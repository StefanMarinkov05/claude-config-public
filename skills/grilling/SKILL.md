---
name: grilling
description: Relentless one-question-at-a-time interview to stress-test a plan, design, or spec before building. Use when the user says "grill me/this", wants a plan challenged, before committing to any one-way-door decision, or as the sharpening step inside requirements-to-spec and project-pipeline Phase 0-1. Also use when the user's request hides unresolved design tension.
---

# Grilling

Interview the user relentlessly about every aspect of the plan until shared understanding is reached. The goal is to surface the decisions hiding inside the idea - one at a time, before code makes them expensive.

## Protocol

- **One question per message.** Multiple questions at once produce shallow answers to all of them. Ask, wait, follow the answer down its branch, then move to the next branch.
- **Every question comes with your recommended answer** and a one-line reason. The user should be reacting to a concrete proposal, not facing a blank. ("How should duplicate submissions behave? Recommendation: idempotency key + replay stored response - retries are inevitable.")
- **Walk the design tree dependency-first**: resolve decisions that other decisions hang on before descending (data model before API shape, auth model before endpoints).
- **If the codebase or existing docs can answer it, look there instead of asking.** Questions cost the user attention; spend it only on genuine judgment calls.
- **Log as you go**: every decision that lands goes into `plan/decisions.md` (one-way doors get a full ADR - see engineering-reasoning); new/sharpened domain terms go into the project glossary. The grilling session should leave artifacts, not just a conversation.
- **Do not start building until the user confirms shared understanding.** The explicit close: restate the plan in ≤10 bullets, ask "anything wrong or missing?", get the yes.

## What to grill about (checklist of branches)

Unhappy paths and edge behavior (see requirements-to-spec's edge checklist) - concurrency and retries - data lifecycle (who deletes, when, GDPR) - authz model per resource - scale numbers and their implications - the riskiest assumption and how it gets tested first - non-goals ("so we are NOT doing X, correct?") - operational story (deploy, rollback, who gets paged) - the tempting alternative not chosen, and why.

## Calibration

Depth proportional to reversibility: a prototype gets 3-5 questions; a schema or public API gets the full tree. Stop when questions stop changing the plan - grilling past that point is theater. If the user answers "whatever you think" three times in a row, switch mode: state your decisions as a block, flag the two that most deserve their attention, and proceed.
