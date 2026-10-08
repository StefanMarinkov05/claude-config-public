# Automated testing — unit, integration, system

The regression layer. Its value is not that it finds bugs today; it is that it
stops today's bug returning in six months.

**Read `test-quality.md` alongside this** — it covers whether a test deserves
to exist and how to prove it works. This file covers how to structure the
suite.

This layer runs **headless** — no browser, no CSS, no JS executing. The
part of the automated suite that *does* drive a real browser in CI
(Playwright / Cypress / Pest-browser / Dusk — smoke, responsive, lifecycle
E2E) is `automated-browser-testing.md`; it runs in step 2 alongside these
but has its own traps and its own job in CI.

## The three levels

### Unit — one class, no I/O

For pure logic: calculations, state-machine matrices, value objects,
normalisation helpers.

Fast enough to run constantly. Should never touch the database, the filesystem,
the network, or the clock. If it needs any of those, it is an integration test
that has been mislabelled.

**Highest-value unit tests in a web app:**
- A state machine's transition matrix, including that no state lists itself
  (a self-transition is usually a special case handled elsewhere, and an
  acyclic graph is what makes "already at target" a safe no-op).
- Money arithmetic, especially rounding direction at the half-cent.
- Any normalisation function that takes untrusted input.

### Integration — several units plus real dependencies

For an operation writing across tables, a query's actual SQL behaviour, an
Action composing other Actions.

Use a real database. Mocking the database here removes the only thing being
tested.

**This is where most business-rule tests belong.** An Action that must write
three tables atomically is proved by calling it and inspecting all three.

### System / feature — a real request through the stack

For authorization, routing, middleware, redirects, session behaviour, and
rendered output.

Slow, so spend them on things only a full request can prove:
- Does an unauthorized role get a 403 at this URL?
- Does the middleware apply to *this* stack (a panel building its own
  middleware stack does not inherit the default group)?
- Does the response actually contain the escaped form of a payload?

Do **not** use them for exhaustive branch coverage.

## Structuring a suite

**Vertical over horizontal.** Testing every method of one class, then every
method of the next, produces high coverage and finds nothing — bugs live
*between* units. Prefer one real behaviour proved end to end, plus unit tests
for genuinely tricky internals.

**Group by the invariant, not by the class.** A file named for an aggregate
("what can and cannot happen to an order") ages better than one named for a
class, because the class will be refactored and the rule will not.

**Name the test as the claim.** `it('refuses a product with no variations')`
tells a reader what breaks if it fails. `testProductValidation` does not.

## Fixtures

**Create what the test needs; do not depend on seeded data.** A test relying on
a seeder passes until someone edits the seeder, then fails for an unrelated
reason.

**Factories should produce valid rows by default.** If a factory can produce a
row the schema rejects, every test using it is one constraint away from
breaking. A test asserting that *every factory persists a row* is cheap and
catches this whole class.

**Watch for factory/constraint drift.** Adding a database constraint can make
existing factories invalid — the factory passes every static check and fails on
insert.

## The database you are actually testing against

**Confirm the driver before trusting any test result.** A test suite running on
a different engine from production is testing a different set of rules, and
nothing about a working app reveals it:

```bash
php artisan tinker --execute="echo DB::connection()->getDriverName();"
```

A lighter-weight engine substituted by accident (a skeleton `.env` left in
place, a config default) silently drops **column length limits, enum
enforcement, and every `CHECK` constraint**. Every test asserting that a bad
value is refused then passes for the wrong reason — or, worse, the constraint
tests pass locally and the behaviour differs in production.

Related: a spawned child process reads the environment file, not the test
configuration, so a worker in a concurrency test can silently run against the
*development* database. Pass the connection environment explicitly
(`concurrency-testing.md`).

## Silently discarded attributes

An ORM commonly discards attributes that are not mass-assignable, or that do
not exist, **without complaint**. A seeder or factory sets a field, the row
does not have it, nothing errors — and a test asserting on the *other* fields
passes.

The framework usually offers a strict mode that turns this into an exception
(`preventSilentlyDiscardingAttributes()` and equivalents). Enable it in
non-production environments; without it, a renamed column leaves every seeder
and factory referencing the old name silently doing nothing.

## Isolation

Most suites wrap each test in a transaction rolled back afterwards. Know the
two consequences:

1. **Rows are invisible to other connections.** Any test needing a second
   process (see `concurrency-testing.md`) must opt out and truncate manually.
2. **Committed side effects don't happen** — including anything registered to
   run after commit. If the code under test dispatches an event after commit,
   the test must account for it.

## What to assert

Covered in depth in `test-quality.md`; the short version:

- **Data, not status codes.** A wrong answer returns 200.
- **The count *and* the identity.** A count can coincide.
- **The exception type**, when a constraint would produce a different failure
  than the application guard. That difference *is* the test.
- **Negative space.** "And this other thing did not change" catches
  over-broad writes that a positive assertion misses.

## Edge cases worth a standing habit

- **Zero, one, and two.** Set-replacement bugs almost never appear at zero or
  one.
- **Exactly at the limit.** A partial operation taking *exactly* the remainder
  should reach the terminal state, not the partial one.
- **The second identical request.** Idempotent, refused, or double-applied —
  all three are valid designs, only one is intended.
- **Accumulation versus absolute.** A third-party API reporting a *cumulative*
  total, passed to code that *accumulates*, double-counts everything after the
  first. Establish which each side means.

## Coverage numbers, and what they cannot see

Coverage is a report, not a gate — a percentage says which lines executed, not
which behaviours were proved. Two specific blind spots worth knowing before
quoting a number:

**A subprocess is invisible to the coverage driver.** If a test spawns a real
process to run the code under test — which every genuine race test must
(`concurrency-testing.md`) — that execution is not instrumented. Measured: a
race test isolated on its own reports the Action it exercises at **0.0%**.

The trap is that the class's *overall* percentage often still reads high,
because a same-process companion test covers the same file — the same Action
measured 92.3% via its sequential companion. **Read the number as silent about
the race, not as evidence either way.** What proves a race is the deletion
method, not the report.

**A high percentage on an authorization path means little.** An assertion that
a role *can* do something passes just as happily against a system with no
authorization at all. The assertions carrying information are the denials.

Also expect the full run to need more memory than the default to assemble the
report — the failure comes *after* every test has passed, which reads as a
suite failure rather than a reporting one.

## Parallelism is not free, and more workers is not faster

If each worker rebuilds its own database, worker count trades startup cost
against contention. Measured on one 12-core machine, 472 tests:

| Invocation | Duration |
|---|---|
| Sequential | 473s |
| `--parallel --processes=4` | **260s** |
| `--parallel --processes=12` (= cores) | 338–361s |

Twelve workers each paying a schema load at once contend on I/O during exactly
the expensive part; four do not. **Measure rather than setting workers to core
count**, and re-measure when the schema's migration cost changes materially.

**Never run concurrency tests under parallel execution.** The per-process
database split is usually wired to fire only for test cases using a
database-refresh trait — and concurrency tests deliberately use none, because a
wrapping transaction would hide the committed rows a second connection must
see. So every parallel worker points at the *same* physical database and their
fixtures collide. Measured: 21 failures out of 33, all
model-not-found or constraint errors from workers deleting each other's rows.
That is not flakiness to retry away. Parallelise those at the *shard* level —
separate sequential runs in separate databases.

## Time-balanced sharding beats hand-partitioning, and stays correct on its own

Splitting a suite across CI shards by directory or file count optimises the
wrong variable — a shard with three slow integration tests and a shard with
thirty fast unit tests are not balanced just because they hold the same
file count. Split by measured wall-clock time instead: bin-pack the heaviest
files into the lightest shard first, from real per-class timings, not a
guess.

The trap with doing this by hand: it goes stale silently. A shard split
correct when written drifts the moment someone adds a slow test to the
"light" shard, and nothing flags it — the job still passes, just
unevenly, and the imbalance is only visible to someone who happens to
compare job durations. Tooling that reads a **committed, auto-refreshed
timing file** (Pest 5's `--shard=N/M` against `--update-shards`'
output is the concrete example) fixes this at the source: the split is
derived from data, the data has a refresh command, and the tool itself
warns when the file is stale rather than silently drifting. Prefer that
shape over a hand-maintained shard list in CI config, in any framework
that offers it.

## Test Impact Analysis: real speedup, real constraints

Frameworks that support TIA (Pest 5's `--tia`, similar tools elsewhere) map
source files to the tests whose coverage touches them, then replay only
the tests a change could affect — a 10-minute suite can become seconds for
a small diff. Two constraints worth checking *before* assuming it will
just work, both found by trying rather than reading the feature
announcement:

- **A git-dependent CLI flag needs its own verification inside the actual
  execution environment**, not just `--help` confirming the flag exists.
  A container that mounts only the application subdirectory (not the
  whole repository) may have no reachable `.git` at all — and the fix is
  not always "mount `.git`": if the tool computes file paths relative to
  its own working directory independently of any `GIT_WORK_TREE`
  override, the only shape that works is running the tool from *inside* a
  mount that mirrors the real repository layout (`.git` and the app
  directory as true siblings, matching the host), not from the
  application directory alone with git pointed elsewhere by an
  environment variable. Confirm this by dirtying one real file and
  checking the tool actually narrows to it — and confirm the negative
  case too, that a clean tree reports nothing dirty, so an infinite-match
  bug does not read as success.
- **TIA may demand that the tool's project root *be* the git repository
  root** — a stricter bar than "git must be reachable," and the one that
  bites when an app lives in a subdirectory of a larger repo by design
  (docs, infra, and app code sharing one repository). Read the refusal
  message *and* the source: "requires git" and "requires the repository
  root" are different constraints with different fixes.

  Then push past the refusal twice, because there are two separate
  questions and answering only one produces a confident wrong answer in
  either direction:

  1. **Is the guard actually unconditional?** Often it is one cheap
     predicate — in Pest 5's case, `git rev-parse --show-prefix` must
     return empty at the project root. `GIT_DIR`/`GIT_WORK_TREE` can make
     that true without restructuring anything, so "the tool refuses"
     rarely means "the tool cannot be made to start." Find the predicate
     and run it yourself rather than paraphrasing the error.
  2. **If the guard passes, is the output sound?** This is the half that
     matters and the half that is easy to skip once something finally
     runs. A worktree override that satisfies the guard can leave the
     *index* rooted somewhere else, so the tool's own
     `git diff --name-only` emits paths it then resolves against the
     wrong base — every changed file resolving to a path that does not
     exist. Nothing matches, nothing narrows, and the run is fast and
     green while selecting the wrong tests.

  **A test selector that silently over- or under-selects is worse than no
  selector**, because the suite still reports success — the same shape as
  a scanner that never reached its target. Verify selection positively
  (change one file, confirm exactly the dependent tests run) *and*
  negatively (clean tree selects nothing) before trusting it. If
  soundness needs a structural change — giving a subdirectory its own
  repository, say — that is a deliberate architectural trade to argue in
  a decision record, not something to configure in quietly.

## When a bug is found

1. Write the failing test **first**, at the level that reproduces it.
2. Confirm it is red for the right reason — read the failure message.
3. Fix.
4. Confirm green, then **revert the fix** and confirm red again.
5. Add the file to the CI shard list if one is maintained by hand.

## Checklist

- [ ] Each test at the right level for what it proves
- [ ] Vertical slices, not horizontal per-class sweeps
- [ ] Named as the claim it makes
- [ ] Fixtures created by the test, not inherited from a seeder
- [ ] Every factory known to persist a valid row
- [ ] Isolation consequences understood for after-commit behaviour
- [ ] Asserts data and identity, not status
- [ ] Zero/one/two, at-the-limit, and repeat cases covered
- [ ] Coverage read as silent about anything running in a subprocess
- [ ] Worker count measured, not set to core count
- [ ] Concurrency tests excluded from parallel execution
- [ ] Database driver confirmed to match production before trusting refusals
- [ ] Strict "discarding attributes" mode on, so a renamed column fails loudly
- [ ] Every new file registered wherever CI discovers tests
