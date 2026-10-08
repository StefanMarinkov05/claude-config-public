---
name: code-review
description: Adversarial code review - reading code to find defects, with a severity taxonomy, per-change-type checklists, and actionable rejection format. Use whenever reviewing a PR/diff/patch, acting as a reviewer agent in a pipeline, the user asks "review this code" or "what's wrong with this", or before merging any agent-produced code. Distinct from writing code (code-quality skill) - this is hostile reading. Trigger for every review request even if the code looks obviously fine.
---

# Code Review (Adversarial Reading)

The reviewer's job is to find the reasons this change breaks, not to confirm it works. Assume the author (human or agent) was competent and still wrong somewhere - they usually are.

## Review order (highest yield first)

1. **Does it do the right thing?** Read the task/ticket/contract first, then the diff. The most expensive defect is a perfect implementation of the wrong behavior. Check every done-criterion against evidence.
2. **Boundaries and error paths.** Correct code is usually correct in the happy path; bugs live at edges: empty/null/zero, max sizes, unicode, concurrent access, partial failure mid-operation, retries causing double-execution. For each external call: what happens on timeout, on 500, on malformed response?
3. **State and invariants.** What invariants does the touched module promise? Trace whether every mutation path preserves them - especially error paths that return early (half-updated state?). Look for TOCTOU: check-then-act on shared state. On any hit, load **concurrency** and run its review checklist - an invariant guarded on only one of the paths that can break it is not guarded, and a race test written in one process proves nothing.
4. **The tests.** Read tests as hostilely as code: do they assert the contract or the implementation? Would they catch a deliberate bug (mental mutation test: flip a `<` to `<=`, swap two arguments - does anything fail)? Assertion-free tests, snapshot-everything tests, and tests that mock the thing under test are defects.
5. **Security pass** (see security-baseline for depth): unvalidated input reaching queries/commands/HTML, authz checked per-resource, secrets in code, unsafe deserialization.
6. **Only then**: readability, naming, structure - real but cheapest to fix, so cheapest attention.

## Agent-code-specific checks

Agent-written code has characteristic defects; check explicitly:
- **Phantom APIs**: imports/methods that don't exist or have different signatures than used - verify against the actual dependency, not plausibility.
- **Contract drift**: interfaces subtly differing from interfaces.md (renamed param, different error shape).
- **Scope creep**: changes outside declared file scope, "while I was here" refactors - reject regardless of quality; they break parallel agents.
- **Overconfident comments**: comments describing behavior the code doesn't have.
- **Deleted/weakened tests** to make the suite pass - automatic escalation.
- **Duplicated logic** instead of using an existing util the agent didn't know about.

## Severity taxonomy (every finding gets one)

- **[blocker]** - wrong behavior, data loss risk, security hole, broken contract, missing invariant test. Merge is impossible.
- **[should]** - real defect or debt that's much cheaper to fix now (missing error handling on unlikely path, N+1, unclear ownership). Fix now or ticket with justification.
- **[nit]** - style/naming/preference. Never blocks; batch at the end; auto-fixable nits belong in the linter config, not review comments.

Verdict rules: any [blocker] → **reject**. Only [should]s → **approve-with-required-fixes** listed. Judgment disagreements where the author's call is defensible → comment, don't block; the author owns the code.

## Rejection format (actionable, machine-routable)

Per finding: `severity | file:line | what's wrong | why it matters | expected fix or question`. The complete defect list goes back with the original task file - the fixer must be able to work from the list alone without re-deriving your reasoning. Never "this needs work"; never a fixed rewrite from the reviewer (reviewer fixes destroy the separation that keeps review honest - exception: single-character typos).

## Reviewer discipline

- Review the diff *and* its blast radius: callers of changed functions, other implementors of changed interfaces.
- Big PRs get worse reviews (defect-detection drops sharply past ~400 lines): request a split rather than skimming.
- Don't review the author's explanation - review the code. In pipelines, give the reviewer only code + contract, not the implementer's pitch.
- Timebox: findings surface in the first focused pass; a second pass only for [blocker]-dense diffs.
- Approve means "I'd take the 3am page for this." If you wouldn't, you have unwritten [should]s.
