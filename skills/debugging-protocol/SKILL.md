---
name: debugging-protocol
description: Systematic debugging procedure - build a feedback loop, reproduce and minimize, hypothesize, instrument, fix, and regression-proof. Use whenever anything is broken - failing tests, exceptions, wrong output, flaky behavior, performance regressions, "works on my machine", or production incidents. Also the operating manual for a dedicated debugger agent in a pipeline. Trigger on any error message, stack trace, or "why doesn't this work" - before proposing any fix.
---

# Debugging Protocol

Debugging is applied epistemology under time pressure. The intuitive approach - stare at code, guess, change something - feels fast and is slow. Pair with transparent-reasoning for showing the hypothesis chain.

## Phase 0 - Read the error. Actually read it.

The full text, the *first* error not the last (cascades bury the cause under consequences), exact line numbers, versions in the trace. Half of debugging time is wasted on errors whose message named the problem. Cheap wins before any machinery: is this the code you think is running? (stale build, wrong branch, cached artifact, wrong env - these answer a shocking fraction of "impossible" bugs.)

## Phase 1 - Build a feedback loop (this IS the skill)

Everything downstream is mechanical *if* you have a **tight pass/fail signal that goes red on this specific bug**. No loop → no hypothesizing; reading code to build theories before a red-capable command exists is the exact failure this protocol prevents. Spend disproportionate effort here.

Ways to construct one, in rough order of preference: failing test at whatever seam reaches the bug → curl/HTTP script against dev server → CLI invocation diffed against known-good output → headless browser script → replay a captured real payload/trace through the path in isolation → throwaway harness (minimal system subset, one function call) → property/fuzz loop for "sometimes wrong" bugs → bisection harness (`git bisect run`-able) → differential loop (same input through old vs new version, diff) → human-in-the-loop script as last resort.

**Then tighten it** - the loop is a product: faster (cache setup, narrow scope; 2 seconds beats 30), sharper (assert the user's exact symptom, not "didn't crash"), deterministic (pin time, seed RNG, isolate FS/network). Non-deterministic bugs: don't chase a clean repro, **raise the reproduction rate** - loop the trigger 100x, parallelize, stress, inject sleeps to widen race windows. A 50% flake is debuggable; 1% is not. Flaky tests are real bugs; "rerun until green" is data destruction.

**Completion criterion**: one command you have already run at least once that is red-capable (drives the actual bug path, asserts the actual symptom), deterministic (or pinned-high-rate), fast, and agent-runnable unattended. If you genuinely cannot build one: stop, say so, list what you tried, and ask for environment access, a captured artifact (HAR, log dump, recording), or permission for temporary production instrumentation.

## Phase 2 - Reproduce + minimize

Run the loop; watch it go red with the **user's described failure** - not a nearby different failure (wrong bug = wrong fix). Then shrink to the smallest scenario still red: cut inputs, callers, config, data one at a time, re-running after each cut, until **every remaining element is load-bearing**. Minimization shrinks the hypothesis space and becomes the regression test later. Do not proceed without repro + minimization.

## Phase 3 - Hypothesize (plural, ranked, falsifiable)

Generate **3-5 ranked hypotheses before testing any** - single-hypothesis generation anchors on the first plausible idea. Base rates for ranking: your newest code > your config > dependency's config > the library > compiler/OS (in that order; "the framework is broken" is occasionally true and usually cope). Each hypothesis states its prediction: "if X is the cause, changing Y makes the bug disappear." Can't state the prediction → it's a vibe, discard or sharpen. Show the ranked list to the user - they often re-rank instantly ("we just deployed #3") - but proceed with your ranking if they're absent. Log every hypothesis/result pair to the task file (agents: mandatory) - the scratch log prevents circling.

## Phase 4 - Instrument, one variable at a time

Each probe maps to one prediction. Bisect along the cheapest axis: time (`git bisect` - works because commits are atomic and green, see git-workflow), data (which half of input triggers it), code path (does the bad value exist at this layer boundary? each check halves the territory), environment (diff versions/env vars/locale/TZ, don't meditate on code). Tools: debugger/REPL breakpoint > targeted logs at hypothesis-discriminating boundaries > never "log everything and grep". Tag every debug log with a unique prefix (`[DBG-a4f2]`) so cleanup is one grep. **Performance bugs**: logs are the wrong tool - baseline measurement (profiler, timing harness, query plan) first, then bisect; measure before touching anything.

Three failed hypotheses → zoom out one level and question an assumption from above, or escalate.

## Phase 5 - Fix the cause, prove it, protect it

- Symptom patch (null-check hiding it) vs cause fix (why was it null?) - patches are debt with interest; take them only consciously, ticketed, under incident pressure.
- Regression test **before the fix, at a correct seam** - one where the test exercises the real bug pattern as it occurred. If no correct seam exists, that's an architecture finding (see tdd + codebase-design): document it, don't write a false-confidence test at the wrong seam. Then: red → fix → green → full suite → re-run the Phase 1 loop against the original un-minimized scenario.
- Look for siblings: the same wrong pattern usually exists elsewhere - grep now, while you understand it.

## Phase 6 - Cleanup + retro

Before declaring done: original repro re-run and green; regression test in (or seam-absence documented); all `[DBG-*]` instrumentation grepped out; throwaway harnesses deleted; the winning hypothesis stated in the commit message so the next debugger learns. Then the two retro questions: **which gate/test class should have caught this** (add it - verification-gates), and **would preventing it take architectural change** (no good seam, tangled callers → route to codebase-design, *after* the fix lands, when you know most).

## Incident mode (production)

Order inverts: **mitigate first** - rollback, flag off, failover (devops-cicd) - and diagnose on the stabilized system. Preserve evidence before rotation (logs, metrics snapshots, dumps). Root-cause afterward, blamelessly, written timeline; output is systemic fixes, not a culprit.

## Debugger-agent rules

Never widen scope mid-debug (no drive-by refactors). Log all hypothesis/result pairs to the task file. Two failed fix attempts on the same bug → escalate to human with the full scratch log, not a fresh confident third guess.
