---
name: brainstorming
description: Collaborative divergence phase that turns a raw idea into an approved design before any implementation. Use at the very start of any creative or build work - new features, components, tools, behavior changes - before requirements-to-spec formalizes and before any code. Trigger on "I have an idea", "I want to build", "let's add", or any request arriving as a wish rather than a spec. The generative counterpart to grilling.
---

# Brainstorming: Idea → Approved Design

Grilling stress-tests a plan that exists; brainstorming creates the plan. Divergence first (options), convergence second (design), approval always - before any implementation action.

## Hard gate

No implementation skill, no code, no scaffolding until a design has been presented and the user approved it. This applies regardless of perceived simplicity - "too simple to need a design" is the anti-pattern: simple projects are where unexamined assumptions burn the most work. For truly simple things the design is three sentences; it still gets presented.

## Procedure

1. **Explore context first** - files, docs, recent commits, existing conventions. Questions the codebase can answer are not asked (same rule as grilling).
2. **Clarify intent** - one question at a time: purpose, constraints, success criteria, non-goals. What need hides behind the proposed mechanism (requirements-to-spec's outcome-not-mechanism rule applies from the first minute)?
3. **Propose 2-3 genuinely different approaches** - different decompositions, not cosmetic variants (design-it-twice from codebase-design, applied pre-spec). Each with trade-offs on the dominant axis and a stated recommendation. The null option (don't build; compose existing things) is always candidate #1.
4. **Present the design in sections scaled to complexity** - data model, interfaces, flow, risks - checking agreement per section rather than dumping a monolith.
5. **Write it down** - `docs/specs/YYYY-MM-DD-<topic>-design.md`, committed. A design that lives only in chat doesn't exist (context-handoff rule).
6. **Self-review before handing over**: placeholders left? contradictions between sections? ambiguity a second reader would trip on? scope beyond what was agreed?
7. **User reviews the written doc** - then hand off: to grilling if the design deserves stress-testing (one-way doors present), else straight to requirements-to-spec / project-pipeline Phase 0.

## Divergence discipline

- Generate before judging: while collecting options, no feasibility vetoes - premature convergence is the failure mode this skill exists to prevent.
- Steal adjacently: how do neighboring domains/products solve this? (frontend-distinctive-design's print/physical-world borrowing, generalized.)
- Name the assumption each approach bets on; the riskiest assumption becomes milestone 1's target (project-planning).
- If the user answers "whatever you think" repeatedly, switch to decide-and-flag mode (same bail-out as grilling).

## Position in the pipeline

brainstorming (idea → design) → grilling (design → stress-tested design) → requirements-to-spec (design → tickets) → project-pipeline Phases 1+. Skipping brainstorming is fine when the input already *is* a design; skipping it because the idea "seems clear" is how confident wrong software gets built.
