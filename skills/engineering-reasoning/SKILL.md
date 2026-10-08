---
name: engineering-reasoning
description: Structured logical reasoning and decision-making for engineering tradeoffs. Use whenever a technical decision must be made between alternatives - architecture choices, build-vs-buy, sync-vs-async, consistency-vs-availability, optimization-vs-simplicity, refactor-vs-rewrite, or any "should we do X or Y" question in software work. Also use when reviewing a plan or design to check its reasoning for hidden assumptions, missing constraints, or premature optimization. Trigger even when the user asks a seemingly simple "which is better" question.
---

# Engineering Reasoning & Tradeoffs

Expert engineering is mostly disciplined decision-making under uncertainty. This skill encodes the reasoning process; apply it before writing any code that embodies a decision.

## The Decision Procedure

For every non-trivial decision, walk these steps explicitly (in analysis or comments):

1. **State the actual problem.** Not the solution someone proposed - the underlying need. Half of bad decisions solve the wrong problem. Ask: "what breaks if we do nothing?"
2. **Enumerate constraints before options.** Hard constraints (budget, deadline, team skills, compliance, existing stack) eliminate options cheaply. A "best" technology that the team can't operate is a wrong answer.
3. **Generate 2-4 real alternatives.** Always include the null option (do nothing / keep current) and the boring option (simplest thing that could work). If you can only think of one option, you haven't understood the problem.
4. **Identify the dominant axis.** Most decisions are dominated by one dimension: latency, cost, correctness, time-to-ship, operability, or reversibility. Name it. Comparing 8 criteria with equal weight produces mush.
5. **Classify reversibility (one-way vs two-way doors).**
   - Two-way door (framework choice in a small app, library selection, internal API shape): decide fast, bias to action, cheapest-to-try wins.
   - One-way door (public API contract, database engine, data model of core entities, language of a large codebase): slow down, prototype, write the decision up.
6. **Estimate with numbers, even rough ones.** "Slow" is not an argument; "adds ~40ms p99 per request at 100 rps" is. Fermi estimates beat vibes. Orders of magnitude are enough.
7. **Decide, record, and set a tripwire.** Write an ADR (see below) and define the condition under which you'd revisit ("if p99 exceeds 200ms" / "if we exceed 1M rows").

## Core Tradeoff Heuristics

- **Simplicity is the default winner.** Complexity must pay rent with a concrete, measured benefit. YAGNI until data says otherwise.
- **Premature optimization test:** do you have a measurement showing this path is hot? No measurement → no optimization. But **premature pessimization** is also real: don't choose an O(n²) design when O(n log n) is equally simple.
- **Correctness > operability > performance > elegance**, in that order, for most systems. Reorder only with explicit justification (e.g., HFT reorders performance up).
- **Optimize for change.** Requirements will change more than you predict. Prefer designs where the likely change is a local edit, not a rewrite. Ask: "what's the most probable next requirement, and how expensive is it under each option?"
- **Buy/adopt for undifferentiated work, build for core differentiators.** Auth, payments, email, monitoring: adopt. The thing your product actually is: build.
- **Coupling is the enemy; duplication is only a suspect.** A little duplication is cheaper than the wrong abstraction. Abstract on the third occurrence (rule of three), not the second.
- **Distributed systems tax:** any decision that moves from one process to many (microservices, queues, caches) buys scalability with consistency problems, partial failure, and observability costs. Demand evidence the monolith actually failed first.

## Common Reasoning Failures to Flag

- **Resume-driven choice**: technology chosen for novelty, not fit.
- **Sunk cost**: "we already built half of it" is not an argument for finishing.
- **Survivorship copying**: "Netflix does X" - Netflix has 1000 engineers and your constraints differ.
- **False dichotomy**: presenting 2 options when a hybrid or third exists.
- **Unpriced risk**: option A looks cheaper because its failure modes weren't costed.
- **Solution anchoring**: the first proposed design frames all discussion. Deliberately generate one alternative that shares zero components with it.

## Architecture Decision Records (ADR)

Record every one-way-door decision in `docs/adr/NNNN-title.md`:

```markdown
# NNNN. Choose PostgreSQL over MongoDB for core entities
Date: 2026-07-04 | Status: Accepted

## Context
(the problem, constraints, and forces - 3-6 sentences)

## Decision
(what we chose, one sentence)

## Alternatives considered
(each with the one reason it lost)

## Consequences
(what gets easier, what gets harder, the tripwire for revisiting)
```

ADRs are teaching documents: write them so a new team member understands *why*, not just *what*.

## Output Format When Advising

When asked "should we X or Y", respond with: problem restatement → constraints → options table (option, dominant-axis score, reversibility, main risk) → recommendation with numeric justification → tripwire. Keep it compact; one screen where possible.
