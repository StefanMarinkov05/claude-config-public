---
name: code-quality
description: Standards for writing scalable, performant, well-tested, production-grade code. Use whenever writing or reviewing implementation code in any language - functions, classes, modules, services, APIs - and whenever the user asks for tests, a refactor, a code review, error handling, performance work, or "make this production-ready". This is the default skill for any coding task that produces more than a throwaway snippet. Trigger it even if the user doesn't mention quality explicitly.
---

# Code Quality: Architecture, Testing, Performance

Production code has three audiences: the machine, the next reader, and the 3am debugger. Serve all three.

## Architecture & Structure

- **Dependencies point inward**: domain logic depends on nothing; I/O (HTTP, DB, filesystem, clock, random) lives at the edges behind interfaces. This single rule buys testability, swap-ability, and comprehension.
- **Functions do one thing**; a function that "validates and saves and notifies" is three functions and a coordinator. Target ≤ ~40 lines and ≤ 3 params; more params → a typed options object.
- **Make illegal states unrepresentable**: use the type system (discriminated unions, enums, non-nullable types, value objects like `Email`, `Money`) so invalid data can't be constructed, instead of validating everywhere.
- **Parse, don't validate**: convert untrusted input into rich types once at the boundary; the core then trusts its inputs by construction.
- **Composition over inheritance**; inheritance only for true is-a with stable contracts (rare).
- **Rule of three for abstraction**: duplicate twice, abstract on the third occurrence. Wrong abstractions cost more than duplication.
- Module boundaries follow **domain concepts, not technical layers**: `orders/`, `billing/` (each with its handlers, logic, storage) over top-level `controllers/`, `services/`, `utils/`. `utils.py` is where cohesion goes to die.

## Errors & Robustness

- Errors are part of the interface: every function's failure modes are as designed as its success path. Use the language's idiom (exceptions with specific types / Result types) consistently - never both randomly.
- **Fail fast** on programmer errors (assert invariants, crash loudly in dev); **handle gracefully** only expected environmental failures (network, user input, external services).
- Never swallow exceptions. Catch only what you can act on; catch narrowly; rethrow with context. An empty catch block is a bug.
- All external calls get timeouts, retries with jittered exponential backoff **only if idempotent**, and a failure plan (circuit breaker/fallback/queue) once availability matters.
- Every mutation exposed over a network should be idempotent (idempotency keys) - retries happen whether you plan for them or not.
- Structured logging with context (request id, entity ids) at boundaries and failures; no secrets/PII in logs. Log the decision, not the noise.

## Testing (with invariant coverage)

Layered strategy:
- **Unit tests** for domain logic: fast, no I/O, the bulk of the suite.
- **Integration tests** against real infrastructure (real Postgres in a container, not mocks of the DB) for repositories, queries, migrations.
- **A few end-to-end tests** for the critical user journeys only.
- Test **behavior through public interfaces**, not private methods; tests that break on refactor without behavior change are liabilities.

**Big-invariant coverage** - for every module, explicitly list its invariants and write tests named after them:
- Domain invariants: "balance never negative", "order total = Σ line items", "state machine only follows legal transitions".
- **Property-based tests** for anything algorithmic or parser-like (Hypothesis / fast-check / FsCheck): generate thousands of inputs, assert the invariant, not examples. Classic properties: round-trip (`decode(encode(x)) == x`), idempotence (`f(f(x)) == f(x)`), invariance under permutation, oracle comparison against a naive implementation.
- Boundary cases always: empty, one, many, max, unicode, negative, concurrent.
- Every bug fixed gets a regression test that failed before the fix.
- Concurrency-sensitive code: test the race deliberately (barriers, repeated randomized interleaving), don't hope.

Tests are documentation: `test_order_cannot_ship_before_payment_captured` teaches; `test_case_7` doesn't. Arrange-Act-Assert, one behavior per test, no logic in tests. Tests live only at pre-agreed seams and must avoid tautological/implementation-coupled patterns - see the tdd skill for the loop discipline and anti-pattern list, and codebase-design for interface shapes that make testing natural.

## Performance & Scalability

- **Measure first**: profile before optimizing; add the fix; measure again; keep the numbers in the commit message. Guessed optimizations are usually wrong and always unverifiable.
- Big-O sanity at design time (avoid accidental O(n²) - nested loops over the same collection, string concat in loops, N+1 queries), micro-optimization only from profiler evidence.
- The usual real-world costs, in order: network round-trips > disk > memory allocation > CPU. Batch the round-trips first.
- **Design for statelessness** in services (state in DB/cache, not process memory) - that's what makes horizontal scaling a deployment detail rather than a rewrite.
- Backpressure over unbounded queues; bounded pools; load-shed early. An overloaded system that queues forever fails worse than one that rejects.
- Cache with a named invalidation strategy (TTL / event-driven) or don't cache; unbounded or unexplainable caches are memory leaks with extra steps.

## Hygiene & Process

- Small, single-purpose commits with messages explaining *why*; PRs reviewable in one sitting (<~400 lines).
- Linter + formatter + type checker in CI, zero-warning policy; CI runs the full test suite on every PR - red main is a stop-the-line event.
- No secrets in code (env/secret manager); validate and encode at trust boundaries (parameterized queries always, output encoding, authz checked server-side per resource).
- Feature flags for risky changes; every service exposes health checks and metrics from day one.
- Dependencies pinned via lockfiles; automated vulnerability scanning.

### Editing tools: prefer the one that fails loudly

**Never edit source with a stream editor (`sed -i`, `perl -pi`, a regex rewrite) when a structure-aware editor is available.** A stream editor has no model of the language: a pattern written against the file *as remembered* rather than as it currently reads will match a different span, match twice, or match nothing — and **all three exit zero**. Multi-line patterns are the worst case, because the span they can silently swallow is unbounded. Every other tool in the workflow reports its own failure; here, success, no-op, and mangling share one exit code, so the damage surfaces minutes later as what looks like a bug in the code you were aiming at.

When a scripted rewrite genuinely is the right tool (one mechanical mutation across many files), make the check unskippable by putting it in the same command: copy the file first, run the language's syntax check on every touched file immediately after (`php -l`, `node --check`, `python -m py_compile`, `ruff check`), and restore from the copy on failure.

The same asymmetry applies to any tool whose failure is silent — a formatter that skips an unparseable file, a codemod that matches nothing, a `--dry-run` misread as applied. Ask of every tool: *what does it do when it fails, and would I notice?*

## Review Checklist (apply to own code before presenting)

1. Do names reveal intent without comments? 2. Are all failure modes handled or consciously propagated? 3. Which invariants does this code maintain, and where are they tested? 4. What happens at 10x the data/traffic? 5. Could a reader new to the codebase trace one request through this? 6. What would the 3am debugger wish was logged?
