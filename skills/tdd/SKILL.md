---
name: tdd
description: Test-driven development - the red-green loop, pre-agreed test seams, and test anti-patterns (tautological, implementation-coupled, horizontal slicing). Use when building features or fixing bugs test-first, when the user mentions red-green-refactor or TDD, when deciding where tests should live, or as the implementation discipline inside agent pipelines. Trigger also when reviewing whether existing tests are worth keeping.
---

# Test-Driven Development

The red → green loop, disciplined so it produces tests worth keeping. Complements code-quality (what to test - invariants, layers) with *how* to drive implementation from tests and *where* tests may live.

## Pre-agreed seams (the rule that tames agents)

A test lives at a **seam** - the public interface where behavior is observable without reaching inside (see codebase-design). **Before writing any test, name the seams under test and confirm them** - with the user, or in the task ticket for agent work (the planner pre-agrees seams at Phase 3, implementers may not invent new ones silently).

Why this rule carries so much weight: you can't test everything, so seam agreement is how testing effort lands on critical paths instead of sprawling over every internal function - and for agents specifically, it's the fence that prevents the classic failure of 400 lines of tests coupled to implementation details nobody wanted. A test at an unconfirmed seam is scope creep (verification-gates G2).

## The loop

1. **Red first**: write one failing test at an agreed seam. Watch it fail - a test never seen red proves nothing (it may pass vacuously).
2. **Green minimally**: only enough code to pass. No speculative features, no anticipating future tests.
3. **Repeat in vertical slices**: one test → one implementation → next test, each informed by what the last cycle taught.
4. **Refactoring is a separate stage** - after green, with the suite as the net; never mixed into the red-green cycle (and per git-workflow, a separate commit).

**Never horizontal-slice** (all tests first, then all implementation): bulk-written tests verify *imagined* behavior and shape, go insensitive to real changes, and commit you to structure before understanding exists. This is the tracer-bullet principle from project-planning applied at test scale.

## Anti-patterns (reject in review - these are G3 findings)

- **Implementation-coupled**: mocks internal collaborators, tests private methods, or verifies through a side channel (queries the DB directly instead of using the interface). The tell: refactoring breaks it though behavior didn't change. Fix: test at the seam; replace adapters (in-memory fake) rather than layering mocks.
- **Tautological**: the assertion recomputes the expected value the same way the code does - `expect(add(a,b)).toBe(a+b)`, a hand-derived snapshot, a constant compared to itself. It passes by construction and can never disagree with the code. Expected values must come from an **independent source of truth**: a known-good literal, a worked example, the spec. This is the single most common agent-written-test defect - check for it explicitly.
- **Vacuous green**: a test that was never observed red (asserts nothing meaningful, or the setup dodges the code path). Mental mutation test: flip an operator in the code - would this test notice?
- **Green for the wrong reason**: passes, but a *different* mechanism produced the result. The assertion is correct, the error type is right, the effect really was prevented — only the *attribution* is wrong, and nothing in the output distinguishes the two sources. For security and concurrency tests the mental mutation test is not enough; **actually delete the mechanism, watch it go red, restore it** (see concurrency, which specialises this). Two mechanisms cause it, needing different fixes:
  - **A nested check fired first.** The unit under test composes another that performs the same kind of check, so a subject with *no* privileges is refused by whichever runs first. Fix: grant everything the composed units need *except the one under test* — deny by exactly one, never by zero. A test actor holding no permissions at all proves nothing.
  - **A sibling guard subsumes the range.** Two guards in the same unit raise the *same* error class, and a constraint elsewhere makes one's rejected range contain the other's — every input the first refuses, the second refuses too. Fix: assert the *message*, not only the class, and add the one case only the guard under test can catch. Signal to look for: one error class with several static factories (`notPositive()`, `belowMinimum()`). Nastier than the nested case, because nothing is visibly composed — one call site, right exception class, and the subsumption lives in a database constraint.
- **Test-as-mirror**: one test file per source file, one test per method, regardless of behavior. Tests mirror the *contract*, not the file tree.

## TDD for bug fixes

The minimized repro (debugging-protocol) becomes the red test at the correct seam *before* the fix - red → fix → green → full suite. If no seam exists where the real bug pattern can be exercised (the bug needs a caller-chain a unit test can't replicate), **that absence is itself a finding**: document it and route an architecture task (codebase-design) rather than writing a false-confidence test at the wrong seam.

## When not to TDD

Exploratory prototypes (throwaway declared - project-pipeline prototype mode), UI pixel-pushing, and spikes answering "is this even possible". Write those without tests, then *rebuild* the keeper test-first - don't retrofit tests onto the spike and promote it.
