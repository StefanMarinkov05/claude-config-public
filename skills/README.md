# Personal skills index

## Token cost (measured 2026-09-16)

Two numbers per skill, because they are consumed differently: **SKILL.md** is
what loading the skill costs; **+refs** is the ceiling if every reference file
under it is also read. Most skills are a single file, so the two are equal.

| | SKILL.md only | with all references |
|---|---|---|
| **All 32 skills** | **~52,500t** | ~137,000t |
| The five that carry references | ~13,000t | ~98,000t |

The heavy ones, and the only ones worth thinking about before loading:

| Skill | SKILL.md | +refs | Refs |
|---|---|---|---|
| `website-testing` | 3,100t | **57,300t** | 20 |
| `laravel-pro` | 3,000t | 10,700t | 4 |
| `concurrency` | 3,900t | 5,700t | 1 |
| `docs-and-comments` | 4,400t | 4,400t | 0 |

Everything else is 700–2,100t as a single file; the 27 of them together are
~33,000t.

**Read this as a budget, not a ban.** The reference files exist precisely so a
skill can be cheap to load and deep on demand — `website-testing`'s SKILL.md is
3,100t and routes to whichever one of its 20 references the task needs. Loading
all 20 is never the intent.

Re-measure after any substantial edit:

```bash
cd ~/.claude/skills && for d in */; do
  printf '%-32s %6dt\n' "${d%/}" "$(( $(cat "$d/SKILL.md" | wc -c) / 4 ))"
done | sort -k2 -rn
```

## Rules when working in a repo that uses this library

1. **Do not read every skill to decide which applies.** Reading them all to
   choose one costs the same as loading them all — that is what this index is
   for. Choose from the groupings below.
2. **Everything lives in `skills/`; nothing is symlinked per project.** All 32
   are `"off"` by default in `settings.json`'s `skillOverrides`, and a project
   opts in what it needs via its own `.claude/settings.local.json`. (There was
   once a `skill-archive/` tier — it was deleted after ten skills sat in it
   unloadable and invisible, because only `~/.claude/skills/` is ever scanned.)
3. **Project instructions outrank every skill here.** If a project's
   `CLAUDE.md` contradicts a skill, the project wins — say so explicitly rather
   than diverging silently.
4. **A first-party source outranks a skill on its own subject.** Where a
   project ships vendor guidance (Laravel Boost's `laravel-best-practices` and
   its ~20 rule files, for instance), read that first; it is version-aware and
   these files are not.
5. **`critical-observer` is standing behaviour**, not task-triggered — it
   applies to every conversation regardless of topic.


All 32 are off by default (`skillOverrides` in `~/.claude/settings.json`) to
keep the per-turn skill listing small. Flip an entry's value to `"on"` (or
delete its line) in that file to re-enable one persistently; a project's
`.claude/settings.json` or `.claude/settings.local.json` can override
individual entries for just that repo without touching the user file.

Ten of these (`api-design`, `code-review`, `concurrency`, `database-design`,
`debugging-protocol`, `devops-cicd`, `docs-and-comments`, `laravel-pro`,
`security-baseline`, `tdd`) were restored on 2026-09-07 from a
`skill-archive/` folder that had gone stale and invisible — they were never
loadable at all while archived, since only `~/.claude/skills/` is scanned.
No note existed for why they'd been archived; several (`laravel-pro`,
`concurrency`, `database-design`) are directly relevant to Laravel/e-commerce
work like this project's, so they were restored rather than left buried.

## Process / pipeline (idea → shipped)

- **project-pipeline** — end-to-end router for any build request; sequences
  which of the skills below to consult at each phase. Start here for
  "build me X" requests.
- **brainstorming** — turns a raw idea into an approved design before any
  code. The generative counterpart to `grilling`.
- **requirements-to-spec** — vague requests → precise, agent-consumable
  specs and tickets.
- **grilling** — one-question-at-a-time interview to stress-test a plan
  before committing to it.
- **project-planning** — scoping: milestones, MVP scope, risk registers.
- **tech-selection** — criteria/process for choosing a stack, framework, or
  technique.
- **engineering-reasoning** — structured tradeoff analysis for
  architecture-level "which is better" decisions.

## Writing and reviewing code

- **code-quality** — default standards for any non-trivial code: testing,
  error handling, performance, production-readiness.
- **codebase-design** — deep-module interface design, seams, testability
  by shape.
- **code-comprehension** — orienting in unfamiliar code before changing it;
  the research phase.
- **coding-standards** — Stefan's personal stack conventions and
  agent-architecture standards (LangGraph/orchestrator patterns, paste-ready
  agent prompts).
- **code-review** — adversarial reading to find defects, severity taxonomy,
  actionable rejection format. Distinct from `code-quality` (writing) —
  this is hostile reading, for PRs/diffs/patches.
- **api-design** — REST resource modeling, contract-first workflow,
  versioning, pagination, idempotency for any new endpoint or webhook.
- **database-design** — schema modeling, normalization, indexing, query
  performance, migrations. Trigger even for "just add a column."
- **concurrency** — MVCC/isolation semantics, the race taxonomy (lost
  update, write skew, TOCTOU), pessimistic/optimistic/constraint-based
  control, the two-process harness that actually proves a lock exists.
  Directly relevant to this project's stock-reservation and coupon-redemption
  code.
- **laravel-pro** — Stefan's professional Laravel/PHP standard:
  scaffolding-first (Blueprint/Filament), the abstraction ladder, DB-level
  validation, and the Filament/Livewire/Eloquent traps that cost an afternoon
  each. Deliberately narrow: where a Boost-enabled project ships Laravel's own
  `laravel-best-practices` rules, or where `security-baseline`,
  `concurrency`, `database-design` or `website-testing` own the topic, this
  skill defers instead of restating. Carries no version table — `composer
  show --direct` is the authority, and a stale pin argues for downgrading
  working code.
- **tdd** — red-green loop, pre-agreed test seams, test anti-patterns
  (tautological, implementation-coupled, horizontal slicing).
- **debugging-protocol** — systematic procedure: feedback loop, reproduce
  and minimize, hypothesize, instrument, fix, regression-proof. Trigger on
  any error/stack trace before proposing a fix.
- **docs-and-comments** — standards for code comments and project docs
  written for learning/teaching; READMEs, architecture docs, runbooks.

## Frontend / UI

**Two halves of one job, deliberately not merged.** For Stefan's own work load
both, `frontend-distinctive-design` first; for a general design question or
someone else's stack, that one alone suffices.

- **frontend-distinctive-design** — the transferable craft: pick a concept
  first, the anti-generic checklist, type/colour/layout discipline,
  self-review. **The checklist rotates** as AI-design tells move.
- **ui-design** — Stefan's stack and defaults on top: Framer Motion / GSAP /
  R3F, artifact constraints, ask-first, the paste-ready UI prompt generator.

*Why not one file:* the checklist needs frequent editing and the stack
preferences rarely change. Merged, the fast-rotating half gets buried in the
slow half and goes stale in the copy nobody edits — which is exactly why
`ui-design` points at the checklist instead of restating it.

## Testing, security, and ops

- **website-testing** — the full test-layer suite for a web app: static
  analysis, DAST/security, concurrency, CI/CD gating, post-deploy checks.
  **Deliberately one skill, not five.** It is already split the right way — a
  3,100t router over 20 references loaded individually. Its core asset is the
  "which layer finds what / misses what" table, which only works whole: the
  thesis is that each layer misses what another catches, so you diagnose by
  comparison. Split it, and a session that loads only the security half never
  learns DAST misses authorization while static review misses headers, and
  stops at one layer believing it is done — the exact failure the skill exists
  to prevent. Splitting would also *cost* tokens: five sets of frontmatter plus
  the three shared governing rules repeated five times.
- **verification-gates** — blocking pass/fail criteria between pipeline
  stages or agents.
- **security-baseline** — input validation, auth/authz, secrets, dependency
  hygiene, security-review checklist. Trigger automatically for any
  endpoint, form, SQL/ORM query, or auth code.
- **devops-cicd** — CI/CD pipelines, environments, deployment strategies,
  rollback, observability. "How do I ship this" questions.

## Git and multi-agent coordination

- **git-workflow** — branching, commit, and PR conventions for solo/team/
  multi-agent work.
- **git-guardrails** — the enforcement layer: hooks that mechanically block
  destructive git commands.
- **agent-orchestration** — designing multi-agent dev-team topologies, task
  decomposition, handoff contracts.
- **context-handoff** — carrying state across agent handoffs and long
  sessions / context-window limits.

## Reasoning and communication style

- **transparent-reasoning** — auditable, sourced reasoning alongside any
  conclusion or recommendation.
- **critical-observer** — standing meta-behavior: proactively flags blind
  spots and contradictions in Stefan's own decisions, across any topic.

## Career / interviews

- **interview-handbook** — personalised interview-prep handbook per job ad
  (LaTeX → two cross-linked PDFs with page-number links, back trail, 150%
  zoom): job + own-project analysis, gap chapters, verified resources. Code
  lives in the `interview-prep` repo; this skill is the process.

## Full skill descriptions

Run `head -6 ~/.claude/skills/<name>/SKILL.md` for any skill's exact
trigger conditions, or open the file directly — the frontmatter
`description` is the authoritative trigger text this index summarizes.
