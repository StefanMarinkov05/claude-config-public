---
name: verification-gates
description: Blocking quality gates between agents or pipeline stages - machine-checkable pass/fail criteria that outputs must satisfy before the next stage consumes them. Use whenever setting up or debugging an agent pipeline, defining done-criteria for a task, deciding whether code/artifacts are ready to hand off or merge, or when agent output was accepted and later found broken. Trigger for any mention of QA gates, acceptance criteria, definition of done, or "how do I stop agents from approving bad code".
---

# Verification Gates

Agents (and tired humans) approve plausible-looking work. Gates replace judgment with checks: objective, machine-runnable where possible, and **blocking** - a failed gate stops the pipeline, it doesn't add a warning.

## Gate design principles

- **Pass/fail, no vibes.** Every criterion must be checkable by running a command or answering yes/no against an artifact. "Code is clean" is not a gate; "linter exits 0" is.
- **The Iron Law: no completion claim without fresh verification evidence.** "Done", "fixed", "passing" may only be stated alongside the command run *in this session* and its output. Claim→evidence table: tests pass → test run output with 0 failures (not "should pass", not an earlier run); bug fixed → original symptom re-tested; agent completed → VCS diff inspected (never the agent's own success report); requirements met → criterion-by-criterion checklist with evidence each. Red-flag words that mean verification is missing: "should", "probably", "seems to", or expressing satisfaction before running anything.
- **Cheap gates first** (fail fast, in cost order): does it parse → does it build → do unit tests pass → scope check → then expensive review.
- **The producer never grades itself.** The implementer reports "done"; the gate verifies. Self-certification is the root failure of agent pipelines.
- **Failure output = actionable defect list**, routed back with the original task: file:line, what rule failed, expected vs actual. "Rejected" without specifics makes the retry a coin flip.

## Standard gate stack (per completed task)

**G1 - Mechanical (scriptable, run first):**
- [ ] Builds/compiles from clean checkout
- [ ] Linter + formatter + type checker exit 0
- [ ] Full test suite passes (not just new tests)
- [ ] New code has tests; coverage on changed lines ≥ agreed floor
- [ ] No secrets/keys in diff; dependency audit clean if deps changed

**G2 - Scope & contract:**
- [ ] Diff touches only files in the task's declared scope (out-of-scope changes = automatic reject, even if "improvements")
- [ ] Public interfaces match `interfaces.md` exactly - names, types, error shapes
- [ ] All done-criteria in the task file individually satisfied, each with evidence (test name or command output)
- [ ] Judgment calls recorded in decisions.md, none smuggled in silently

**G3 - Semantic (reviewer agent, only after G1-G2 pass):**
- [ ] Invariants of the module listed in the task are tested by name
- [ ] Error paths handled per code-quality skill (no swallowed exceptions, timeouts on external calls)
- [ ] No hallucination markers: imports that don't exist, APIs used contrary to their actual signature, tests that assert nothing (`assert true`, snapshot-everything)
- [ ] No tautological tests (assertion recomputes the expected value the way the code does - expected values must come from an independent source; see tdd skill) and no tests at seams that weren't pre-agreed in the task
- [ ] Docs/comments updated where behavior changed

**G4 - Integration (after merge, before next task builds on it):**
- [ ] Full suite green on the integrated branch
- [ ] Walking-skeleton smoke test (one end-to-end request) still passes
- [ ] Migrations run cleanly against production-shaped data (if schema changed)

## Anti-gaming rules

Agents optimize for gate passage, so gates must resist Goodharting:
- Tests written by the same agent as the code satisfy G1 but not G3 - the tester/reviewer checks tests actually assert the contract (mutate the code mentally: would this test catch it?).
- Coverage floors invite assertion-free tests; G3's "tests assert invariants by name" is the counter.
- "Fixed by deleting the failing test" = automatic escalation to human.
- Any gate an agent asks to skip "just this once" is the gate doing its job.

## Calibration

Start strict; loosen only a gate that produces false positives repeatedly (document why). Track which gates catch real defects - a gate that has never fired in 50 tasks is either useless or the pipeline is excellent; check a sample to learn which. Every escaped defect (found after merge) gets a retro question: which gate should have caught this, and what check do we add?

## Human attention budget

You cannot review everything - that's why you built agents. Spend human review on: the plan (highest leverage), one-way-door decisions flagged in decisions.md, G3 rejections that repeat, and a random 1-in-N full audit of passed tasks to keep the gates themselves honest.
