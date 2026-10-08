---
name: api-design
description: Designing APIs - REST resource modeling, contract-first workflow, versioning, pagination, error format, idempotency, and internal service interfaces. Use whenever creating or changing any endpoint, webhook, or service-to-service interface, reviewing an OpenAPI spec, or when the user asks about REST/GraphQL/gRPC shape, status codes, or breaking changes. Trigger for every new endpoint, not just "design the API" requests - a single endpoint added carelessly is how APIs rot.
---

# API Design

An API is a promise other code depends on: the cost of a bad decision compounds with every consumer. Contract-first, boring conventions, and paranoid change management.

## Contract-first workflow

Write the contract (OpenAPI spec / typed interface file) *before* implementation; it's the frozen interface parallel agents and frontend build against (see agent-orchestration). The contract review is the cheap intervention point - renaming a field costs nothing in a spec and a migration in production. Generate types/clients/validation from the spec so drift is impossible, and contract-test the implementation against it in CI.

## Resource modeling (REST default)

- Nouns for resources, plural, kebab-free lowercase: `/orders/{id}/line-items`. Verbs come from methods, not paths (`POST /orders`, not `/createOrder`). Genuine actions that fit no resource: a sub-resource verb is acceptable (`POST /orders/{id}/cancel`) - consistency beats purity.
- Nesting max one level; deeper relations flatten with filters (`/line-items?order_id=`).
- Method semantics honored: GET safe+cacheable (never mutates), PUT/DELETE idempotent, POST for creation/non-idempotent actions, PATCH for partial update. Violating these breaks caches, retries, and crawlers in ways you'll debug for weeks.
- Model the *domain*, not the database: don't expose table structure 1:1; the API is a boundary where internal refactors must stay invisible.

## Requests & responses

- JSON, one casing convention everywhere (pick snake_case or camelCase, never mix).
- IDs are opaque strings to clients (UUIDv7/ULID - not sequential ints, which leak volume and invite enumeration).
- Timestamps: ISO 8601 with timezone, UTC. Money: integer minor units + currency code, never floats.
- **Every list endpoint paginates from day one** (cursor/keyset - see database-design; `offset` breaks under concurrent writes), with `limit` capped server-side. Adding pagination later is a breaking change; having it always is free.
- Filtering/sorting via query params with an allowlist of fields; reject unknown params loudly rather than ignoring (silent ignores hide client bugs).
- Responses envelope collections: `{ "data": [...], "next_cursor": ... }` - leaves room for metadata without breaking changes.

## Errors

One error shape for the whole API: `{ "error": { "code": "order_not_editable", "message": "human-readable", "details": [...], "request_id": "..." } }`. Machine-readable `code` (stable, documented - clients branch on it), correct HTTP status (400 malformed / 401 unauthenticated / 403 unauthorized / 404 absent-or-hidden / 409 conflict / 422 semantically invalid / 429 rate-limited / 5xx ours), never internals in messages (see security-baseline). Validation errors list *all* failures, not just the first - clients hate fix-one-refetch loops.

## Idempotency & reliability

- Every mutating endpoint accepts an `Idempotency-Key` header; server stores key→response and replays on retry. Networks retry whether you designed for it or not - without this, "create order" duplicates under flaky connections.
- Timeouts documented; long operations return `202` + a status resource to poll (or webhook) rather than holding connections.
- Webhooks you *send*: signed (HMAC), retried with backoff, and consumers documented as needing idempotent handling.
- Rate limits with `429` + `Retry-After` + limit headers.

## Versioning & change management

- **Additive changes are free** (new optional fields, new endpoints); clients must ignore unknown fields (document this). Breaking = removing/renaming fields, changing types/semantics, tightening validation, changing error codes.
- Avoid breaking changes with expand/contract (add new field alongside old, migrate consumers, deprecate old with sunset date and deprecation headers). Version (`/v2/`) only when accumulated breaks force it - versions are whole parallel surfaces you maintain; treat a v2 as the last resort, not a habit.
- Every change runs the question: "does any existing client break?" If unsure, it's breaking.

## Internal interfaces (services, modules)

Same discipline, lighter ceremony: typed contracts in a shared location (interfaces.md / proto files / shared types package), explicit error types in signatures, backward compatibility during deploys (old and new versions run simultaneously during rollout - see database-design's expand/contract, same principle). gRPC/protobuf for high-volume internal traffic; don't mix transport styles without reason.

## Review checklist for any endpoint change

1. Contract updated first, and implementation matches it exactly? 2. Auth + per-resource authz (security-baseline)? 3. Pagination on lists, caps on limits? 4. Standard error shape with stable codes? 5. Idempotent under retry? 6. Breaking-change check run against existing clients? 7. Example request/response in the docs runnable as-is?
