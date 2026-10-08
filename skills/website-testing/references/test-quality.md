# Test quality — when a test earns its place, and how to prove it works

Two questions, asked in this order, about every test:

1. **Does it prove something that is ours?**
2. **Has it been observed failing?**

A test that fails either is a liability: it costs runtime, it costs
maintenance, and — worse — it produces confidence that isn't backed by
anything.

## The deletion method: a test is not a test until it has failed

**Write the test, watch it go red, then make it green.** If you wrote the test
after the code, break the code deliberately and confirm the test catches it.

Two ways to break it, and they are not equivalent:

### Flip the assertion

Fastest check that the test *executes* what it claims. Change `toBeTrue()` to
`toBeFalse()`, or the expected count from 1 to 2. If it still passes, the
assertion never ran — a guard clause returned early, the setup threw and was
swallowed, or the test asserts on a variable it never populated.

This catches a **broken test**.

### Remove the mechanism

Delete the fix, the lock, the `#[Locked]` attribute, the middleware
registration — then run. If the test still passes, it does not test what its
name says.

This catches a **test pointed at the wrong thing**, which is the more common
and more dangerous case, because it looks correct in review.

### Record what happened

When a suite is validated this way, the *split* is the evidence:

> Validated by replacing the middleware with a deliberately vulnerable version
> that trusts the body: **eight of eleven failed**, including "refuses an
> unsigned request claiming a payment succeeded". The three that still passed
> are correctly scoped — idempotency rests on the UNIQUE index rather than the
> signature, and route shape is unaffected.

That paragraph is worth more than the eleven tests, because it says which test
covers which mechanism. A blanket "all tests pass" says nothing about
coverage.

Similarly, a partial revert is stronger evidence than a total one:

> 6 cases, confirmed to fail with the change reverted (5 failed on the reverted
> page; the 6th passed, because it exercises the table, which was not reverted
> — the split is what proves each case targets what it claims).

## Four ways a deletion test stays green anyway

The deletion method is necessary and not sufficient. These are the documented
cases where a guard was removed and the test *still* passed — each looks
correct, and none is visible from the test's own output.

### 1. A composed call raised the same exception

An Action calls another Action and passes the actor down, so both check a
policy. A test actor holding *neither* permission is denied twice, and
`toThrow(AuthorizationException::class)` cannot tell which check did it. The
exception type is right, the write really was prevented, the description
matches — only the attribution is wrong.

**Fix:** grant the actor **every permission the composed calls need except the
one under test** — exactly one permission short of success, rather than none.

### 2. A second guard subsumes the first

Two guards in the same function raise the *same* exception class, and a
database constraint makes the second one's valid range cover the first's. On an
empty cart line, every quantity a `< 1` guard rejects is also rejected by a
`min_order_quantity` guard, because a `CHECK` keeps every minimum at 1 or more.

**Fix, both halves needed:**
1. **Assert the message, not only the class.** Two guards are two different
   messages to a user; a shared exception class with distinct static factories
   (`notPositive()`, `belowMinimumOrder()`) is the signal to check for.
2. **Add the case only the guard under test can catch.** A *negative* quantity
   against an existing line: `-2` added to a line of `5` sums to `3`, clearing
   both the minimum and the stock check — so without the guard, "add to cart"
   silently removes two units.

### 3. A constraint backstops the mechanism

Covered in `concurrency-testing.md`, and it generalises beyond locks: if a
`UNIQUE` or `CHECK` constraint produces one winner whether or not the
application guard exists, then counting winners proves the constraint. Assert
the **kind** of failure — the domain exception versus the driver exception.

### 4. A disabled control never sent the field

A form-submission test passes with the server-side guard deleted, because the
form disables the field for exactly that actor, so the payload never carried
it. **A disabled control is not security, and a test driving the UI is not
testing the seam a crafted request reaches.** Call the mutation hook, Action,
or endpoint directly.

**The generalisation:** when a deletion test stays green, do not conclude the
guard is redundant. Find which *other* mechanism caught it — there is always
one, and knowing which is the real result.

## Does it prove something that is ours?

A test earns its place by proving **our** logic, not the framework's.

**Does not earn its place:**
- That a file-upload widget rejects a disallowed MIME type — the framework's
  own suite covers that.
- That a validation rule library rejects an undersized image.
- That the ORM's `where()` binds parameters.
- That a route returns 404 for a nonexistent typed model binding.

These cost a flaky, fixture-heavy test for zero information gained.

**Does earn its place:**
- That the *right constant* reached the *right method* — though note a good
  type checker already proves this by refusing to compile a typo'd reference,
  so check whether you need a test at all.
- That a domain rule expressed *through* a framework mechanism holds: a form
  that refuses a product with no variations is exercising the framework's form
  machinery, but what it *proves* is a domain invariant.
- Anything in the "invariants the schema cannot express" list
  (`thinking-in-invariants.md`).

**Before writing a test, name what it would prove, then check whether that
thing is ours.**

## Testing against a faked third party — and the gap it leaves

Faking an external service is usually right: what is under test is *your*
arithmetic and state machine, not the provider's. A test hitting the real API
proves their system works, which is not yours to prove, and makes the suite
depend on network and credentials.

But it leaves a precise, nameable gap: **your tests prove your handling of the
response shape you imagined, not the shape the provider actually sends.**

The technique that closes most of it, without putting the network in the suite:

1. **Fetch real objects once**, from the provider's sandbox, and check every
   assumption your code makes about them — does this field exist, is it
   distinct from that one, is the currency lowercase, is this amount in minor
   units, is this id a string or an expanded object?
2. **Pin the confirmed shapes in tests**, so a provider's API-version bump that
   renames or retypes a field fails a test rather than silently changing what
   your code reads.
3. **Record what you confirmed, with the real values**, so the next person does
   not re-derive it.

Real findings from doing exactly this: a field documented as "usually the
amount of the charge, but it can differ" must not be amount-guarded; a boolean
that stays `false` throughout a partial refund would misclassify if used; an id
field can arrive as an *expanded object* rather than a string, silently
dropping the event.

**Mock the right seam.** Mocking a magic accessor that delegates to a real
method leaves the delegation running and produces a confusing "no expectations
were specified" error naming a method you never mocked. Mock what the code
actually calls.

**And state the residual gap honestly.** "Every test fakes the client, so what
is proven is this application's arithmetic, state machine, and endpoint
behaviour; what is *not* proven is that the provider accepts the exact request
shapes sent" is a complete and useful statement. "Payments are tested" is not.

## Assertion strength: a wrong answer returns 200

The single most common weak test:

```php
// Proves the request survived. Proves nothing about correctness.
$response->assertOk();
```

A real bug that passed such a test for weeks: a nested-array parameter didn't
crash, so `assertOk()` was green — but `intval()` of a non-empty array is `1`,
so the filter collapsed onto a real, filterable id and silently applied it.
164 products became 37 under a filter the visitor never selected.

The rules that follow:

- **For any value reaching a query, assert the resulting set, not the status.**
  Only inspecting the returned data proves it survived *correctly*.
- **Every "does not crash on X" test deserves a sibling "and X changes
  nothing" test.**
- **Assert the count *and* the identity.** A count can coincide.

## The control row

Any table of probes needs at least one case that is **required to pass**.

Without it, a probe that never reaches the code under test is
indistinguishable from a defence that works. A real instance: five malformed
prices all reported "refused" — a clean-looking pass. They were refused on a
missing required field in the probe's own payload; the price column was never
reached. Only adding a valid control (which *must* be accepted) exposed it.

This applies to authorization matrices too: if every role is denied
everything, the denials prove the request was broken, not that authorization
works. Include the role that *should* succeed.

## Test levels, and what each is for

| Level | Scope | Use it for | Do not use it for |
|---|---|---|---|
| **Unit** | One class, no I/O | Pure logic, calculations, state machines, enum matrices | Anything touching the database or HTTP |
| **Integration** | Several units + real dependencies | An Action writing across tables; a query's actual SQL behaviour | Whole-request behaviour |
| **System / feature** | A real request through the stack | Authorization, routing, middleware, redirects, rendered output | Exhaustive branch coverage — too slow |
| **Concurrency** | Two OS processes | Races, locks, idempotency (see `concurrency-testing.md`) | Anything single-process can prove |

**Horizontal slicing is the anti-pattern.** Testing every method of one class
at unit level, then every method of the next, produces high coverage and finds
nothing, because bugs live *between* units. Prefer a vertical slice: one real
behaviour proved end to end, plus unit tests for the genuinely tricky logic
inside it.

## Test anti-patterns

**Tautological.** The test computes the expected value the same way the code
does. If the code's formula is wrong, both are wrong together.

**Implementation-coupled.** Asserts on private state, call order, or the exact
number of queries when the count isn't the point. Breaks on every refactor
while proving nothing about behaviour. (A query-*count* test is legitimate when
the count *is* the invariant — an N+1 guard.)

**Mystery-guest fixtures.** The test depends on seeded data it doesn't create
and doesn't name. It passes until someone edits the seeder.

**Assertion-free.** Calls the code, catches nothing, asserts nothing. Passes as
long as no exception escapes. Surprisingly common in "smoke tests."

**Over-mocked.** Everything the unit touches is a double, so the test proves
the unit calls the mocks it was written to call. The integration it actually
depends on is untested.

**Conditional assertions.** `if ($x) { expect(...) }` — silently proves
nothing when the branch isn't taken.

## Flaky tests

A flaky test is worse than no test: it trains everyone to re-run rather than
investigate.

When one appears, **do not** immediately add a retry. Record it first —
which test, what the failure was, what the immediately-following run did. Then
find the cause. Common ones: time-dependent assertions crossing a boundary,
tests depending on other tests' data, unsorted results asserted in order, and
timing barriers in concurrency tests that stop aligning on a loaded machine.

If a barrier-based concurrency test is flaky, the barrier is too tight — and
note the failure mode is asymmetric: a barrier that stops aligning makes the
workers sequential, which makes the test **pass** while proving nothing.

### Factories that compute related fields from one draw

A specific, hard-to-diagnose cause worth knowing by name. A factory computes
two or three fields from a single internal random draw — a price, a discount
derived from *that* price, a validity window drawn independently. Overriding
**one** of the group in `create([...])` does not touch the others: they were
computed inside `definition()` before the override merged in.

Two failure shapes, both real:

- Overriding a discount to `null` leaves independently-drawn window dates in
  place, so some fraction of runs land on a closed window that silently
  suppresses a discount the test explicitly set.
- Overriding a price without pinning the derived discount leaves the discount
  computed against the factory's *internal* price, which can now exceed the
  override and trip a `CHECK` constraint as an uncaught driver exception —
  before the test's assertions ever run.

The failure rate (roughly one run in five to ten) is exactly low enough for a
single local run and a single CI run to pass, letting a flaky test merge
looking green and fail later on an unrelated change.

**Rule: when overriding one field of a factory's randomised group, override
every field derived from the same draw** — including pinning to `null`
explicitly when the intent is "none". And **run a new money- or
window-dependent test ten times in a loop, not once**; a test observed failing
zero times is not evidence it cannot.

## Where a new test file goes

If CI shards by a hand-maintained file list, **a new test file must be added
to a shard in the same change** — otherwise it runs nowhere, and a test that
runs nowhere is indistinguishable from a passing one. See `cicd-gating.md`.

## Checklist

- [ ] Named what it proves, and confirmed that thing is ours, not the framework's
- [ ] Observed failing — assertion flipped, or mechanism removed
- [ ] If it stayed green, the *other* mechanism that caught it identified
- [ ] Actor granted one permission short of success, not zero
- [ ] Message asserted, not only exception class, where one class has two sources
- [ ] Factory groups pinned together; money/window tests looped ten times
- [ ] Which mechanism each test covers is recorded when a suite is validated
- [ ] Asserts data, not just status
- [ ] Control case included in any probe table or authorization matrix
- [ ] Right level — unit for logic, system for authorization, two processes for races
- [ ] No tautology, no conditional assertions, no mystery fixtures
- [ ] Added to the CI shard list if one is maintained by hand
