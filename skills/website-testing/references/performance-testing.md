# Performance testing

Performance is only meaningful once behaviour is correct — a fast wrong answer
is not progress. Run this layer after the correctness layers are green.

**A finding is a measurement plus a row count plus a query plan.** "The
catalogue feels slow" is not a finding; "203 queries / 2,267ms at 100,169
products, of which 173 are one identical category query" is. Record the size
the number was taken at, or the number means nothing next month.

## Seeding strategy — the part that is already built

Two independent seeders, neither wired into the default seed run and neither
run in CI.

### Order-volume seeding

For table size on the transactional side: query plans and pagination against a
realistic number of orders.

```bash
php artisan db:seed --class="Database\Seeders\Stress\StressSeeder"
STRESS_SEED_COUNT=5000 php artisan db:seed --class="Database\Seeders\Stress\StressSeeder"
```

**It reuses the demo seeder's per-order engine rather than a fast factory
path.** That is deliberate and worth preserving: factory-fabricated orders
reserve no stock and produce inventory rows that disagree with their own items
— a corrupt dataset that looks fine until someone queries it. A performance
measurement against incoherent data measures nothing.

It is deliberately loose where the demo seeder is exact (no coupon assignment,
no guest ratio, simplest legal status walk) because none of that precision
affects table size.

### Catalogue-volume seeding

For browsing, search, and category listing at a size the demo catalogue cannot
exercise.

```bash
php artisan db:seed --class="Database\Seeders\Stress\CatalogueStressSeeder"
```

**The two are independent, but order-volume at high counts needs catalogue
volume first** — the demo catalogue's filtered pool becomes the bottleneck well
before large order counts, and a run against it alone has already produced
failures once the pool ran dry.

### Rules for stress data

- Never wired into the default seed run; never run in CI.
- Never presented as demo data.
- Protected/showcase records excluded from the pools, so a demo stays
  reproducible after a stress run.
- **Record the row counts a measurement was taken at.** A latency figure
  without a table size is not a measurement.

## What to measure

Per page: **elapsed server time, query count, and the plan for the slowest
query** — all three, at two table sizes. Measure in-process (dispatch a real
request through the app with the query log enabled) rather than over HTTP when
the question is "which query is slow": that excludes network and browser render
and gives the server-side floor. Say which you did.

Cover at minimum the list page, the same list filtered/searched, the detail
page, and each admin index — list pages are where the cost concentrates.

### The four shapes a list page fails in

Measured on a real catalogue at 100k products; the *shapes* generalise to any
list-plus-facets page in any stack.

1. **A per-row helper that re-queries.** A resolver called once per row issues
   one correct query per call and caches nothing across calls — 173 categories
   produced 173 byte-identical queries in one request. Individually cheap
   (~1.3ms), collectively ~225ms, and **it grows with the facet's cardinality,
   not the table size**, so a product-count stress test will never surface it.
   The tell is a repeated identical query in the log, not a slow one.
2. **The filtering columns carry no index.** `EXPLAIN` showed the engine
   walking 95,129 of 100,169 rows on an index it *did* have (`category_id`)
   and discarding 99%, because the two columns actually narrowing the result
   (an availability flag, a soft-delete timestamp) had no index. Fix is a
   composite in filter-then-group order — and re-measure before adding a second
   one, because the first often makes it unnecessary.
3. **Leading-wildcard search is a full scan, by construction.** `LIKE
   '%term%'` cannot use a B-tree — the engine cannot know where in the column
   the term starts. Measured `type: ALL`, ~900ms *per facet query*, three
   times per page load, 2.6s of a 3.9s page. This is not an indexing mistake to
   fix with an index; it needs a full-text index or a search service, i.e. a
   different query shape. Name it as a known trade with a measured cost rather
   than an oversight.
4. **Eager loading that actually works, confirmed as a negative result.** The
   detail page held **19–22 queries flat** across a 5× increase in child rows
   (5→500 variations, 2→200 images), and ~100ms inside a database of 5M image
   rows. Growth was PHP hydrating models, not queries. **Record the page you
   checked and found sound** — otherwise it gets re-suspected on every future
   pass.

The comparison that made the diagnosis obvious: the list page was **18× slower
than the detail page in the same database**. That ratio localises the problem
to the page, not to scale in general.

## The N+1 problem, specifically

The highest-value performance check in an ORM-backed admin panel, and the one
that hides best: **a page with an N+1 still renders correctly.** Nothing fails.
It is only slow, and only at scale.

The rule: **a table column crossing a relation gets that relation eager-loaded.**
This applies equally to an accessor that reads a relation, where the column name
contains no dot to hint at it.

**Test it by counting queries, not by timing.** A query-count assertion is the
one legitimate use of an implementation-coupled test, because the count *is*
the invariant:

```php
DB::enableQueryLog();
// render the page
expect(count(DB::getQueryLog()))->toBeLessThan($threshold);
```

Consider whether to enable the framework's strict lazy-loading prevention. If
it is deliberately left off, the rule must be enforced by review and by
query-count tests instead — and that decision should be written down.

## Method

- **Measure before optimising.** A guess about which query is slow is wrong
  often enough to be worthless.
- **Read the query plan**, not just the duration. `EXPLAIN` names the missing
  index; a timing does not.
- **Measure at two sizes at least** — demo and stress — so the *shape* of the
  curve is visible. A query that is linear at 200 rows and quadratic at 20,000
  looks identical in a single measurement.
- **Warm and cold separately.** Report which.
- **Isolate the variable.** One change per measurement.
- **Seed through the real write path, not raw inserts.** A seeder that fabricates
  rows directly skips model events, defaults and invariants, producing a dataset
  that looks fine and measures nothing — orders that reserve no stock, inventory
  rows disagreeing with their own items. Slower to seed, and the only kind of
  measurement worth having.
- **Check the seed scales linearly too.** Log a checkpoint every N rows: if the
  last batch takes the same time as the first (measured: 14.1s vs 14.0s per
  2,000 products, empty → millions of rows), the write path has no hidden
  quadratic. That is a free finding from a seed you were running anyway.
- **Confirm row counts by querying, not from the seeder's own total.** The
  seeder reports what it believes it did.
- **Clean up after measuring**, and say how. Stress rows left behind silently
  become the "demo" data someone later presents from.

## Load testing

Distinct from the query-level work above: **load testing at 2–3× expected peak**
is an operational-readiness gate, not a query optimisation. It answers "does it
fall over", not "is this query slow".

Watch saturation, not just latency: connection-pool exhaustion, queue depth,
and memory are what actually break first, and a latency graph alone hides them
until the moment they do.

**Size-scaling and concurrent-load are different questions — don't let one
stand in for the other.** Everything above answers "does a query slow down as
the table grows", measured one request at a time. It says nothing about many
users at once. Split that second question in two, because the halves have very
different value:

- **Race correctness under concurrency** — does simultaneous access corrupt
  state — is the half that matters for anything touching money or stock, and it
  is provable locally with two real processes against one row, verified by
  deleting the lock and watching the test fail (see `concurrency-testing.md`).
- **Raw throughput** — hundreds of simulated users, k6/`wrk` — is legitimately
  skippable when the ceiling would be a property of the dev machine (local
  worker counts, default database tuning) rather than of the application, and
  so would not predict production capacity. **Skipping it is a defensible
  decision; leaving it unstated is not.** Write down which one you skipped and
  why, so the gap is a decision rather than an oversight.

## Tooling

- **Query log + in-process request dispatch** for per-request query counts and
  timings — the highest-value tool, and usually already in the framework.
- **`EXPLAIN`** for plans. `type: ALL` means full scan; a `rows:` figure near
  the table size with a low `filtered:` percentage means the index in use cannot
  narrow on the columns that matter.
- **A load generator** (k6, `wrk`) for throughput, when the capacity question is
  real — see the caveat above.
- **The browser performance trace** for front-end work, which server-side
  numbers deliberately exclude.

## Rate limiting — a performance control, not only a security one

A throttle sits at the intersection of this file and `security-review.md`:
it is applied for abuse-prevention reasons but its correctness is a
performance measurement, because "does it limit" only means something
against an actual attempt rate.

### Every unauthenticated write needs one — this is a sweep, not a judgment call per form

**A rate limit is a property of the endpoint, not of how sensitive the
endpoint *feels*.** A login form gets one because throttling is culturally
part of the login idiom; a newsletter signup or a contact form is skipped
because nothing about "send us a message" suggests abuse — and that gap is
exactly where an unthrottled form sits for months. Do not reason about each
form individually. Enumerate every route accepting an unauthenticated
write, then check each one has a limiter:

```bash
# One example shape — adapt the discovery to the framework:
grep -rL "RateLimit\|Throttle" app/Http/Controllers app/Livewire 2>/dev/null
```

A file with no hit is not automatically a finding — some writes are safe
unthrottled (idempotent, or already gated some other way) — but every file
with no hit needs a one-line justification, not silence.

### Measuring whether a limit actually limits

State a before/after pair from a real attempt run, not "a limiter is
configured." Configuration proves intent; measurement proves effect:

```
newsletter signup, 12 rapid attempts, single session:
  before: 12 accepted, 0 refused
  after:   5 accepted, 7 refused
```

**Include a legitimate-use control alongside the abuse simulation.** A
limiter set so aggressively that a real user's second attempt (a mistyped
password, a resubmitted form after a validation error) gets refused is a
different bug wearing a fix's clothes — measure that the Nth *legitimate*
attempt inside a normal usage pattern still succeeds, not only that rapid
abuse gets refused.

### Choosing the key: this is the part that actually needs judgement

The rate-limit **key** — what identifies "one caller" for counting purposes
— is the one decision in this whole section that is not mechanical, and
getting it wrong can be worse than no limit:

| Key | Correct when | Wrong when |
|---|---|---|
| Requester's network address | No account exists yet, or the account itself is what's being probed for | Multiple legitimate users share an address (NAT, corporate egress) — locks out innocent traffic alongside the attacker |
| The account/user id | An authenticated action where the account itself is the asset under attack (e.g. a change-password flow taking the current credential) | Never for an unauthenticated action — there is no id yet to key on |
| **The value being submitted** (an email address, a coupon code) | Almost never, for an *enumeration* defence | **Keying an enumeration defence on the value being enumerated hands an attacker the full attempt budget for every value tried** — an attacker walking a sequential id range or a list of guessed emails gets N attempts *per guess* rather than N attempts total, which is not a limit on the thing that matters |

The failure mode in that last row is subtle enough to be worth restating
directly: if the defence exists to stop someone from *discovering which
values are valid*, keying the counter on the value itself removes the
defence precisely for the attack it exists to stop, while still looking
correctly configured under a single-value test.

### Two windows, two purposes, on the same endpoint

A single flat limit trades off between "stops a burst" and "stops sustained
low-and-slow abuse," and a single count-per-window cannot do both well.
Consider a short window for burst protection and a longer, higher-ceiling
window for sustained-rate protection, independently — this matters most on
account-creation and credential endpoints, where sustained abuse
economically outweighs bursts (an attacker who knows a hard burst limit
exists simply spaces requests out under it).

## Front-end

Core Web Vitals — LCP, CLS, INP — measured with a real browser trace rather
than a synthetic score. Note that a dev server with unbundled assets produces
numbers unrelated to production; measure against a production build.

## Checklist

- [ ] Correctness green before starting
- [ ] Stress seeders run; row counts recorded alongside every figure
- [ ] Measurements taken at two data sizes to reveal the curve
- [ ] Query plans read, not only durations
- [ ] N+1 checks as query-count assertions on every list page
- [ ] Warm/cold stated
- [ ] Front-end measured against a production build, not the dev server
- [ ] Every unauthenticated write route checked for a rate limiter — a miss justified, not silent
- [ ] Limiter effect measured with a real before/after attempt count, not assumed from configuration
- [ ] A legitimate-use control included alongside the abuse simulation
- [ ] Rate-limit key checked against the table above — never the value being enumerated, for an enumeration defence
