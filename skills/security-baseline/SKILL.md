---
name: security-baseline
description: Application security baseline - input validation, authentication/authorization, secrets, dependency hygiene, and a security-review checklist for code and PRs. Use whenever writing or reviewing code that handles user input, auth, sessions, file uploads, payments, or personal data; before any deployment; when acting as a security-reviewer agent; or when the user asks "is this secure". Trigger automatically for any endpoint, form, SQL/ORM query, or authentication code, even if security isn't mentioned.
---

# Security Baseline

Security is a property of defaults, not a feature sprint. These are the invariants every web/app codebase maintains; a security-reviewer agent runs the checklist at the end on every PR touching a trust boundary.

## The trust-boundary rule

All input is hostile until parsed and validated: HTTP params, headers, cookies, file uploads, webhook payloads, DB contents written by another system, LLM outputs, and messages from your own other services. Validate at the boundary with allowlists (what IS valid) not blocklists; convert into typed values once (parse-don't-validate, see code-quality), then the core trusts by construction.

## Injection (still #1 after 25 years)

- **SQL**: parameterized queries/ORM parameters, always, no exceptions. String-built SQL is a [blocker] in review even if inputs "are already validated". Dynamic table/column names: allowlist map, never interpolation.
- **Command**: no shell string building; use exec APIs with argument arrays. Better: don't shell out for what a library does.
- **XSS**: framework auto-escaping on by default; every escape hatch (`dangerouslySetInnerHTML`, `v-html`, `innerHTML`) requires sanitization (DOMPurify-class) and a review justification. Set a Content-Security-Policy.
- **Path traversal**: resolve to absolute and verify the result is under the allowed root before any file access with user-influenced names.
- **SSRF**: user-supplied URLs fetched server-side get scheme+host allowlists; block private ranges/metadata endpoints (169.254.169.254).
- **Deserialization**: never deserialize untrusted data with formats that execute (pickle, Java native, YAML full loader). JSON + schema validation.

## AuthN & AuthZ

- **Never hand-roll**: password hashing = argon2id/bcrypt via library; sessions/OAuth/JWT via the platform's mature library. Custom crypto or session logic is a [blocker].
- Sessions: httpOnly + Secure + SameSite cookies; regenerate session id on login; server-side revocation possible. JWTs: short-lived access + rotating refresh, verify signature *and* alg allowlist, never `alg:none`.
- **Authorization on every request, server-side, per resource**: the check is "may THIS user act on THIS object" (`WHERE id = ? AND owner_id = ?`), not "is the user logged in". IDOR - fetching by id without ownership check - is the most common real-world authz bug; grep for it explicitly in review.
- Deny by default: new endpoints require auth unless explicitly public. Client-side checks are UX, never security.
- Rate-limit auth endpoints; uniform error messages and timing on login ("invalid credentials", not "wrong password"); MFA support for anything valuable.

## Secrets & data

- No secrets in code, git history, logs, error messages, or client bundles (anything in frontend env vars is public). Env vars / secret manager; rotate on any suspected leak - a secret that entered git history is compromised, period.
- TLS everywhere including service-to-service; HSTS on.
- Personal data: collect minimum, define retention, hard-delete on request (GDPR); encrypt sensitive-at-rest; logs carry ids not payloads (no passwords, tokens, card numbers, health data in logs - log redaction is a launch blocker, not polish).
- Passwords: hashed (never encrypted/reversible), no max-length silliness, check against breached-password lists.

## Dependencies & platform

- Lockfiles + automated vulnerability scanning (npm audit / pip-audit / Dependabot) in CI; a critical CVE in a direct dependency blocks deploy.
- New dependency = supply-chain decision (see tech-selection): maintenance health, typosquat check, install scripts.
- Error handling: users get generic errors + correlation id; stack traces and versions go to logs only. Debug mode off in prod.
- Uploads: size limits, content-type verification by magic bytes not extension, store outside webroot / in object storage, never execute-able paths.
- Security headers: CSP, X-Content-Type-Options, frame-ancestors; CORS allowlist specific origins - `*` with credentials is a [blocker].

## Security review checklist (run per PR at trust boundaries)

1. New input paths → where's the validation, what's the type after parsing? 2. New queries → parameterized? ownership in WHERE? 3. New endpoints → auth required? authz per-resource? rate-limited if sensitive? 4. Anything secret touched → in env/manager, absent from logs/errors/client? 5. Escape hatches (`raw`, `dangerously*`, `exec`, `eval`) → each individually justified? 6. Dependency changes → audit clean? 7. Error paths → leak internals? 8. Could user A read/modify user B's data through any new path?

Findings use code-review severity ([blocker]/[should]/[nit]); injection, authz bypass, secret exposure, and broken session handling are always [blocker].
