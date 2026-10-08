---
name: project-planning
description: How to scope and plan software projects from idea to shippable milestones. Use whenever a new project, feature, MVP, milestone, or rewrite is being started or estimated - including when the user says "help me plan", "break this down", "how long will this take", "what should v1 include", or pastes a vague product idea. Also use when a project feels stuck or scope is creeping. Produces scope documents, milestone plans, and risk registers.
---

# Project Scoping & Planning

Plans exist to expose risk early and force scope decisions before code makes them expensive. The artifact matters less than the thinking.

## Phase 1 - Frame (before any task list)

Answer in writing, max one page:

1. **Problem & user**: who hurts, how, today? One sentence per.
2. **Success metric**: the single number or observable behavior that means "it worked". If you can't name one, the project isn't defined yet.
3. **Non-goals**: explicitly list what v1 will NOT do. This list is the most valuable part of any scope doc - it's the anti-scope-creep contract.
4. **Constraints**: deadline, budget, team, existing systems, compliance.
5. **Riskiest assumption**: the thing that, if false, kills the project. Plan to test it first, not last.

## Phase 2 - Slice into milestones

- **Walking skeleton first**: milestone 1 is always a thin end-to-end path through every layer (UI → API → DB → deploy), doing one trivial real thing. It de-risks integration and deployment on day one, not week six.
- Each subsequent milestone is a **vertical slice** (a complete user-visible capability), never a horizontal layer ("do all the backend, then all the frontend" is how projects die undemoable).
- Every milestone must be **demoable and shippable in principle**. Definition of done: deployed, tested, documented.
- 3-6 milestones for anything under 3 months. More means slices are too thin or the project is too big to plan honestly - plan the first 3 and re-plan after.
- Order milestones by **risk first, then value**. Attack the riskiest assumption in milestone 1-2 while it's cheap to cancel.

## Phase 3 - Break milestones into tasks

- Tasks of 0.5-2 days. Anything estimated over 2 days is unanalyzed - split it or spike it.
- **Spike** (timeboxed research task, output = a decision, not code) anything with genuine unknowns before estimating it.
- For each task note dependencies; the dependency chain reveals the critical path. Parallelize off-critical-path work.
- Include the invisible tasks people forget: environment setup, CI/CD, seed data, auth, error handling, logging/monitoring, data migration, documentation, deployment runbook. These are typically 30-40% of real effort.

## Estimation Rules

- Estimate in **ranges** (best/likely/worst), never single points. Sum likely × 1.5 as your commitment number - the multiplier covers integration friction and the unknown unknowns, which always exist.
- Use **reference-class estimation**: "the last similar feature took X" beats bottom-up guessing.
- Never negotiate the estimate; negotiate the **scope**. When the deadline is fixed, cut features from v1 (move to non-goals), don't compress the numbers.
- Track actuals vs estimates on the first milestone and recalibrate the rest. Your personal multiplier is empirical data.

## Risk Register (living doc)

Table with: risk | likelihood (H/M/L) | impact (H/M/L) | mitigation | owner | trigger. Review at each milestone. Anything H/H gets a mitigation task in the current milestone.

Typical top risks: third-party API doesn't do what docs claim (spike it), data model wrong (prototype with real data), performance (load-test the skeleton), scope creep (enforce non-goals list), single-person knowledge silos (docs + pairing).

## Scope-Creep Protocol

New request mid-project → it goes to one of: (a) v2 backlog, (b) swapped in for an equal-sized v1 item (name the item being removed), or (c) deadline formally moves. Never silent absorption. Write the decision down.

## Deliverable Templates

**Scope doc** (`docs/scope.md`): problem, users, success metric, non-goals, constraints, riskiest assumptions, milestone list.
**Milestone plan** (`docs/plan.md`): per milestone - goal, demo criteria, task list with estimates and dependencies, risks addressed.

When asked to plan something, produce these two documents populated, plus the risk register. Ask at most one clarifying question first if the success metric or deadline is unknowable from context; otherwise state your assumptions inline and proceed.
