# Build-Time Dev Team (Claude Code Orchestrator Pattern)

The agent team that BUILDS Stefan's apps inside Claude Code. Load when Stefan asks for agent setup, agent prompts, or orchestration design for building.

## The pattern (grounded in current Claude Code practice)

Orchestrator (main Claude Code session, top model) does NOT write code. It: reads requirements → plans → decomposes into a task dependency graph → dispatches specialist subagents via the Task tool → reviews returned output → decides next step. Each subagent runs in an ISOLATED context (its own window), sees only what it's told, returns a result. Isolation is the whole point: it prevents cross-contamination (backend patterns leaking into frontend code) and keeps each agent's attention on only its rules.

Persistent specialists live as markdown files with YAML frontmatter in `.claude/agents/` (project) or `~/.claude/agents/` (user-global). They inherit CLAUDE.md context automatically.

Execution modes:
- **Sequential chain**: when task B needs task A's output (schema → seeding → tests). Default for dependent work
- **Parallel fan-out/fan-in**: independent domains dispatched together, orchestrator synthesizes (the fan-in is where cross-cutting bugs get caught - e.g. an auth gap + a validation gap together = a vuln neither agent saw alone). NEVER parallelize agents that write the same files
- **Builder/validator (validation chain)**: one agent writes, a separate agent reviews - for security-sensitive or high-cost-of-bug code

When NOT to orchestrate: single-file changes, utility functions, typos - overhead costs more than it saves.

## Stefan's dev-team roles (his orchestrator pattern: DB / seeding / testing / security ...)

Standard roster for his app builds. Each is a specialist subagent with a tight domain:
- **DB agent**: schema design, migrations, Prisma/EF models, indexes, query optimization. Owns the data layer only. Kleppmann principles apply here
- **Seeding agent**: seed/fixture data, factories, realistic test data respecting schema constraints. Depends on DB agent output (sequential)
- **Testing agent**: unit + integration tests, coverage, edge cases. Depends on the code it tests
- **Security agent**: auth flows, input validation, secrets handling (the Supabase-exposure history makes this non-optional), OWASP-class review, dependency audit. Runs as validator on anything sensitive
- **API/backend agent**: routes, controllers, business logic, DTOs
- **Frontend agent**: components, state, forms (hands visual/animation work to ui-design conventions)
Add/rename per project; keep each domain non-overlapping so parallel dispatch stays conflict-free.

## Model routing for the dev team
- Orchestrator (main session): Opus-class - planning, decomposition, review
- DB / API / frontend / security-review subagents: Sonnet-class - well-scoped generation and review
- Seeding / formatting / mechanical extraction: Haiku-class
- Set `CLAUDE_CODE_SUBAGENT_MODEL` for the default subagent tier; override per-task when a subagent's job genuinely needs more reasoning

## PASTE-READY AGENT PROMPT GENERATOR

When Stefan asks for an agent, output a complete `.claude/agents/<name>.md` file: YAML frontmatter + system prompt. Template:

```markdown
---
name: <agent-name>
description: <one line - when the orchestrator should dispatch this agent>
model: <opus|sonnet|haiku - per routing rules>
tools: <only what it needs - principle of least tool access>
---

# Role
You are the <domain> specialist. You own ONLY <domain>. You do not touch <explicit out-of-scope>.

# Context you inherit
<stack conventions relevant to this domain - pulled from coding-standards; e.g. for DB agent: Prisma 7 datasource.url in prisma.config.ts, PostgreSQL, access-pattern-driven model choice>

# Your task contract
- Input you receive: <what the orchestrator passes>
- Output you return: <exact deliverable + format>
- Definition of done: <checklist>

# Rules
- <domain-specific hard rules; e.g. security agent: never put secrets in client code or commits; rotate on exposure>
- Comment heavily and pedagogically (Stefan learns from and briefs agents with this code)
- <Kleppmann principle if data-touching, named explicitly>

# Failure handling
<what to do on ambiguity: return a question to the orchestrator rather than guessing>
```

Generate one per requested role, pre-filled with Stefan's actual conventions and the correct model tier. For a full team, also output a short orchestrator brief describing dispatch order (the dependency graph: DB → seeding → API → tests, security as validator, frontend parallel to backend).

## Guardrails
- Least-privilege tools per agent (don't give the seeding agent shell access it doesn't need)
- Secrets rule propagates to every agent's prompt
- Comment-heavy output is a standing instruction in every generated agent
- Keep agent domains non-overlapping to preserve conflict-free parallelism
