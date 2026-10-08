---
name: coding-standards
description: Stefan's software engineering standards, architecture design, and AI-agent development. Use whenever Stefan writes/reviews/debugs code, designs an app or data layer, works on his personal projects (fitness platform, polybot, e-commerce), asks about agent architecture (build-time Claude Code dev-team agents OR runtime LangGraph user-facing agents), asks for paste-ready agent prompts, or works via Claude Code in VS. Covers stack conventions, data-system design (Kleppmann-grounded), the orchestrator pattern, model routing, and heavy learning-oriented code comments. NOT for UI/visual work - that is the ui-design skill.
---

# Coding Standards & Agent Architecture

Stefan's engineering layer. Two project modes: **academic** (AI as reference/tutor, he writes it) and **personal** (learning to build agentic systems, AI helps build). Detects mode from context; when unclear, ASKS. Always asks clarifying questions before large builds. UI/visual work → defer to `ui-design` skill.

## Ask-first rule
Before any non-trivial build or design, if scope, stack, data model, or agent boundaries are ambiguous - ask targeted questions (use the elicitation pattern, 1-3 questions). Guessing architecture wastes more tokens than asking.

## Stack conventions & known gotchas

Backend/.NET: ASP.NET Core .NET 8, EF Core, MSSQL; clean architecture (Onion/N-Tier), SOLID, DI everywhere, async by default, DTOs at boundaries, FluentValidation, xUnit + integration tests.

Full-stack/personal: Next.js 14 (App Router), TypeScript strict, Prisma 7 + PostgreSQL, Zustand, Supabase Auth.

Logged environment gotchas (do not re-derive):
- Prisma 7: `datasource.url` goes in `prisma.config.ts`, not schema
- PowerShell: UTF-16 encoding trap on generated files - force UTF-8
- WSL2: wslrelay Docker bug - known workaround applies
- **Secrets: Supabase keys were exposed TWICE. Standing rule: nothing secret in client code, in commits, or in chat. `.env` + server-only, `.gitignore` verified, rotate immediately on any exposure.** This is flagged hard on every recurrence (critical-observer)

## Comment philosophy (Stefan-specific, important)
Stefan uses generated code to LEARN and to brief his own agents. So: comment heavily and pedagogically, not sparsely. Every non-obvious block gets a comment explaining WHY (the decision/tradeoff), not just what. Public functions get doc-comments with intent, params, and failure modes. Architecture-level files get a header block explaining the file's role in the system. Trade token cost for his comprehension deliberately - this is a stated preference, not waste.

## Application & data design (Kleppmann-grounded)

Kleppmann (Designing Data-Intensive Applications) governs DATA/APP architecture only - NOT agent management. Apply his principles explicitly and name them:
- **Reliability/fault-tolerance**: design for failure - retries with idempotency, graceful degradation, no single point that drops data
- **Scalability**: know the load parameters before optimizing; describe load honestly (Stefan's apps are small-scale - say so, don't over-engineer for imaginary scale; premature distributed-systems complexity is optimization theater)
- **Maintainability**: simplicity and evolvability over cleverness
- **Data models**: relational vs document vs graph chosen by access pattern, not fashion - the fitness platform's polyglot split (relational core, document feedback, graph supplement-relations) is justified ONLY if access patterns differ; challenge it if they don't
- **Consistency/consensus**: pick the weakest guarantee that's still correct for the use case; know the difference between what needs a transaction and what tolerates eventual consistency
- Encoding, schema evolution, and backwards/forwards compatibility for anything persisted or sent over a wire
When a design decision touches these, name the principle and the tradeoff so Stefan learns the reasoning.

## Two distinct agent systems (never conflate)

Stefan builds agents at TWO layers. Keep them separate:

### A) Build-time dev team (Claude Code, orchestrator pattern)
Agents that BUILD his apps, run inside Claude Code in VS. This is the "dev team full of agents" - see `references/agent-dev-team.md` for the full pattern, roles, model routing, and the paste-ready prompt generator.

### B) Runtime agents (LangGraph, user-facing)
Agents his app's USERS interact with. Production Python, LangGraph. See `references/langgraph-runtime.md` for supervisor pattern, state management, and cost control.

The design principles rhyme but the constraints differ: build-time optimizes for Stefan's token budget and code quality; runtime optimizes for user latency, reliability, and per-request cost.

## Model routing (both layers)
Consensus from current practice: put reasoning at the top, execution at the bottom.
- **Orchestrator/supervisor** (planning, decomposition, routing, review): top model (Opus-class). It reasons, it does not grind out boilerplate
- **Workers/subagents** (generate code, write tests, extract, verify against a clear spec): cheaper/faster model (Sonnet-class; Haiku-class for truly mechanical extraction/formatting)
- Classification step: orchestrator tags task complexity, routes accordingly - the small classification overhead pays for itself on repeated workflows
- Rule of thumb from the field: this split cuts cost ~60-70% (some report 5-10x) with negligible quality loss WHEN subagent tasks are well-scoped. Poorly-scoped subagent work erases the savings in rework
- Don't add a supervisor to a 2-agent job - supervisor overhead ~3x a single well-prompted agent; orchestration earns its cost only on multi-domain coordination

## Interaction
- UI/animation/3D/CSS → `ui-design` skill (separate by design)
- New stack gotcha discovered → log it in this file
- Agent prompt requests → the generators in the reference files output paste-ready blocks
- Data-design decisions get the Kleppmann-principle-naming treatment for learning
