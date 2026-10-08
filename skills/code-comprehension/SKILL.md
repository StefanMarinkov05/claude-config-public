---
name: code-comprehension
description: Systematic approach to understanding unfamiliar code - orienting in a new codebase, tracing behavior, building a mental model before changing anything, and analyzing third-party libraries or inherited projects. Use when joining/inheriting a project, before modifying code not written in this session, when asked "how does this work" or "analyze this repo/library", when evaluating code found online, or as the research phase before any feature in an existing system. Trigger before proposing changes to any codebase not already mapped in context.
---

# Code Comprehension (Research Phase)

Reading is the primary activity of software work; changing code you haven't modeled is guessing with a compiler. This skill front-loads the map-building that makes every later phase cheap. It is Phase 4's "read the existing conventions first" (project-pipeline feature-on-existing mode) expanded into a procedure.

## Pass 1 - Orient (breadth, ~minutes)

Read in this order, taking notes to a scratch map file:
1. **README + docs/ + ADRs** - claimed purpose and architecture (trust but verify later).
2. **Build/manifest files** (csproj/package.json/pyproject) - the *true* dependency list, entry points, scripts, target versions. This is the honest summary no README matches.
3. **Directory shape** - domain-organized or layer-organized? Where do things of each kind live? One representative file per directory, skimmed.
4. **The tests** - often the best behavioral documentation in the repo: test names enumerate intended behaviors, fixtures show real usage shapes.
5. **Git archaeology** - `git log --oneline -30` (what's moving lately), most-churned files (`git log --format= --name-only | sort | uniq -c | sort -rn | head`) - churn marks both the hot core and the pain points; recent reverts mark dragons.

Output of Pass 1: a one-paragraph statement of what the system does, the 5-10 load-bearing modules, and where the entry points are. Wrong is fine - it's a hypothesis to correct.

## Pass 2 - Trace one representative flow (depth)

Pick the most characteristic operation (one HTTP request, one CLI command, one event) and follow it end to end: entry → routing → logic → storage → response. Trace by **reading + search** (grep for the route string, the handler name, the table name), confirming with a debugger/print run where reading is ambiguous. Record the flow as a numbered path with file:line references - this becomes the spine of the mental model, and future features are located relative to it ("auth happens between steps 2 and 3").

While tracing, harvest the **house conventions**: error-handling idiom, DI style, naming patterns, transaction boundaries, test seams. Changes that ignore house style are defects even when correct (code-review will flag them; better to know first).

## Pass 3 - Interrogate the parts that matter for your task

Comprehension is task-relative - don't map the whole country to cross one bridge:
- **Callers and callees** of everything you'll touch (`grep -rn "FunctionName("`, IDE find-usages): the blast radius *is* the required understanding.
- **Invariants**: what do constraints, assertions, and validation reveal about what must stay true? (database-design's invariants, read in reverse.)
- **The surprising bits**: anything that contradicts your Pass 1 hypothesis gets investigated, not glossed - surprises are where your model is wrong, and wrong models write bugs.
- Unclear behavior → **characterization test**: write a test asserting what the code *currently does* (not what it should do). It documents reality, becomes the safety net for changes, and settles "wait, does it handle X?" permanently.

## Analyzing third-party code / libraries / found-online code

Same passes, plus the trust layer: check manifest against tech-selection's dependency health criteria; read the *actual* implementation of the 2-3 functions you'll rely on (docs lie by omission - especially about error behavior and edge cases); for security-relevant code, run the security-baseline checklist over its input handling before adopting; pin the exact version you audited.

## Rules

- **No changes during comprehension.** Reading mode and writing mode don't mix - "fixing while exploring" produces changes based on a half-built model (same separation as debugging-protocol's no-refactors-mid-debug).
- **Externalize the map** - `plan/codebase-map.md` with the Pass 1 summary, traced flows, conventions, and surprises. Comprehension that lives only in context evaporates at session end (context-handoff); the map is reusable by every future session and agent.
- **Timebox by stakes**: 30 minutes for a small fix's blast radius; hours for inheriting a system. When the timebox ends, list what remains unknown as explicit `[assumed]` items (transparent-reasoning) rather than silently proceeding as if known.
- Estimates for work in an uncomprehended codebase get the ×2 unknown-territory multiplier (project-planning) - and saying so is honest, not weak.
