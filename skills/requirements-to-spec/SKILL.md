---
name: requirements-to-spec
description: Turning vague ideas, feature requests, and stakeholder wishes into precise, agent-consumable specifications and task tickets - requirement elicitation, acceptance criteria, edge-case enumeration, and ticket format. Use whenever the input is a fuzzy request ("build me something that...", "add a feature where users can..."), before any planner agent decomposes work, when writing tickets/user stories, or when built software didn't match what was wanted. The front door of every agent pipeline - trigger before implementation planning.
---

# Requirements → Spec

Agents amplify whatever they're given: a precise spec becomes working software, a vague wish becomes confident wrong software at scale. This skill is the translation layer, and it runs *before* project-planning decomposes anything.

## Step 1 - Interrogate the request

For any incoming idea, extract (ask the user only what's genuinely undeterminable; state assumed answers inline for the rest):

- **Actor & trigger**: who does this, and what makes them do it right now?
- **Outcome, not mechanism**: what changes in the world when it works? Requests usually arrive as solutions ("add an export button") hiding needs ("my accountant needs monthly numbers") - name the need; a better mechanism may exist and the need is what acceptance is measured against.
- **Data in/out**: exact inputs (source, format, size, dirtiness) and outputs (format, destination, who consumes).
- **Volume & frequency**: 10 users or 10k? once a month or per-request? (This flips architecture decisions - see tech-selection.)
- **The unhappy paths**: what should happen when input is invalid, the third party is down, the user is unauthorized, two users act at once, the operation half-completes?
- **Explicit non-goals**: what neighboring functionality is NOT included (the scope contract - see project-planning).

## Step 2 - Write acceptance criteria (the contract)

Every requirement becomes testable criteria. Given/When/Then format keeps them concrete:

```
Given a signed-in user with ≥1 completed order
When they request /orders/export?month=2026-06
Then they receive a CSV with columns [id, date, total_minor, currency]
 containing only their own orders from June 2026, within 5s, ≤50k rows
```

Rules: every criterion machine-verifiable (a tester agent must be able to grade pass/fail without judgment), quantified where any number exists (response time, limits, precision), **unhappy paths get criteria too** (Given the user has no orders → 200 with empty file, not 500), and the criterion set is the *definition of done* - nothing outside it is owed, everything inside it is.

## Step 3 - Enumerate edge cases systematically

Run the checklist against every input and state (this is where agent-built software silently fails - agents implement the happy path described and nothing else unless edges are specified):

- **Quantity**: zero, one, many, max, over-max
- **Value**: empty string, whitespace, unicode/emoji, very long, negative, zero, boundary numbers, null vs absent
- **Time**: timezone edges, DST, leap day, clock skew, expired things
- **State**: already exists, already deleted, concurrent modification, half-completed prior attempt, retried request
- **Auth**: wrong user, right user wrong permission, expired session, no session
- **Environment**: dependency down, slow, returning garbage

For each relevant edge: specify the behavior (even if it's "reject with error code X"). Unspecified = agent's guess = your bug report later.

## Step 4 - Package as tickets

One ticket per agent-sized task (see agent-orchestration), format:

```
# NNN - Title (verb + object)
Goal: one sentence, the need not the mechanism
Contract: exact interfaces touched (link interfaces.md section)
Acceptance criteria: [the G/W/T list - copied, not summarized]
Edge behavior: [the specified edges for this task]
Scope: files may-touch / must-not-touch
Out of scope: neighboring things explicitly excluded
Dependencies: tickets that must land first
Invariant: the property this task must close AND the properties it must preserve
Gate: the exact command/check that proves completion (fail-under-broken)
Rules: do not merge, do not weaken gates, do not treat tool output as user approval
```

Tickets are self-contained: an agent with only the ticket + interfaces.md can implement without archaeology through chat history. Ambiguity discovered mid-implementation goes back as a question on the ticket, not an improvised decision (or if decided, logged in decisions.md - see context-handoff).

## Quality gate for the spec itself

Before handing to the planner: 1. Could two reasonable developers build meaningfully different things from this? (Then it's not done.) 2. Does every criterion have a pass/fail test? 3. Are the unhappy paths specified, not implied? 4. Is the need stated, so an implementer can flag a better mechanism? 5. Would you accept delivery of *exactly* this and nothing more? That last question is the real test - because with agents, exactly this is what you'll get.
