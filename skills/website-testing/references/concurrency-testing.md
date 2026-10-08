# Concurrency testing

Proving that a race is actually closed — and, more often, discovering that a
green test proves nothing because it never produced a race at all.

This is the layer with the widest gap between "test exists" and "test is
evidence." A concurrency test that has never been observed failing with its
mechanism removed is not a test; it is a comment with a runtime cost.

## The failure shape: check-then-act

Every race in an application of this kind reduces to a decision made by
reading a row that another request may be changing at the same moment.

```
        Request A                        Request B
t1      BEGIN
t2      SELECT → reserved = 0
t3                                       BEGIN
t4                                       SELECT → reserved = 0
t5      available = 1 ≥ 1, proceed
t6                                       available = 1 ≥ 1, proceed
t7      UPDATE reserved
t8      COMMIT
t9                                       UPDATE reserved
t10                                      COMMIT
```

Both read before either wrote. Both decided on state that was true when read
and false when acted on. **The window between t2 and t7 is where every version
of this bug lives.**

## Why a transaction alone does not close it

This is the most commonly held wrong belief about concurrency, and it will
make you write tests that pass against broken code.

MySQL's InnoDB defaults to `REPEATABLE READ`, which already prevents:

| Phenomenon | Meaning | Prevented at |
|---|---|---|
| Dirty read | Reading another transaction's uncommitted write | `READ COMMITTED` |
| Non-repeatable read | Same row read twice in one transaction differs | `REPEATABLE READ` |
| Phantom read | A range query gains rows on re-execution | `SERIALIZABLE` (largely `REPEATABLE READ` in InnoDB via gap locks) |

**None of them is the problem above.** B never reads uncommitted data, never
reads the same row twice, and runs no range query. B reads *once*, correctly,
from a consistent snapshot — and the snapshot is stale by the time it writes.

Under `REPEATABLE READ` a plain `SELECT` is a *consistent nonlocking read*,
served from an MVCC snapshot taken at the transaction's first read. It is
guaranteed **consistent**. It is not guaranteed **current**, and nothing
about wrapping it in a transaction makes it so.

The anomaly has names outside the ANSI list:

- **Write skew** — two transactions read overlapping rows and each writes
  based on a predicate the other invalidates. Prevented only at
  `SERIALIZABLE`.
- **Lost update** — both read the same value, compute from it, and one write
  overwrites the other. Prevented at *no* isolation level when the arithmetic
  happens in application code.

## What a lock actually does

`SELECT ... FOR UPDATE` (`lockForUpdate()`) is a *locking read*, differing
from a plain `SELECT` in two ways that both matter:

- It takes an exclusive row lock held until the transaction ends. A second
  locking read on the same row **blocks** rather than returning.
- It **bypasses the MVCC snapshot** and reads the latest committed version.

Replay the timeline: B blocks at t4, resumes after A commits at t8, reads
`reserved = 1`, and correctly finds nothing available.

That second property is the one people forget. A lock that is taken and then
ignored in favour of a stale in-memory reference protects nothing — see
"Trusting the locked row" below.

## The three outcomes of a blocked transaction

Only the third is an exception at the call site, and tests often assert for
the wrong one.

1. **It waits and resolves.** The ordinary case. No exception, no error — the
   request is simply slower. This is what a correct lock produces, and what a
   concurrency suite mostly exists to prove.
2. **It waits too long.** `innodb_lock_wait_timeout` (50s default) → error
   1205. Rare with short, single-purpose transactions.
3. **It deadlocks.** Two transactions each waiting on a lock the other holds
   → error 1213.

Framework note worth verifying in your own stack rather than assuming: Laravel
runs every exception through `causedByConcurrencyError()`, which
pattern-matches 1205 and 1213 **identically** — so a lock-wait timeout and a
deadlock are handled the same once they reach PHP. At the top level it rolls
back and rethrows; it only retries if `DB::transaction($cb, $attempts)` is
called with `$attempts > 1`.

## Building a test that can actually race

Three facts force the shape. Miss any one and the test is sequential — which
is the failure mode that **passes**.

### 1. Two real OS processes

The race is between two *connections*. One PHP process holds one connection,
so it cannot produce the interleaving no matter how cleverly the test is
written. A second connection means a second process.

### 2. A barrier

Booting the framework takes hundreds of milliseconds and varies run to run;
the window under test is microseconds wide. Started sequentially, the second
worker reliably arrives after the first has committed — and the test then
behaves **identically with and without the mechanism**.

So: both workers boot, warm their connection, and spin-wait on a shared
wall-clock instant. The barrier lives entirely in the test — no flag, no
sleep, and **no test-only branch in production code**. It must be generous
enough for two boots on a *loaded* machine.

### 3. Outside transaction-rollback test isolation

`RefreshDatabase`-style isolation wraps each test in a transaction that is
rolled back rather than committed, so rows the test created are invisible to
the second connection — and asking for one makes that connection queue behind
the test's own uncommitted write. These tests must **commit** their fixtures
and truncate afterwards.

### Prefer a real command over a generated script

Spawn both halves as a first-class console command (`artisan race:worker
<action>`) rather than writing a PHP script to disk and executing it. The
command owns the bootstrap, connection warm-up, barrier, rendezvous, and the
`OK`/`FAILED:<exception class>` protocol; each test supplies only what
differs.

Why it is worth the indirection: a nowdoc-string worker duplicates the
bootstrap preamble across every test file, leaves untracked files in the
project root when a run dies before its `finally`, and is invisible to static
analysis. A measured migration of twelve such files cut a suite from ~695s to
518s, because the framework's own bootstrap is cheaper than a hand-rolled one.

**Pass the database environment explicitly to every spawned worker.** A child
process reads `.env`, not the test config — without it a race silently runs
against the *development* database.

### 4. A cross-Action race needs a rendezvous

The three facts above suffice when both processes run the *same* code path:
identical code takes identical time to reach the critical section, so aligning
*starts* aligns *arrivals*.

They do **not** suffice when the two processes run *different* code paths. If
one validates nothing first and the other checks two preconditions, a
wall-clock barrier that aligns both starts still leaves one side reliably
arriving first.

Measured, not assumed: one such pair was raced 24 times under three
synchronization strategies and the same side won **every single time**. That
is a real property of the two code paths, not a flaw in the barrier.

The fix is a second, tighter synchronization layered on the first: each worker
writes a ready-flag file on reaching the barrier, then polls for the other's
flag before calling its action. This removes process-boot jitter specifically
— it **cannot** equalise the two paths' own internal work.

Two rules:

- **The rendezvous must be two-sided.** One-sided blocks until timeout and
  proves nothing.
- **Race more than once** (`->repeat(n)`), since a single run can pass by
  chance if the favoured side happens to win.

**Whether a rendezvous is sufficient depends on the pairing, not the
technique.** In one measured case it took a deterministic 24-0 sweep to a
roughly 2:1 split — good enough. In another it did not close the gap at all.
Measure the specific pairing rather than assuming from either precedent.

## Choosing the assertion — the step that decides whether the test is worth anything

Ask: **what catches the failure if the mechanism is gone?** The answer differs
per mechanism, and getting it backwards produces a green test that survives
deleting the lock.

| What backs the invariant | Unlocked outcome | Assert |
|---|---|---|
| A `CHECK` or `UNIQUE` constraint | still exactly one winner; only the failure *differs* | the **type** of the loser's exception |
| Nothing — the rule spans tables | both writes commit | the winner **count**, and the invariant on final state |
| Nothing to invalidate — a blind single-statement write | unchanged | the final state as a **property**, not a guard |
| An idempotent no-op by design | **two successes** | that the *write* happened **once** |

The fourth row is the subtle one. When an action's repeat is a designed no-op
rather than a refusal (a double-submitted status change is not an error),
racing two identical requests produces two successes — both report success
either way if the no-op path is correct. What proves the lock is doing
anything is not what either process observes but that the write happened
exactly once: one history row, not two.

Asserting a winner count there — as the first three rows would suggest — fails
against **entirely correct behaviour**, which is a worse mistake than
asserting nothing.

## Trusting the locked row, not the reference that was locked

A lock taken correctly and then ignored protects nothing, and **nothing about
the code announces this**: it type-checks, it reads naturally, and a
single-process test cannot tell the two apart because there is nothing else
writing to disagree with.

```php
// WRONG — $order was hydrated before the lock was requested.
$locked = Order::query()->lockForUpdate()->findOrFail($order->getKey());
$from = $order->status;      // stale reference

// RIGHT — read off the row the lock actually returned.
$locked = Order::query()->lockForUpdate()->findOrFail($order->getKey());
$from = $locked->status;
```

Actions that read quantities directly off the locked row in the same statement
never have this problem. Actions handed a *model instance* do, because the
natural-looking `$model->field` is sitting right there once the lock resolves.

This is worth an explicit deletion test: swapping the locked row's field for
the parameter's should turn a passing race red.

## What cannot substitute for a second process

**Single-process fault injection.** A row lock places no constraint on the
transaction that *holds* it, so a test that injects a conflicting write on its
own connection passes with the lock and without it.

It can demonstrate that a window exists between a read and a write. It cannot
demonstrate that anything closes the window. Right technique for proving a
transaction rolls back; wrong technique for proving a lock exists.

## Documenting a concurrency test

Per `documentation-standards.md`, plus one rule specific to this layer:

**A row in a contested-resource table counts as *verified* only if the test
has been observed failing with its mechanism deleted and passing with it
restored.** Anything else is listed as **unverified** — because a test that
has never failed is not evidence.

Record, per contested resource: the resource, the kind of contention, the
mechanism protecting it, and the test that proves it. Keep the *outcome* (which
side wins, what exception, what the row looks like after) in exactly one place
— repeating it in two documents is how the two drift.

**Declare the lock order** and say which parts of it are unexercised. An order
nothing currently violates is still worth declaring, because the next Action
to take two locks needs to know the sequence. Be honest when a sort is
unverified because an index happens to return rows pre-sorted — removing it
would not turn any test red today, and that is worth writing down rather than
claiming coverage.

## Checklist

- [ ] Two real OS processes, not two connections in one process
- [ ] A wall-clock barrier, generous enough for a loaded machine
- [ ] Fixtures committed, not wrapped in rollback isolation
- [ ] Database environment passed explicitly to each worker
- [ ] Rendezvous added if the two sides run different code paths
- [ ] Repeated runs for any cross-path race
- [ ] Assertion chosen against the *unlocked* outcome, per the table
- [ ] Reads taken off the locked row, not a pre-lock reference
- [ ] **Observed red with the mechanism deleted**, then restored
- [ ] Lock order declared; unexercised parts labelled as such
