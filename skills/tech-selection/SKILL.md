---
name: tech-selection
description: Criteria and process for choosing technologies, frameworks, libraries, databases, infrastructure, and implementation techniques. Use whenever a project needs a stack decision, the user asks "what should I use for X", compares tools ("Postgres vs Mongo", "REST vs GraphQL", "which framework"), evaluates a library before adding it, or is choosing between implementation techniques (caching strategy, queue vs cron, SSR vs SPA). Trigger even for small dependency-addition decisions.
---

# Technology & Technique Selection

Technology choices are bets on operability, hiring, and change - not feature checklists. Default to boring; deviate with evidence.

## The Selection Procedure

1. **Requirements before candidates.** Write the 3-5 requirements that actually discriminate: expected scale (numbers!), latency budget, consistency needs, team's existing skills, budget, deadline. Most "X vs Y" debates dissolve once real numbers are on the table - at 100 requests/second and 10GB of data, nearly everything works, so pick the simplest.
2. **Boring-technology default.** Each project has a small innovation budget (~1 novel choice). Spend it only where novelty gives a decisive advantage on the core problem. Everything else: the most mainstream, oldest-stable option the team already knows. Proven > trendy; the failure modes of boring tech are documented on Stack Overflow, the failure modes of new tech are discovered in your production.
3. **Shortlist 2-3, then score on the axes below.** Kill options with hard-constraint violations first.
4. **Prototype the winner on the riskiest requirement** (timeboxed spike) before committing if it's a one-way door (database, language, cloud provider, public protocol).
5. **Record the decision as an ADR** with the losing options and why (see engineering-reasoning skill).

## Evaluation Axes

**For frameworks/platforms/databases (one-way doors - weight heavily):**
- Team familiarity - a familiar B-grade tool beats an unfamiliar A-grade tool for delivery
- Operational maturity: monitoring story, backup/restore, upgrade path, failure modes documented
- Ecosystem: hiring pool, docs quality, answered questions volume
- Longevity signals: age, corporate/foundation backing, release cadence, migration-off difficulty
- Fit to data/access pattern (see database-design skill for DB specifics)

**For libraries/dependencies (cheaper doors, but audit anyway):**
- Could we write this in <200 lines? Then write it - every dependency is an ongoing liability (supply chain, upgrades, transitive bloat).
- Health check: last commit recency, open-issues trend, maintainer bus factor, weekly downloads, semver discipline
- License compatible with the project (MIT/Apache/BSD fine; (A)GPL needs a deliberate call in commercial code)
- Size and transitive dependency count - prefer focused libraries over kitchen sinks
- Security: known CVEs, does it handle untrusted input?

**For techniques (caching, queues, patterns):**
- Introduce a technique only against a named problem, ideally a measured one. "Add Redis" is an answer; what was the question?
- Prefer techniques that degrade gracefully (cache miss = slow, not broken) over those that add hard dependencies.

## Standard Defaults (override with justification)

These are strong priors, not laws:

- **Database**: PostgreSQL unless a specific access pattern demands otherwise (see database-design skill). SQLite for single-node/embedded/dev.
- **API style**: REST + JSON for public/simple; add GraphQL only for many-client aggregation pain; gRPC for internal service-to-service at scale.
- **Architecture**: modular monolith first. Microservices only when team size (>~2 teams) or independent scaling demonstrably require them.
- **Async work**: cron/scheduled job → simple DB-backed queue → dedicated broker (in that escalation order, each step by evidence).
- **Caching**: none → HTTP caching → in-process → Redis (same escalation discipline).
- **Frontend**: server-rendered or lightweight SPA per interaction needs; static site generator for content sites. Don't ship a SPA for a form.
- **Hosting**: managed platform (PaaS) until cost or control demands otherwise; containers when you need portability; Kubernetes only with dedicated ops capacity.
- **Auth**: adopt (managed provider or battle-tested library), never hand-roll crypto/session logic.

## Red Flags in Any Evaluation

- Choosing by benchmark numbers irrelevant to your scale
- "It's what FAANG uses" (their constraints ≠ yours)
- Vendor blog posts as primary evidence - seek postmortems and "X years with Y" retrospectives instead
- No exit strategy considered (data export, protocol lock-in, egress cost)
- Adding a second tool from the same category the stack already has (two queues, two ORMs) without a deprecation plan for the first

## Output Format

When asked "what should I use for X": state assumed scale/constraints (ask one question only if truly undeterminable) → recommendation with 2-sentence rationale → shortlist table (option, key strength, key risk, when it would win instead) → exit strategy note for one-way doors.
