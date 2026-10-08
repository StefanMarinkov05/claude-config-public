# CI/CD gating

Making the checks run automatically, and knowing exactly what a green tick
does and does not mean.

## What belongs in the pipeline

In cost order, cheapest first, so a failure returns the fastest signal:

1. **Formatter check** — seconds. Mechanical to fix.
2. **Type analyser** — under a minute.
3. **Unit + integration + system tests** — minutes; shard if needed.
4. **Dependency audit** — seconds. Advisory rather than blocking, unless a
   policy says otherwise.
5. **Concurrency tests** — slow, and must not run in parallel with themselves.
6. **DAST baseline scan** — about a minute; worth running per deploy rather
   than per push.

Full active scans, stress seeding, and browser-driven passes do **not** belong
on every push. They are periodic or on-demand.

## The trap that makes a green tick meaningless

**If CI discovers tests from a hand-maintained file list, a new test file runs
nowhere until it is added.** It does not error. The suite passes. The new test
simply does not exist as far as CI is concerned — which is worse than a failing
test, because it looks like coverage.

**Rule: a new test file is added to a shard in the same change that creates
it.** If the project has a placement rule (by default this shard, by exception
that one), follow it rather than hand-tuning a balance; let a shard that
visibly drifts be re-measured later.

The general form: **whatever mechanism CI uses to find tests, verify a newly
added file is actually picked up.** Add a deliberately failing test, push, and
confirm CI goes red. That is the deletion method applied to the pipeline
itself.

## Sharding

Split by runtime, not by directory tidiness. Two things dominate:

- **Tests with expensive per-test setup** (full reseed, permission cache
  rebuild) belong together and dominate whatever shard holds them.
- **Concurrency tests must not run under parallel test execution** — they need
  real separate connections and a wall-clock barrier; parallel workers with
  per-worker databases break both assumptions.

Re-measure occasionally. A shard split that was balanced six months ago is not.

## CI environment parity

The most common CI-only failure is an environment difference, not a code
difference:

- **Database.** CI must run the same engine and version as development.
  Constraint behaviour, ordering without `ORDER BY`, and collation all differ.
- **Time zone and locale.** A date assertion passing locally and failing in CI
  is almost always this.
- **Memory limits.** A type analyser's workers can exhaust a default limit and
  report the crash in the same shape as a real finding.
- **Environment variables.** A child process reads the environment file, not
  the test configuration — so a spawned worker can silently run against the
  wrong database.
- **Third-party credentials.** External APIs should be faked in CI. A pipeline
  needing real credentials will be disabled the first time they expire.

## What a green tick does not mean

Worth stating explicitly in the project's own documentation, because people
read a tick as "safe to merge":

- It does not mean the behaviour is right — only that the assertions written so
  far hold (`test-quality.md`).
- It does not mean the new code is covered, if the discovery mechanism missed
  it.
- It does not mean it is secure — no scanner in the pipeline finds
  authorization bugs (`security-review.md`).
- It does not mean it is fast — unless a performance gate exists
  (`performance-testing.md`).

**And if a green check does not block merging, say so.** A pipeline that is
advisory rather than blocking is a legitimate choice, but an undocumented one
leads people to assume enforcement that isn't there.

## Pre-merge discipline

Before opening or updating a pull request:

1. **Merge the target branch in and resolve conflicts as part of that same
   session** — do not leave a conflict for the PR to surface later.
2. **Re-run the full local gate afterwards.** A textually clean merge can
   combine two branches into behaviour neither had alone, and that is precisely
   what neither branch's tests cover.

## Build once, promote everywhere

**The artifact tested in CI must be the artifact that deploys.** Rebuilding per
environment means testing one thing and shipping another — and the difference
will surface exactly once, in production.

So: the artifact contains no environment names and no secrets; behaviour
differences come only from injected configuration. Tag the image with the git
SHA, so every running container is traceable to a commit.

## Deployment environment parity

Minimum ladder: **local** (one command brings the whole stack up) → **staging**
(production-shaped: same infrastructure type, same migrations, realistic
anonymised data) → **production**. Staging that does not resemble production is
theatre.

When something works in staging and fails in production, check these four
before the code:

- **Data volume** — a query linear at 200 rows and quadratic at 200,000.
- **Concurrency** — races only appear under real parallelism
  (`concurrency-testing.md`).
- **Config drift** — a value set by hand in one environment and never recorded.
- **Third-party sandbox-vs-live behaviour** — a payment or courier sandbox that
  accepts request shapes the live API rejects.

That last one deserves its own note: **an integration that has only ever run
against a fake is unproven.** Faked tests prove your arithmetic, state machine,
and endpoint behaviour; they do not prove the provider accepts the exact
request shapes you send. Record that gap honestly rather than counting the
integration as tested.

## Migrations and rollback

**Migrations are append-only after a schema freeze.** Never edit a merged
migration; always add a new one. A pipeline that reruns edited migrations
against an existing database produces divergence between environments.

**Database changes precede the code that needs them and stay backward
compatible with the still-running old version** (expand/contract). This single
rule is what makes rollback possible: if old code runs fine against the new
schema, rollback is redeploying the previous tag. Without it, rolling back
requires a down-migration under pressure, which is how a bad deploy becomes an
outage.

**Rollback must be one command and rehearsed**, not improvised during an
incident. Rehearse it before the first production deploy, not after the first
failure.

Keep a **deploy log** — who, what, when — so "what changed?" takes seconds.

## Deployment strategy

- **Default:** rolling deploy behind a health check. New instances must pass
  readiness before receiving traffic; the deploy halts on failures.
- **Higher stakes:** blue/green (two full environments, instant switch) or
  canary (small traffic share, watch the error rate, ramp).
- **Feature flags decouple deploy from release** — ship dark, enable per
  cohort, kill without redeploying. Remove flags after full rollout; flag debt
  is real.

**Post-deploy verification is part of the deploy**: a smoke test plus watching
error rate and latency for a bake period. A successful build is not a
successful deploy, and neither is a successful deploy a working release.

## Observability — the part testing depends on

Testing in production is not a slogan; it is what these three give you.

- **Structured logs** with a request id propagated across services. Level
  discipline: `ERROR` means a human should look. No PII, no secrets.
- **Metrics**: latency as p50/p95/p99 (never averages alone), traffic, error
  rate, saturation — plus a business pulse metric (orders, signups), which
  catches what technical metrics miss.
- **Traces** for multi-service paths.

**Alert on symptoms users feel**; dashboards show causes. Every page must be
actionable and linked to a runbook — a noisy pager trains people to ignore it,
which is worse than no pager.

Scheduled tasks and queue workers need a runtime that actually runs them: a
local container with no scheduler means schedule entries are correct and never
fire — fine locally, a silent outage in production.

## Operational readiness

Before the first production deploy:

1. One-command deploy **and** one-command rollback, both tested?
2. Health and readiness endpoints?
3. Logs centralised, metrics dashboarded, alerts reaching a human?
4. Backups automated **and a restore rehearsed**? An untested backup is a hope.
5. A runbook covering the top failure modes?
6. Secrets in a manager, TLS on, debug off?
7. Load tested above expected peak (`performance-testing.md`)?
8. On a solo or agent-built project, "who gets paged" is you — so tune
   thresholds to what you will actually respond to.

## Checklist

- [ ] Cheapest checks first
- [ ] New test files registered wherever CI discovers tests — verified by making one fail
- [ ] Concurrency tests excluded from parallel execution
- [ ] CI database engine and version match development
- [ ] External APIs faked; no real credentials required
- [ ] Whether a green tick blocks merge is documented
- [ ] Target branch merged and full gate re-run before opening a PR
- [ ] One artifact built once and promoted, not rebuilt per environment
- [ ] Migrations append-only and expand/contract, so rollback needs no down-migration
- [ ] Rollback rehearsed before it is needed
- [ ] Integrations that have only ever run against a fake recorded as unproven
- [ ] Backups restored at least once, not merely scheduled
