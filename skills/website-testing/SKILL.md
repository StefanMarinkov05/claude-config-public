---
name: website-testing
description: Full testing suite for a web application - static analysis, unit/integration/system tests, automated in-CI browser testing (Playwright/Cypress/Pest-browser/Dusk - smoke, responsive/overflow, lifecycle E2E, render-speed, 3-D-Secure-class payment challenges), manual and exploratory testing, debugging, live UI testing through an MCP browser, security testing (DAST scanners, injection techniques, authorization probing), concurrency and race testing, performance testing, acceptance testing, CI/CD gating through deployment, rollback, and observability, and post-deployment testing of a live system. Also carries the preventive security baseline (injection classes, auth/session/upload rules, secrets hygiene) and the per-PR security review checklist. Use whenever testing, probing, breaking, auditing, or verifying a website or web app; whenever writing or reviewing tests; whenever asked "is this safe/correct/fast enough"; whenever shipping, deploying, or rolling back; whenever a bug needs reproducing or a finding needs documenting. Covers how to run each layer, which layer finds which bug class, and how to write up what was found.
---

# Website testing

A complete testing library for a web application. Each layer finds a
different bug class; no single one covers more than its own. The expensive
mistake is running one and believing the job is done.

Built from real passes against a Laravel/Livewire/Filament e-commerce
codebase. The techniques generalise; the worked examples are kept because a
concrete bug teaches more than an abstract rule.

## The governing principle

**A green result whose mechanism was never confirmed proves nothing.**

A scanner reporting zero findings against an app it never actually reached,
a test that has never been observed failing, a probe that crashed before it
reached the code under test — all three look exactly like success. Most of
this skill is about not fooling yourself that way.

Three rules follow, and they recur in every reference below:

1. **Every test must be proven able to fail.** Flip the assertion, or remove
   the fix, and watch it go red. See `references/test-quality.md`.
2. **Every probe table needs a control row** — a case that is *required to
   pass*. Without one, a probe that never reaches the target is
   indistinguishable from a defence that works.
3. **Verify against the running system, not by reading code.** Type checkers
   prove types, linters prove style, neither executes behaviour.

## Which layer finds what

| Layer | Finds | Misses | Reference |
|---|---|---|---|
| **Static analysis** | Type errors, undefined refs, style drift, some security constants | Anything runtime; all behaviour | `references/static-analysis.md` |
| **Unit / integration / system** | Regressions, logic errors, contract breaks | What you didn't think to assert | `references/automated-testing.md` |
| **Manual / exploratory** | Everything the tests' author never imagined | Regressions (nobody re-runs it) | `references/manual-testing.md` |
| **System simulation (E2E)** | Cross-step state bugs a single-Action test never spans | Anything not walked — coverage is only as good as the enumerated states | `references/system-simulation-testing.md` |
| **Automated browser (in CI)** | JS executing, CSS applying, responsive/overflow, asset load, console errors, cross-frame payment flows — a regression net on every push | Exhaustive coverage (slow); logic edge cases; anything not scripted | `references/automated-browser-testing.md` |
| **UI (MCP browser)** | Rendering, interaction, console errors, real-session auth — exploratory, once, by a human | Backend logic; off the happy path; regressions (nobody re-runs it) | `references/ui-testing-mcp.md` |
| **Input abuse** | Crashes, silent wrong answers, injection | Authorization, business logic | `references/input-abuse-techniques.md` |
| **Security — static review** | Authorization, IDOR, trust boundaries, business logic | Misconfiguration, headers | `references/security-review.md` |
| **Security — DAST** | Misconfiguration, missing headers, known signatures | Authorization, business logic | `references/security-tooling.md` |
| **Payment provider (Stripe et al.)** | Real API acceptance, webhook signing, 3DS-equivalent challenges | What a faked client cannot — provider-side behaviour | `references/stripe-testing.md` |
| **Concurrency** | Races, lost updates, write skew, idempotency | Anything single-process can prove | `references/concurrency-testing.md` |
| **Debugging** | The cause behind a symptom | Nothing — but it is not a test | `references/debugging.md` |
| **Performance** | Slow queries, N+1, scale cliffs | Correctness | `references/performance-testing.md` |
| **Acceptance** | "We built the wrong thing" | Implementation defects | `references/acceptance-testing.md` |
| **CI/CD** | Whatever you wired into it, on every push | Whatever you didn't | `references/cicd-gating.md` |
| **Post-deployment** | Environment config, real integrations, scale, deploy correctness | Anything you're not authorized to touch | `references/post-deployment-testing.md` |

## Start here: what are you attacking?

**`references/thinking-in-invariants.md`** is the conceptual entry point. The
techniques below are only as good as the target you point them at, and naming
what must always be true — especially the invariants the schema *cannot*
express — is what turns a click-around into a pass with a hit rate. Read it
before a first pass on an unfamiliar system.

## Documentation is part of the work

A finding that is not written down is a finding that will be rediscovered.
**`references/documentation-standards.md` is not optional reading** — it
covers when to screenshot, when to use bug-bounty format, how to record a
negative result, and how to write a gap honestly. Read it before writing up
any pass.

**Security findings specifically get their own format** —
`references/vulnerability-documentation.md`. It is stricter than the general
standard above: a technical record for the team, a separate and deliberately
thinner assurance summary for anyone outside it, and an explicit
**expected-behaviour contract** per finding (which of 404 / 403 / silent
no-op / generic rejection / exception / rollback / deliberate deception the
system uses, and why that one) — so a later change that alters the
mechanism is a visible regression against a stated contract, not a
quietly different behaviour nobody notices moved.

## Order of work

For a **full sweep**, run in this order — each layer's output narrows the
next:

1. **Static analysis** — cheapest, catches the trivial, must be green first.
2. **Automated tests** — establishes the baseline still holds. Includes the
   **automated browser suite** (`references/automated-browser-testing.md`)
   if one exists — smoke, responsive, and lifecycle E2E run here, on every
   push, as a regression net.
3. **Static security review** — the reasoning layer; finds the expensive bugs.
4. **Live probing** — confirms what step 3 suspected, in a real browser
   (the *manual* MCP pass — exploratory, not the scripted suite from step 2).
5. **DAST + dependency scan** — the mechanical sweep for misconfiguration.
6. **Concurrency** — for every contested resource named in step 0.
7. **Performance** — only meaningful once behaviour is correct.
8. **Post-deployment** — only what the live environment alone can answer, and
   only with written authorization (`references/post-deployment-testing.md`).
9. **Write it up** — per `references/documentation-standards.md`.

Step 0, before all of them: **name the invariants**
(`references/thinking-in-invariants.md`).

For a **targeted pass**, jump to the relevant reference. Do not run steps 4–5
without 3: a scanner without a reasoning pass finds headers and misses
authorization.

## Model and effort

Reasoning quality is not uniform across these layers, and downgrading the
wrong half is the single most damaging configuration mistake — it is silent.

| Task | Model | Effort | Thinking |
|---|---|---|---|
| Static security review, authorization, IDOR | Opus | `xhigh` | on |
| Reasoning about a suspected finding; writing the exploit | Opus | `xhigh` | on |
| Test-quality judgement (does this test deserve to exist) | Opus | `high` | on |
| Designing a browser lifecycle E2E / payment-challenge spec (which steps, cross-frame targets, async webhook race) | Opus / Sonnet | `high` | on |
| Driving a scanner, triaging output, writing the report | Sonnet | `high` | optional |
| Browser smoke/responsive specs once the probe pattern is known; batching for speed; CI YAML | Sonnet | `medium` | off is fine |
| Mechanical fixes once understood; screenshotting; clicking | Sonnet | `high` | off is fine |

**Why this matters more here than elsewhere.** On most work a model
downgrade trades a little quality for cost. On security review it trades an
*invisible* amount of quality for cost, and the thing made invisible is the
entire point: a downgraded model still reads every file, still runs every
scan, still produces a confident report — it simply misses the authorization
bug that needed one more inference, and reports the app clean. You do not get
an error. You get a false all-clear that reads exactly like a true one.

Move the **effort** lever, not the **model** lever, and split by phase.

**A subtler trap: switching models mid-session does not re-run the reading.**
A second model inherits a mental model of what is worth looking at, assembled
under the first one's judgement. That is fine for a mechanical phase. It is
not fine to then ask the downgraded model a *new reasoning question* ("is
this other path also vulnerable?") — it will answer from a weaker footing
while appearing to have full context. Ask reasoning questions on the
reasoning tier, before you downgrade.

## Problems to take into account

Hard-won, from real passes. Each is expanded in its reference.

- **A disabled or hidden control is not security.** A test that submits
  through the UI can pass with the server-side guard deleted, because the
  form never sent the field. Target the seam a crafted request reaches.
- **A wrong answer returns 200.** `assertOk()` proves the request survived,
  not that it survived *correctly*. Assert the resulting data.
- **`intval()` of a non-empty array is `1`.** Type-juggling turns malformed
  input into a *valid* value, which is worse than a crash.
- **A probe can fail before reaching the target.** All-refused reads as a
  clean pass. Always include a control.
- **Framework hooks do not all fire.** `updated*` hooks never run on first
  page load from URL hydration — so validation living only there is bypassed.
- **A modal-opening UI action never returns to an awaiting driver.** It will
  hang until timeout. Drive the underlying call instead.
- **Clean on one property says nothing about the one below it.** Type-driven
  bug classes are per-property, not per-file, per-component, or per-session.
- **A scanner's session expires mid-scan** and every later request is scanned
  as a guest, silently, with a successful exit code.
- **Static checks pass on wrong behaviour.** Green types, green lint, wrong
  answer is the most common shape of a real bug.
- **A transaction is not a lock.** `REPEATABLE READ` guarantees a *consistent*
  snapshot, not a *current* one — so a check-then-act race survives being
  wrapped in a transaction.
- **A concurrency test that never raced passes.** A barrier that stops aligning
  makes the workers sequential, which is the failure mode that looks like
  success.
- **A deletion test can stay green for four documented reasons** — a composed
  call raised the same exception, a second guard subsumes the first, a
  constraint backstops it, or a disabled control never sent the field. Green
  after deletion means *find which other mechanism caught it*, not "the guard
  was redundant".
- **In production you cannot roll back.** Every local probe assumes a
  transaction that never commits; live, the write is real, replicated, and
  possibly emailed to a customer.
- **Your testing is indistinguishable from an attack.** Same requests, same
  logs, same pagers. Authorization and announcement are what separate them.

## Project-specific rules override this skill

If a project's own documentation contradicts anything here, **the project
wins** — say so explicitly rather than silently diverging. This skill is the
general library; a repository's `CLAUDE.md`, ADRs, and testing docs are the
local law.
