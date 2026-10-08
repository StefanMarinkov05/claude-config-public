# Post-deployment testing

Testing a system that is **live, shared, and not yours to break**. Everything
in the other references assumes a disposable local environment where a
rolled-back transaction is a safety net and a crashed container is an
inconvenience. None of that holds here.

The defining constraint: **your testing is indistinguishable from an attack.**
Same requests, same payloads, same log entries, same alerts. The difference is
authorization and intent — and neither is visible from inside the system you
are probing.

## Before anything: authorization in writing

Do not begin without **explicit, written, scoped permission** naming:

- **Which hosts and domains.** Exactly. A wildcard is not a scope; a shared
  hosting neighbour or a third-party subdomain is someone else's system.
- **Which environments.** Staging and production are different authorizations.
- **What techniques are permitted.** Read-only probing, active injection, and
  denial-of-service are three separate permissions.
- **A time window.**
- **A named contact reachable during it**, who can confirm "that alert is us."
- **What to do on finding a live compromise** — because you might.

If you cannot produce that document, you are not testing, and the right move
is to say so and stop.

**On third-party services this is stricter, not looser.** A payment provider,
a courier API, or a hosting control panel has its own terms; your client's
permission does not extend to them. Their sandbox is the only environment you
may attack.

## The core rule: read-only by default

In production, escalate deliberately through these tiers, and stop at the
lowest one that answers the question:

| Tier | Examples | Risk |
|---|---|---|
| **0 — Passive** | Response headers, TLS config, DNS, public pages, published JS bundles | None |
| **1 — Authenticated read** | Log in as a test account, browse, read your own data | Negligible |
| **2 — Bounded write** | Create/modify data owned by a test account, then clean it up | Contained |
| **3 — Active probing** | Injection payloads, authorization bypass attempts, fuzzing | Real — needs explicit sign-off |
| **4 — Destructive** | Load testing, deletion, resource exhaustion | Usually forbidden in production |

**Most valuable findings live in tiers 0–2.** Missing headers, a debug page, an
IDOR reachable by changing an id in a URL you already legitimately hold — none
of these require an attack.

## The thing that makes production different: you cannot roll back

Every technique in `input-abuse-techniques.md` and `security-review.md`
applies, with one change: **the safety mechanism is gone.**

Locally, a probe wraps in a transaction that never commits. In production the
write is real, indexed, replicated, backed up, and possibly emailed to a
customer. So:

- **Use dedicated test accounts**, tagged so they are identifiable in the
  data. Never probe with a real customer's account, even with their password.
- **Prefix test data recognisably** (`ZZTEST-`, a reserved email domain) so
  cleanup is possible and so a colleague reading the database at 3am knows what
  it is.
- **Know the cleanup path before you create anything.** Soft deletes, audit
  logs, and event streams mean "delete the row" is often not enough.
- **Never probe a destructive action to see what happens.** Read the code, or
  test it in staging. A delete that turns out to cascade is not recoverable by
  apologising.

**Side effects reach real people.** An order state transition can send an
email, charge a card, notify a courier, or decrement stock a real customer was
about to buy. Enumerate the side effects of any write *before* making it —
which is exactly the invariant work in `thinking-in-invariants.md`, done in
advance rather than discovered.

## Not being mistaken for an attacker

Your traffic will hit rate limiters, WAFs, fraud scoring, and on-call pagers.

- **Announce the window** to whoever watches the alerts, and confirm receipt.
- **Use a fixed, known source address** where possible, and give it to them.
- **Set an identifying `User-Agent`** — `SecurityTest/<name>/<ticket>` — so a
  log line explains itself without anyone having to ask.
- **Throttle deliberately.** A scanner at default parallelism looks exactly
  like an attack and can degrade the service for real users, which converts
  your test into an incident.
- **Stop immediately if the service degrades**, and say so. A pass that causes
  an outage costs more than it found.

And the inverse: **if you find evidence of a real, existing compromise, stop
and escalate.** Continuing to probe destroys forensic evidence and confuses
your traffic with the attacker's.

## What only production can tell you

This is the reason to be here at all. These are invisible locally:

### Configuration that differs by environment

**The highest-yield category, because these fail open.**

- **Debug mode.** The single most valuable check. A debug page hands an
  anonymous visitor the framework version, the internal directory layout, and
  proof of a reachable crash. Trigger a benign 404 and a malformed route
  parameter, then read the **response body**, not the status code.
- **Version banners.** `Server` and `X-Powered-By`. Note these are set by the
  web server and language runtime, so a fix verified in a local Docker stack
  does **not** carry to a host that provisions its own — verify per
  environment.
- **Security headers.** They are per-response and per-server. Check the app's
  pages, the admin panel (which may build its own middleware stack and so miss
  a group-scoped middleware), and **static assets**, which the web server
  serves directly without the application touching them.
- **TLS**: version, cipher suite, certificate chain, HSTS, and expiry.
- **CORS**: a wildcard origin with credentials is a finding.
- **Directory listing and stray files**: `/.env`, `/.git/config`,
  `/storage/logs/laravel.log`, `/phpinfo.php`, backup archives. Cheap, and
  occasionally catastrophic.

### Things that only exist when the system is running

- **Scheduled tasks and queue workers actually firing.** A local container
  with no scheduler means schedule entries are correct and never run — correct
  code, silent outage. Verify by observing the effect, not by reading the
  schedule definition.
- **Real third-party behaviour.** An integration that has only ever run against
  a fake is unproven: your tests prove your arithmetic, state machine, and
  endpoint behaviour, not that the provider accepts the exact request shapes
  you send. Sandbox and live environments also differ — a sandbox that accepts
  a request the live API rejects is a production-only bug by construction.
- **Webhook delivery end to end.** Signature verification against the
  provider's real signature, with the real API version. A version pinned at
  endpoint creation and drifting from your SDK is a production-only failure.
- **Secret rotation.** During a roll, providers commonly sign with *every*
  active secret; a single-secret implementation rejects events signed only with
  the new one and silently drops real traffic for the rotation window.
- **Session and cache behaviour under real concurrency.** Session-regenerating
  middleware under load, cache stampedes, and connection-pool exhaustion appear
  at a scale no local run reaches.
- **Data volume.** A query linear at 200 rows and quadratic at 200,000 looks
  identical in a single local measurement.
- **Backups, by restoring one.** An untested backup is a hope, not a backup.
  This is the check most often skipped and most expensive to have skipped.

### Deployment correctness itself

- **The artifact is the one that was tested.** If it was rebuilt per
  environment, you tested one thing and shipped another. Check the deployed
  build identifier against the commit.
- **Migrations applied and applied once.** Compare the applied-migration list
  against the repository.
- **Rollback rehearsed**, not assumed — before you need it, not during an
  incident.
- **Post-deploy smoke test**: the critical path (sign in, add to cart,
  checkout) exercised once against the live system, deliberately, rather than
  waiting for a customer to find it broken.

## Smoke testing a deploy

Small, fast, and the same every time. It answers "is this deploy fundamentally
broken", not "is the feature correct":

1. The home page and one deep page return 200 with expected content.
2. A static asset loads (catches an unbuilt or unpublished asset pipeline).
3. Sign-in works for a test account.
4. One authenticated read returns that account's own data.
5. A health/readiness endpoint reports healthy, including its dependencies.
6. Error rate and latency are watched for a bake period.

**Automate it and run it on every deploy.** A smoke test performed manually
"when we remember" is a smoke test that stops being performed.

## Traps

**Testing against production while believing it is staging.** Check the
hostname before every destructive-ish action. Environments that look identical
by design are indistinguishable by accident. Colour the environment in the UI
if you control it.

**The tooling defaults are tuned for a lab, not a live system.** A scanner's
default parallelism, retry, and payload set assume a disposable target. Turn
them down before pointing them anywhere real.

**A scan that reports clean because it never authenticated.** A spider that
follows a logout link ends its own session, and every later request is scanned
as an anonymous guest — silently, with a successful exit code. Prove coverage
from the *server's* access logs, not the scanner's summary
(`security-tooling.md`).

**Caching hides the finding, or fakes one.** A CDN or page cache may serve a
stale response — so a header you "fixed" may still be cached, and a leak you
"found" may be a cached artifact of an earlier deploy. Check with cache-busting
and confirm at the origin.

**A load balancer means you tested one instance.** A misconfigured node behind
a round-robin appears intermittently. If a finding reproduces one time in
three, suspect a partial rollout before suspecting a race.

**Read replicas lag.** A write followed immediately by a read can legitimately
return stale data. That is not a bug; asserting on it produces a false finding.

**Your own test data becomes production data.** Test orders in revenue
reports, test users in a customer count, a test article on the public site. Tag
it, and confirm the analytics and reporting paths exclude it.

**Rate limiting masks the result.** After a few attempts you are testing the
rate limiter, not the endpoint. Confirm which one you are looking at before
concluding a probe was "blocked."

**GDPR and personal data.** Production data is real people's. Do not export it,
paste it into a ticket, or screenshot it. A finding is reproducible with an id
and a description; a screenshot of a real customer's address is a second
incident.

## Documenting a production pass

`documentation-standards.md` applies in full, plus:

- **Record the environment and the deploy identifier**, not just the date. A
  production finding is about one build.
- **Redact real data** from every artifact. Reproduce with test accounts and
  synthetic values where possible; where not, describe rather than show.
- **State which findings are environment-specific.** "Debug mode on" is a
  production configuration finding, not a code defect, and the fix lives
  somewhere different.
- **List what you deliberately did not do**, and why — the destructive tiers
  you declined are part of the coverage statement, not an omission.
- **Report anything urgent immediately**, out of band, before the write-up. A
  live exposure does not wait for a document.

## Checklist

- [ ] Written, scoped, time-bounded authorization in hand
- [ ] Named contact aware of the window and reachable
- [ ] Identifying `User-Agent` and known source address agreed
- [ ] Test accounts created and tagged; cleanup path known before any write
- [ ] Side effects of every intended write enumerated in advance
- [ ] Started at tier 0 and escalated only as far as the question needs
- [ ] Debug mode, banners, headers, TLS, CORS, stray files checked
- [ ] Static assets and the admin stack checked separately from app pages
- [ ] Scheduled tasks and queue workers observed *firing*, not just configured
- [ ] Backup restore rehearsed
- [ ] Deployed artifact matched to a commit; migrations verified
- [ ] Smoke test automated and running per deploy
- [ ] Hostname confirmed before anything with a side effect
- [ ] Coverage proven from server logs, not the scanner's summary
- [ ] Throttled; stopped at the first sign of degradation
- [ ] No real personal data in any artifact
