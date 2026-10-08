---
name: agent-orchestration
description: Designing and running multi-agent AI dev teams - team topology, task decomposition into agent-sized units, role definitions (planner, implementer, reviewer, tester, debugger), handoff contracts, and parallelization rules. Use whenever building or improving an agent pipeline, writing agent prompts/personas, deciding how to split work across Claude Code subagents or multiple sessions, or when an agent pipeline is producing inconsistent or broken output. Trigger for any mention of "agents", "subagents", "dev team of AIs", or orchestrator patterns.
---

# Agent Orchestration: Running an AI Dev Team

A multi-agent pipeline is a distributed system where every node hallucinates occasionally. Design for verification and small blast radius, not for trust.

## Team topology (default)

Start with the smallest team that has separated concerns - 4 roles, one orchestrator:

- **Planner**: turns a requirement into a task DAG with contracts (see requirements-to-spec skill). Writes, never codes.
- **Implementer(s)**: one task at a time, owns only the files in its task scope. Can run in parallel when tasks don't share files.
- **Reviewer**: adversarial reader (see code-review skill). Never fixes - only rejects with a defect list; fixes go back to the implementer. Separating author from fixer keeps the reviewer honest.
- **Tester**: writes/runs tests against the *contract*, not against the implementation. Ideally never sees the implementation before writing tests (prevents tests that enshrine bugs).
- **Orchestrator** (you or a coordinating agent): routes work, enforces gates (see verification-gates skill), owns the merge.

Add roles only when a failure class demands it: debugger (recurring broken builds), security reviewer (before any deploy), docs agent (drift in READMEs). Every added agent adds handoff cost - the same rule as human teams.

## Task decomposition rules

- Agent-sized task = completable in one focused session with **all needed context in the task file**: goal, contract (exact interfaces/types/endpoints), file scope (may touch / must not touch), done-criteria (checkable), and pointers to relevant docs.
- Decompose along **interface boundaries**, not effort: two tasks sharing a file must be serialized; tasks touching disjoint files can parallelize.
- Contract-first: the planner freezes interfaces (function signatures, API shapes, DB schema) *before* parallel implementation starts. Parallel agents integrating against guessed interfaces is the #1 source of merge chaos.
- Each task ends in a **verifiable artifact**: code + passing tests + updated task file with status. "I refactored some things" is not an artifact.

## Handoff protocol

All coordination through **files on disk, not conversation memory** (see context-handoff skill):
- `plan/tasks/NNN-name.md` - task spec (planner writes, implementer updates status)
- `plan/decisions.md` - ADR-lite log any agent appends to when it makes a judgment call
- `plan/interfaces.md` - the frozen contracts, single source of truth
- Each agent's first action: read its task file + interfaces.md. Last action: update its task file with what was done, what was assumed, what's open.

## Orchestration loop

1. Planner produces task DAG → you review the plan (cheapest intervention point - a bad plan multiplies through every agent).
2. Dispatch ready tasks (dependencies met, files unlocked) to implementers, in parallel where safe - each parallel agent in its own git worktree (see git-workflow), never sharing a working directory. For high-uncertainty tasks (one-way doors, novel algorithms - never routine CRUD), dispatch **competitively**: same contract to 2 implementers with different approach hints; the reviewer compares against the contract and picks or splices. 2x token cost, justified exactly when design is genuinely unclear.
3. Each completed task passes the verification gate (build + tests + scope check) → reviewer → tester. Failures route back with the defect list attached; the implementer gets the *original task + defects*, not a fresh vague prompt.
4. Two consecutive failed fix attempts on the same task = escalate to you. Agents looping on their own bug burn tokens and often make it worse - that's the human-attention trigger.
5. Merge in dependency order; run the full suite after each merge, not just per-task tests.

## Model routing (cost/quality)

Strongest model for: planning, review, debugging hard failures, security - judgment-heavy, error-expensive. Cheaper/faster model for: boilerplate implementation against a tight contract, test scaffolding, doc updates. A tight contract is what makes cheap models safe; vague tasks need expensive models.

## Failure modes and their fixes

- **Confident integration of garbage** → gates are missing or advisory; make them blocking (verification-gates).
- **Agents overwriting each other** → file-scope not enforced; serialize or re-split tasks.
- **Drift from the plan** → agents making silent scope decisions; require decisions.md entries and reject out-of-scope diffs.
- **Context bloat/loss across steps** → handoffs via chat history instead of state files (context-handoff).
- **Reviewer rubber-stamping** → reviewer sees the implementer's reasoning; give the reviewer only code + contract, not the sales pitch.

## Starting rule

Pipeline v1 = planner → 1 implementer → reviewer → tester on a small real feature. Measure where it breaks; add parallelism and roles from evidence. Building the 10-agent org chart first is the agent version of premature microservices.
