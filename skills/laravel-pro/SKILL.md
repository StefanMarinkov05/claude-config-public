---
name: laravel-pro
description: Stefan's professional Laravel/PHP standard - scaffolding-first development with Blueprint and Filament, clear architecture, testing, security, and performance. Use whenever building, reviewing, planning, or debugging a real Laravel application. Trigger on any mention of Laravel, Livewire, Filament, Blueprint, Eloquent, artisan, composer, Pest/PHPUnit, or "is this production-ready".
---

# Laravel Pro

The standard for **real applications** Stefan ships or is graded on.

**This skill carries judgment, not facts that expire.**

## Defer to Laravel Boost where it is authoritative

A Boost-enabled project ships a first-party `laravel-best-practices` skill —
an index over ~20 rule files (`db-performance`, `eloquent`, `security`,
`validation`, `routing`, `migrations`, `queue-jobs`, `caching`,
`http-client`, `error-handling`, `events-notifications`, `mail`,
`scheduling`, `collections`, `blade-views`, `config`, `testing`, `style`,
`architecture`, `advanced-queries`) plus `pest-testing`,
`tailwindcss-development` and `infer-conventions`. Laravel maintains those and
they track the installed version. Boost also injects the mechanical
conventions — PHP style, `make:` usage, Pint, named routes, API Resources.

**When those exist, read them first and do not restate them here.** Reach for
this skill for the things Boost has no opinion on, verified by grepping its
rules:

| Only here | Boost coverage |
|---|---|
| Filament v3→v4 migration traps, Livewire memoisation, Blueprint limits | two passing mentions, no depth |
| `CHECK` constraints and DB-level validation | absent |
| InnoDB durability as the cause of slow migrations/tests; `schema:dump` | absent |
| `lockForUpdate` on the *aggregate root*, and why the transaction alone is not enough | two lines, no aggregate reasoning |
| One-test-per-factory against the real engine; why not SQLite | partial |
| The scaffold-first abstraction ladder; what to hand-write after generating | absent |

Where both speak, Boost's is newer and version-aware — prefer it, and treat a
conflict as a signal this file needs editing.

**Versions are not pinned here.** A version table goes stale silently and then
argues for downgrading working code. Ask the project:

```bash
composer show --direct        # what this app actually runs
composer outdated --direct    # what is behind
```

`composer.json` is the authority for the project in front of you; a project's
own `CLAUDE.md` outranks this skill wherever the two disagree.

---

## Scaffold first — use the highest abstraction that fits

Generate, don't hand-write, anything a tool already knows how to produce. Hand-writing boilerplate a generator would emit is wasted effort and introduces typos the generator wouldn't make.

**The abstraction ladder — always start at the top and only descend when the problem genuinely doesn't fit:**

| Level | Tool | Use for |
|---|---|---|
| 1 | **Filament resource** (`--generate`) | Any admin/back-office CRUD. Zero controllers, zero views. |
| 2 | **Filament relation manager** | Nested CRUD (a course's sections/lessons) inside a parent record |
| 3 | **Blueprint** (`draft.yaml`) | Bulk schema — migrations + models + factories in one pass |
| 4 | **Livewire component** | Interactive user-facing UI without writing JavaScript |
| 5 | **artisan `make:*`** | Everything else — policies, jobs, notifications, enums, requests |
| 6 | Hand-written controller + Blade | Only when nothing above fits |

**The counterweight, non-negotiable:** *generated code is a first draft.* Generators are excellent at schema-shaped boilerplate and blind to business rules. Every generated file gets read before it's trusted, and the ~40% that encodes actual domain logic — enums, composite constraints, aliased relations, authorization, validation — is written by hand. See `references/scaffolding.md`.

---

## Design priorities, in order

When two designs compete, this ordering decides:

1. **Clear** — someone unfamiliar can find where a thing lives, and why it lives there. Convention over invention.
2. **Simple** — solve the problem in front of you. No layer for a requirement that hasn't arrived.
3. **Maintainable** — one obvious place to change each behavior. No duplicated business rules.
4. **Scalable** — structurally, so growth doesn't force a rewrite. *Not* prematurely optimized.

Most Laravel architecture wins come from **restraint, not cleverness**. A repository pattern over Eloquent, a service class wrapping one `create()`, or a module structure on a 6-table app all cost more than they return.

---

## Choosing a version

Match the project you are in — never "upgrade" or "downgrade" a working app to
satisfy a preference stated in a skill file.

For genuinely new work, the trade is between tooling lag and support window:
tutorials, Stack Overflow answers and third-party packages trail a new major by
6–18 months, but a version near end-of-life is a security problem. Check
`endoflife.date/laravel` and state the choice and its reason when scaffolding.

**Coupled majors to check before picking anything:** Filament ⇄ Livewire are
released in locked pairs and will not resolve if mixed. Pick the pair, not the
parts.

---

## Non-negotiables (apply unprompted, every time)

1. **Server-side authorization is the only authorization.** A hidden button is not security. Every mutating path gets a policy/gate check. See **security-baseline** for the per-resource "may THIS user act on THIS object" discipline this instantiates.
2. **Private user uploads go on a private disk**, served through a route that authorizes first. `public` disk means readable by URL, forever, by anyone.
3. **Read-then-write on contested state needs a transaction *and* `lockForUpdate()`.** The transaction alone does not prevent the race, and `lockForUpdate()` *outside* one releases immediately and protects nothing. Where the invariant spans tables, lock the aggregate root — the same row for every Action that can break it — not the rows each writes. See **concurrency** for the mechanism-per-window decision and the two-process test harness.
4. **Never interpolate user input into `orderBy()`, raw SQL, or a column name.** Enumerate allowed values. Same allowlist-over-interpolation rule **security-baseline** states for injection generally, applied to the identifiers Laravel's query builder cannot parameterize.
5. **Money is `decimal`, never `float`.** Compare with `bccomp()`; assign as string under a `decimal:N` cast.
6. **`{{ }}` escapes, `{!! !!}` does not.** The latter only for markup you generated. See **security-baseline** for the XSS reasoning this follows.
7. **Every fixed value set is a backed enum** in `App\Enums`, referenced from migrations, casts, forms and views — never the same list twice. With Filament that means implementing `HasLabel` / `HasColor`, **not** bespoke `label()` / `color()` methods: Filament resolves the contracts off the enum automatically, and any other method name forces a value→label map into every resource that displays the column — the duplication this rule exists to prevent.
8. **Catch N+1 before it ships** — `Model::preventLazyLoading(! app()->isProduction())`.
9. **One test persists a row from every factory.** Pint, PHPStan and Pest all pass while a factory writes a value its column cannot hold — `fake()->country()` into a `char(2)` fails only on insert. A glob-driven dataset test over `database/factories/*Factory.php` closes the class permanently. Resolve the path from `__DIR__`, not `database_path()`: dataset closures run during collection, before the app boots.
10. **Test against the engine production uses, not SQLite.** SQLite in memory ignores `VARCHAR` lengths, stores `enum` columns as free text, and cannot run `ALTER TABLE ADD CONSTRAINT` at all — so `CHECK` constraints silently do not exist under test and #9 cannot catch a truncation. Point `phpunit.xml` at MySQL and override only `DB_DATABASE` (host and credentials from the environment) so a run cannot touch dev data. If that feels too slow, the cause is almost always the durability settings below, not the engine.
11. **Validate in the database as well as the Form Request.** They answer different questions: the Form Request gives the user a readable message, the constraint holds for every write path — seeder, queued job, fixture import, raw builder — and under concurrency the application check is advisory while the constraint is not. Add `CHECK` for non-negative money and quantities, discounts below the price they reduce, percentages inside 0–100, date windows ordered, and reservations not exceeding stock. Pure join tables get a **composite primary key**, not just a unique index — same guarantee, and InnoDB clusters by it. Not expressible, so still application invariants: cross-table uniqueness, minimum cardinality, set equality across rows, and anything comparing a row to the row it replaced.

---

## Which reference to load

Load only what the task needs.

| Situation | Load |
|---|---|
| Generating schema, resources, components; what to hand-write | `references/scaffolding.md` |
| Where does this logic go; folder structure; Eloquent | `references/architecture.md` |
| Tests, static analysis, CI, definition of done | `references/quality.md` |
| Filament/Livewire/Blueprint/Eloquent traps | `references/gotchas.md` |

**Owned by other skills — do not duplicate here:**

| Situation | Skill |
|---|---|
| Auth, injection, secrets, uploads, authz-per-resource | `security-baseline` |
| Pen-testing, input abuse, vulnerability write-ups, scanners | `website-testing` |
| Races, locking, isolation, the two-process proof harness | `concurrency` |
| Schema modelling, indexing, migrations, keyset pagination | `database-design` |
| Red-green loop, test anti-patterns, seams | `tdd` |
| N+1, caching, queue jobs, framework mechanics | Boost's `laravel-best-practices` |

---

## Working style

- **Vertical slices, atomically.** One entity fully (migration → model + relations → factory/seeder → policy → admin resource → public UI) before starting a dependent one. Commit and push per slice.
- **Verify against a running app.** `php -l` proves syntax, not behavior. A generator succeeding is not evidence its output is correct. Exercise the real path — HTTP request, tinker, or test.
- **Trust real PHP over the IDE.** Trait-heavy packages (Filament) routinely produce false "undefined method" errors in Intelephense. Confirm with `php -l`, `artisan optimize:clear`, or a tinker call before believing either.

## When migrations or tests crawl, measure before you redesign

Slow DDL reads as "Laravel is slow" or "MySQL is slow" and gets worked around — usually by retreating to SQLite for tests, which silently drops every constraint guarantee. Measure the layers instead; the fix is nearly always configuration, not architecture. Observed on one project, in the order they were found:

| Cause | Test | Fix | Effect |
|---|---|---|---|
| **Container durability on a Docker Desktop volume** — `innodb_flush_log_at_trx_commit=1`, `sync_binlog=1`, binlog on, every statement fsynced to a host-backed filesystem | Time `CREATE TABLE`+`DROP TABLE` **inside the db container**. 8s means the engine, not your code | `--innodb-flush-log-at-trx-commit=2 --sync-binlog=0 --skip-log-bin` on the dev/test container only; production keeps the defaults | `migrate:fresh` 6m51s → seconds; suite 7m34s → 43s |
| **One `ALTER TABLE` per change** — each is a round trip and may rebuild the table | Count statements a migration issues against one table | Group clauses into a single `ALTER TABLE x ADD CONSTRAINT a …, ADD CONSTRAINT b …` | 45 statements 4m57s → 39s |
| **Replaying every migration per test run** | Does `migrate:fresh` say "Nothing to migrate"? | `php artisan schema:dump` (needs Oracle's `mysql-client`; Debian's `default-mysql-client` is MariaDB's and rejects Laravel's `--column-statistics=0`) | Migrations stop replaying |

Order matters: fix durability first. The other two are real but were worth ~15% next to it, and optimising them first hides the actual cause.
