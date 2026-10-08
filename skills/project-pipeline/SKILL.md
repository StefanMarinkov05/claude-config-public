---
name: project-pipeline
description: The end-to-end router for building any software project or feature - from vague idea through planning, implementation, review, and git push/deploy. Use whenever the user says "build me...", "create an app/feature/tool/website", starts any multi-file software project, or asks where to start on one. This skill does not contain doctrine itself - it sequences the phases, names which specialist skill to consult at each phase, and enforces the gates between them. Trigger for every non-trivial build request, even a casual one-liner.
---

# Project Pipeline (End-to-End Router)

This skill is a conductor: it owns the *sequence and gates*, while specialist skills own the doctrine. On any "build me X" request, walk these phases in order. Never skip a phase silently - skipping is allowed only as an explicit, stated decision ("prototype mode: skipping gates G3+, no tests" - see Modes below).

## Phase 0 - Clarify (requirements-to-spec)

Interrogate the request: actor, outcome-not-mechanism, data in/out, volume, unhappy paths, non-goals. **If ambiguity remains that would change the architecture or scope, ask the user now** - one focused round of questions; state assumptions inline for everything minor. Output: acceptance criteria (Given/When/Then) + edge-case behavior.
**Gate**: could two developers build different things from this spec? Then don't proceed - run the grilling skill (one question at a time, with recommendations) until shared understanding is confirmed.

## Phase 1 - Plan (project-planning + engineering-reasoning)

Scope doc (success metric, non-goals, riskiest assumption) → milestones starting with a **walking skeleton** (thin end-to-end slice through every layer, deployed, in milestone 1) → tasks of 0.5-2 days. One-way-door decisions get the engineering-reasoning procedure + an ADR.
**Gate**: user has seen and approved plan + non-goals (cheapest intervention point in the whole pipeline).

## Phase 2 - Choose stack (tech-selection)

Boring-technology default, requirements-with-numbers before candidates, ADR per one-way door. If the user has an established stack (check context/memory), default to it and flag deviations rather than re-litigating.

## Phase 3 - Design contracts (database-design + api-design + codebase-design + security-baseline)

Before implementation: schema with invariants-as-constraints, API contracts (spec-first), frozen into `plan/interfaces.md`. Security consulted at *design* time (trust boundaries, authz model, data classification) - not discovered at review.
Module interfaces designed deep (codebase-design: design-it-twice on the core module, seams named), and **test seams pre-agreed** here so implementation tasks carry them (tdd skill).
**Gate**: interfaces.md exists with seams; top queries have named indexes; every endpoint has auth/authz decided.

## Phase 4 - Set up the repo & skeleton (git-workflow + devops-cicd)

Init repo with .gitignore + lockfiles before first commit; branch model declared; git-guardrails hooks installed (mechanical blocks on destructive git, mandatory for agent pipelines); CI pipeline (lint → typecheck → tests → build) from day one, even minimal; the walking skeleton runs and deploys (or `docker compose up` locally). Commit early, atomic, conventional messages.
**Gate**: clean clone → one command → running skeleton; CI green on main.

## Phase 5 - Implement, task by task (code-quality + frontend-distinctive-design + docs-and-comments)

Per task: branch `type/NNN-desc` → implement against the contract test-first at the pre-agreed seams (tdd skill; dependencies inward, illegal states unrepresentable, errors designed) → tests including named invariant tests → teaching comments and doc updates → state files updated (context-handoff). UI tasks: concept sentence first, anti-generic checklist.
Multi-agent mode: this phase is where agent-orchestration takes over dispatch; tasks parallelize only on disjoint file scopes.

## Phase 6 - Verify per task (verification-gates + code-review + debugging-protocol)

Gate stack in order: G1 mechanical (build/lint/tests) → G2 scope & contract → G3 adversarial review with [blocker]/[should]/[nit] → merge in dependency order → G4 integration (full suite + skeleton smoke test). Anything broken: debugging-protocol, never guess-and-patch. Security checklist runs on every PR touching a trust boundary.
**Gate**: red main = stop-the-line.

## Phase 7 - Ship (devops-cicd + git-workflow)

Same artifact promoted through environments; migrations land before code (expand/contract); deploy with health checks; rollback = one command, known before deploying; observability wired (structured logs, golden signals, alerts that page on symptoms). Tag the release; push. Post-deploy: smoke test + watch the dashboards for the bake period.
**Gate**: operational-readiness checklist (devops-cicd) answered.

## Phase 8 - Close the loop (docs-and-comments + project-planning)

README quickstart verified on a clean clone; architecture doc + runbook current; ADRs filed. Compare actuals vs estimates (recalibrate the multiplier); every escaped defect gets its "which gate should have caught this" retro; v2 items go to the backlog, not into scope creep.

## Cross-cutting, all phases

- **transparent-reasoning** on every recommendation and diagnosis (answer first, evidence ledger, assumptions).
- **context-handoff** state files (`plan/state.md`, `decisions.md`, `tasks/`) updated continuously - the project must survive a session restart at any phase.
- **git-workflow** discipline from the first commit to the last push.
- Ask clarifying questions whenever a decision is ambiguous and consequential; decide-and-state for the trivial ones.

## Modes (declare one at Phase 0)

- **Full** (default for real projects): all phases, all gates.
- **Prototype/spike**: Phases 0-1 compressed to a paragraph, gates G3+ waived, throwaway declared - but still git + README, and still an explicit statement of what was skipped so prototype code doesn't silently become production.
- **Feature-on-existing**: Phase 2 skipped (stack exists), Phase 3 scoped to the delta, Phase 4 replaced by "read the existing conventions first".

## Self-check for the router

At each phase transition, state in one line: phase completed, gate result, next phase, and any skipped step with its reason. That line is the audit trail of the whole build.
