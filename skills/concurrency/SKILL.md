---
name: concurrency
description: Designing and testing concurrency control - MVCC and isolation semantics, the race taxonomy (lost update, write skew, TOCTOU, double-submit), choosing pessimistic vs optimistic vs constraint-based control, aggregate-root locking, deadlock ordering, speculative holds with TTLs, and the two-process harness that actually proves a lock exists. Use whenever code reads state to decide whether a write may proceed, when adding or reviewing a transaction/lock/unique constraint/idempotency check, when enumerating edge cases for checkout, inventory, booking, payment, or ledger flows, and whenever a test claims to prove a race is handled. Trigger on "race condition", "deadlock", "lock", "transaction", "isolation level", "concurrent", "idempotent", "double submit", "oversell", "lost update", or "thread safe" - and proactively on any read-then-write against shared state.
---

# Concurrency

Correctness under simultaneous access. Complements database-design (where constraints live) and tdd (how tests earn trust) with the specific reasoning that goes wrong when two requests touch one row.

**The one rule that decides everything else: the mechanism follows the length of the critical section, not the importance of the data.** A lock held across a user's think time is not a lock, it is an outage. A version check on a microsecond window is pointless overhead.

## Step 1 - name the contention shape

Never ask "is this concurrent?". Ask **who reads this to decide whether to write, and what invalidates the decision.** Four shapes, four mechanisms:

| Shape | Window | Mechanism |
|---|---|---|
| One row read to decide a write on itself (stock, balance, counter) | microseconds, one request | `SELECT … FOR UPDATE` inside a transaction, **before** the deciding read |
| Invariant spanning tables, no constraint can express it | microseconds, one request | lock the **aggregate root** — the same row for every Action that can break it |
| Same record edited by two humans across requests | think time | **optimistic**: version/timestamp carried through the form, checked in the `WHERE` |
| Same operation submitted twice (retry, webhook, double-click) | any | `UNIQUE` constraint + caught violation. **Never check-then-act** |

The second and third are the ones people get wrong, because the first is the only one most guidance covers.

## Step 2 - know what the transaction does and does not buy

**A transaction alone does not prevent check-then-act.** This is the single most common false belief in this area.

Under MVCC (`REPEATABLE READ`, and `READ COMMITTED` for a single statement), a plain `SELECT` is a *consistent nonlocking read* served from a snapshot. It is guaranteed **consistent**. It is not guaranteed **current**, and wrapping it in a transaction does not make it so.

| Anomaly | What it is | Prevented at |
|---|---|---|
| Dirty read | reading uncommitted data | READ COMMITTED |
| Non-repeatable read | same row differs when re-read | REPEATABLE READ |
| Phantom | range query gains rows | SERIALIZABLE (largely REPEATABLE READ in InnoDB, via gap locks) |
| **Lost update** | both compute from one value, one write overwrites the other | **no level**, when the arithmetic is in application code |
| **Write skew** | each reads rows the other invalidates, both write | **SERIALIZABLE only** |

The bottom two rows are where real bugs live, and neither appears in the ANSI list people quote. If the fix being proposed is "wrap it in a transaction", it is wrong unless the read is also a locking read.

## Step 3 - layer the defences, and know their ranking

Judge a change by which layer it touches — they are not equal:

1. **Database constraint** (`UNIQUE`, `CHECK`, FK, composite PK) — absolute, holds for every write path including seeders, raw SQL, and future code. Where the invariant fits in one row or one table, this is the real guarantee.
2. **Locking read** — correct by construction; the engine's semantics, not your cleverness.
3. **Atomic write** (`SET x = x + n`, `UPDATE … WHERE version = ?`) — keeps a *missing* lock loud instead of silent.
4. **The test** — evidence only. A race is non-deterministic; a test makes an interleaving likely, never certain.

A test that stops reproducing a race is a weaker signal than a constraint that is still in place.

### The counter-intuitive part of layer 3

**Atomicity does not hide the bug, it makes the bug trip a guard.**

```
increment('qty', 1)      → SET qty = qty + 1. Evaluated against committed state.
                            With the lock gone, writes an impossible value the
                            CHECK constraint rejects → loud failure, nothing lost.

$m->qty += 1; $m->save() → SET qty = 1. A literal from a stale read.
                            Both racers write the same plausible number, the
                            constraint is satisfied, and the loss is silent.
```

Prefer the form that fails loudly when its guard is removed. This applies far beyond SQL: compare-and-swap over read-modify-write, `INSERT … ON CONFLICT` over select-then-insert.

## Step 4 - lock the aggregate root, not the row you write

When one invariant spans tables and two operations each guard their own side, locking what each one writes is **correct-looking and completely ineffective** — they take different locks and neither waits.

Lock the row that *represents the invariant*: the order, not its items; the product, not its variations; the account, not its entries. Every operation that can break the invariant takes that same lock.

Verify the interleaving both ways. If A-then-B is safe but B-then-A is not, the guard is on one side only and you have not finished.

**Declare a global lock order** the moment two resources can be locked together, and sort multi-row locks by primary key. Two requests acquiring the same pair in opposite order deadlock; the engine will detect it and kill one, and retry is the fallback, not the fix.

## Step 5 - enumerate edge cases systematically

Do not brainstorm. For **each contested resource**, walk the families:

- **Double submit** — retry after timeout with unknown outcome, double-click, at-least-once webhook, replayed message.
- **Concurrent create on a natural key** — same email, SKU, slug, idempotency key, sequential number.
- **Read-then-write** — the decision invalidated between read and write (the default suspect).
- **Delete/deactivate while referenced** — removed from the catalogue while in someone's cart; parent deleted with children attached; soft-deleted row still counted somewhere.
- **Expire while in use** — session, hold, token, coupon, price window, cart, lock TTL. Ask what happens at exactly the boundary.
- **Out-of-order events** — refund before charge, delivery before dispatch, update before create. A `UNIQUE` on event id stops *duplication* and says nothing about *ordering*.
- **Partial failure mid-multi-step** — external call succeeded, local write failed. What compensates, and is the compensation itself idempotent?
- **Cross-entity dependency** — the price/stock/discount changed between the user seeing it and acting on it. Which value wins, and is that a correctness or a product decision?

For each: *who else can be doing what, at the same instant, to the same row?* If the answer needs a diagram, write the diagram into the explanation doc (docs-and-comments).

## Step 6 - speculative holds (reservations, carts, seats)

A hold is speculative execution: subtract now, commit or roll back later. Design rules:

- **Never decrement the physical count.** Keep `on_hand` and `held` separate, with `available = on_hand − held`. A hold that moves the physical number makes the warehouse/ledger disagree and needs a compensating entry to undo.
- **A hold without a guaranteed release path is worse than no hold** — the resource becomes permanently unsellable with no screen showing why. Prefer **lazy expiry** (sweep expired holds on any read of that resource, inside the lock you already take) over a scheduled job, so correctness never depends on a worker existing. A cron sweep is then an optimisation, not a dependency.
- **Take the hold as late as possible.** Value and abuse surface both grow with how early it is taken. Holding from the first step of a long flow is the worst of both: too short a TTL expires on real users mid-flow, too long a one lets an unauthenticated attacker hold the entire catalogue with a few hundred plain HTTP requests. That is **resource exhaustion, not DDoS** — cheap, and rate limiting is mandatory, not optional.
- **Hold the unrecoverable thing, re-check the recoverable one.** Stock gone after entering card details is unrecoverable. A discount code hitting its cap just raises the total before payment — re-validate it, do not reserve it.

## Step 7 - test it, and make the test earn its keep

**The law: a concurrency or security test is not finished until you have deleted the mechanism it guards, watched it go red, and restored it.** A test that has never been observed failing is not evidence. This catches more bad tests in this area than anywhere else, because every wrong version looks right.

For **pure functions** (transition matrices, validators, calculators) there is no mechanism to delete, only a value to get wrong — so the equivalent is **mutation**: apply one *plausible* edit (widen a rule, flip a boolean, drop a list entry, break a terminal state) and confirm the suite notices. Prefer mutants a person would actually write by accident over arbitrary operator flips. Expect some **equivalent mutants** — edits that change no observable behaviour, such as dropping `strict: true` from an `in_array` over enum instances, which PHP compares by identity anyway. A survivor is a finding to investigate, not automatically a hole; record which it was, because "we checked and it cannot be killed" is knowledge and re-deriving it is not free.

### Choose the discriminating assertion by asking what backstop exists

This is the step that is almost always skipped, and it decides whether the test is worth anything:

- **A constraint backs the invariant** (stock with a `CHECK`) → the unlocked version *still* produces exactly one winner; the database rejects the second write. Counting winners proves nothing. **Assert the failure *type***: with the lock the loser reads fresh state and raises a domain exception; without it the loser is stopped by the constraint and raises a driver/query exception.
- **No constraint is possible** (invariant spans tables; triggers rejected) → the unlocked version genuinely commits both writes. **Assert the winner *count***, and assert the invariant directly on final state.

Getting this backwards produces a green test that survives deleting the lock.

### Single-process fault injection cannot test a lock

Injecting a conflicting write via a model/ORM event between the read and the write **runs inside the transaction under test**, and a lock places no constraint on its own holder. Such a test passes with the lock and without it.

It *can* prove a **transaction boundary** rolls back — that is the correct use, and the neighbouring one, which is exactly why the mistake is invisible. Rule: fault injection proves a boundary; only a second connection proves a lock.

### The harness

Two real OS processes with a **barrier** — both boot, warm a connection, then spin-wait on a shared wall-clock instant. Framework boot is hundreds of milliseconds and the window is microseconds, so sequentially started processes never overlap and the test degenerates into a sequential one that passes either way.

Keep race tests **out of transaction-rollback test isolation** (`RefreshDatabase` and equivalents): uncommitted rows are invisible to a second connection, and the second connection queues behind the test's own uncommitted write — producing a lock-wait timeout that looks like a bug in the code under test and is the harness deadlocking against itself. Commit fixtures, truncate afterwards.

Full recipe in `references/test-harness.md`.

### Trap: a denial test satisfied by the wrong check

When operations compose and each authorizes, an actor holding *no* permissions is denied by whichever check runs first — usually not the one under test. The assertion is right, the exception type is right, the attribution is wrong, and deleting the check under test leaves the test green.

**Grant every permission the composed operations need except the one being tested.**

### Trap: one exception class, several reasons

When several named constructors or error codes raise one type, `toThrow(SomeException::class)` passes whichever branch fired. Swap two and the suite stays green. **Assert the payload** - the count, the record, a distinguishing fragment of the message - whenever a class has more than one cause. Same failure shape as the trap above: right type, wrong cause, green test.

## Review checklist

- Read-then-write on shared state with no locking read → race, regardless of the transaction.
- `if (!exists) create()` → replace with a constraint and a caught violation.
- A lock acquired *after* the deciding read → no protection.
- `lockForUpdate`/`FOR UPDATE` outside a transaction → releases immediately, protects nothing.
- Two operations guarding one invariant but locking different rows → neither waits.
- Multi-row locks with no sort order → deadlock waiting to happen.
- Retry loop wrapping a deadlock → the fallback presented as the fix.
- A hold, lock, or TTL with no release path that runs unattended.
- ORM full-object save where only some fields changed → see below.
- A race test asserting the wrong discriminator, or written in one process.

## ORM and framework traps

- **Dirty checking measures against a baseline that may have moved.** If the framework re-resolves the entity from the database on hydration (Livewire, and any component/session layer that stores an id and re-queries), the entity's originals are *current* at save time while the submitted payload is *stale*. A field the user never touched then differs from its original, counts as dirty, and is written — silently reverting someone else's edit. Two entities both loaded before either wrote do **not** show this, so the naive test misses it.
- **Partial (PATCH-style) updates fix only disjoint edits.** They do nothing for two people editing one field, and they can *break* cross-field constraints by validating each field against a snapshot the other half no longer matches.
- **You cannot hold a transaction across two requests** in a request/response runtime — the connection is gone when the response is sent. Anything spanning think time must be optimistic, or an *advisory* application lock (a row with a TTL and a heartbeat, plus a steal-after-expiry path, or a closed browser tab locks the record forever). Never a read lock: it blocks readers who have done nothing wrong.
- **Nested transactions are savepoints.** Composed operations can each open one safely, and the outermost commits — but an inner "commit" is not durable, so do not trigger external side effects on it. Dispatch events **after** the outermost commit.

## Where this connects

database-design owns constraints and indexes; security-baseline owns idempotency on endpoints; api-design owns idempotency keys and retry semantics; tdd owns the vacuous-green mutation check this skill's deletion law specialises; debugging-protocol owns reproducing a nondeterministic failure; code-review's boundary pass should run this file's checklist.
