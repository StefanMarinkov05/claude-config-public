---
name: database-design
description: Database design - schema modeling, normalization, indexing, query performance, and migrations. Use whenever a project needs a data model, the user shows a schema or ERD, asks about tables/relations/keys, complains about slow queries, plans a migration or schema change, or chooses between SQL and NoSQL storage. Also use when reviewing Prisma/EF Core/Django models or writing DDL. Trigger even for "just add a column" requests - column additions are migrations.
---

# Database Design

The data model outlives every framework choice in the project. Design it from the queries backward and the invariants forward.

## Design Procedure

1. **List entities and true invariants first.** What must always hold? ("an order always belongs to a user", "email unique", "balance never negative"). Invariants become constraints - enforced in the database, not only in application code, because every future app/script/bug bypasses app code eventually.
2. **List the top queries and their frequency** before drawing tables. Schema serves access patterns; a schema designed without knowing its queries is decoration.
3. **Model in 3NF by default.** Every non-key column depends on the key, the whole key, and nothing but the key. Practical smells that demand normalization: repeated column groups (`phone1, phone2`), comma-separated values in a column, the same fact stored in two places, columns that are often NULL for entire categories of rows (split the entity).
4. **Denormalize only against a measured read problem**, and treat every denormalized copy as a cache: document its source of truth and the mechanism that keeps it fresh (trigger, transactional write, or async job with staleness bound).
5. **Choose keys deliberately.** Surrogate PK (bigint identity or UUIDv7 - not UUIDv4 if the table is large and insert-heavy, random UUIDs shred index locality). Keep natural keys as UNIQUE constraints. Never build meaning into the PK.

## Column & Constraint Rules

- Correct types: `timestamptz` for time (always UTC in storage), `numeric` for money (never float), `text` with CHECK over `varchar(n)` guessing, native `boolean`, arrays/`jsonb` only for genuinely schemaless payloads.
- `NOT NULL` by default; NULL must mean something specific ("unknown", not "false" or "empty").
- Every FK explicit with a deliberate `ON DELETE` (RESTRICT default; CASCADE only when the child is meaningless without the parent; SET NULL for optional links).
- CHECK constraints for domain rules (`price >= 0`, enum-like status via CHECK or lookup table).
- Soft delete (`deleted_at`) only when undelete/audit is a real requirement - it complicates every query and unique constraint (use partial unique indexes: `UNIQUE ... WHERE deleted_at IS NULL`).

## Indexing

- PKs and unique constraints index themselves. Beyond that, **index from the query log, not imagination**: every index costs write throughput and storage.
- Index FK columns (joins + cascades need them; Postgres does not auto-index FKs).
- **Composite index column order**: equality columns first, then the range/sort column. An index on `(user_id, created_at)` serves `WHERE user_id = ? ORDER BY created_at DESC`; the reverse order doesn't.
- A leading-column prefix of a composite index makes a separate single-column index on that column redundant.
- Covering indexes (`INCLUDE`) for hot queries to enable index-only scans.
- Partial indexes for skewed predicates (`WHERE status = 'pending'` when 1% of rows are pending).
- GIN for jsonb/array/full-text; B-tree for everything ordinary.
- Verify with `EXPLAIN (ANALYZE, BUFFERS)`. Seq scan on a big table in a hot path = missing/unusable index; also check the planner isn't defeated by a function on the column (`WHERE lower(email) = ?` needs an expression index).

## Query Performance Essentials

- N+1 is the top real-world killer: fetch relations with joins or batched `IN` queries (in ORMs: eager-load explicitly, review generated SQL).
- Paginate with keyset (`WHERE (created_at, id) < (?, ?) ORDER BY ... LIMIT n`), not `OFFSET`, for deep pages.
- Keep transactions short; never hold one across network calls or user think-time.
- Lock ordering consistent to avoid deadlocks; use `SELECT ... FOR UPDATE SKIP LOCKED` for job-queue patterns.
- Know your isolation level: READ COMMITTED default; use explicit locking or SERIALIZABLE (with retry) where invariants span rows. Note that lost update and write skew are prevented by *no* isolation level short of SERIALIZABLE - "wrap it in a transaction" is not a fix for check-then-act. Load **concurrency** before designing or reviewing any locking, and before writing a test that claims to prove one works.

## Migrations

- Every schema change is a versioned, ordered migration file in the repo, run by a tool (Prisma Migrate, EF migrations, Flyway, Alembic). No manual prod DDL, ever.
- Migrations must be **forward-safe with running old code** (expand/contract pattern):
  1. *Expand*: add the new nullable column/table/index (backwards compatible), deploy.
  2. *Backfill* in batches (throttled; never one giant UPDATE locking the table).
  3. *Switch* code to write+read new shape, deploy.
  4. *Contract*: enforce NOT NULL/constraints, drop old columns - in a later release, after verification.
- Dangerous-in-place operations on big tables: adding NOT NULL with default (fine in PG11+, dangerous before), type changes (add new column + backfill instead), index creation (`CREATE INDEX CONCURRENTLY` in Postgres).
- Down-migrations for dev convenience; in prod, roll forward. Backfill scripts are code: reviewed, tested, idempotent, resumable.
- Test every migration against a production-shaped dataset (size and skew), not an empty dev DB.

## SQL vs Other Stores

Postgres handles relational + jsonb + full-text + queues + pub/sub adequately to surprisingly large scale - one system, one backup story. Reach for a second store only for a proven mismatch: Redis (sub-ms hot keys, ephemeral), object storage (blobs - never blobs in the DB, store keys), ClickHouse/warehouse (analytical scans over billions of rows), Elasticsearch (search relevance features beyond PG FTS). Every additional store doubles the consistency and ops surface - the data now lives in two places with no transaction spanning them.

## Deliverables

When designing: entity list with invariants → DDL (or ORM schema) with all constraints → the top queries with the indexes that serve them → migration plan if changing an existing system. Comment the *why* on every non-obvious constraint and index - schemas are teaching documents.
