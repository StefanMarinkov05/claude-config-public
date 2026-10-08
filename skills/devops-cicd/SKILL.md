---
name: devops-cicd
description: CI/CD pipelines, environments, deployment strategies, rollback, observability, and operational readiness. Use whenever setting up or modifying CI (GitHub Actions etc.), Dockerizing an app, deploying to any environment, configuring monitoring/alerts/logging, planning a release, or when something is broken in prod and rollback is needed. Also for "how do I ship this" questions on any project. Trigger for any deployment-touching task even if phrased as a coding task.
---

# DevOps & CI/CD

The goal: any green commit on main can reach production through an automated, boring, reversible path. Deployment fear is a symptom of missing automation; the fix is pipeline work, not courage.

## CI pipeline (the gate stack, automated)

Runs on every PR and every merge to main, ordered cheap→expensive so failures are fast:
1. Lint + format + typecheck
2. Unit tests
3. Build artifact (the *same* artifact that will deploy - build once, promote everywhere; rebuilding per environment means testing one thing and shipping another)
4. Integration tests against real services in containers (real Postgres, not mocks)
5. Security: dependency audit + secret scan
6. Migration dry-run against production-shaped schema

Rules: full suite < ~10 min (parallelize/split beyond that - slow CI trains people and agents to skip it), zero flaky-test tolerance (quarantine + ticket immediately; a suite people rerun is a suite nobody believes), red main = stop-the-line, no manual steps between commit and deployable artifact.

## Environments & config

- Minimum: dev (local, docker-compose up gives the whole stack) → staging (production-shaped: same infra type, same migrations, anonymized-realistic data) → production. Staging that doesn't resemble prod is theater.
- **Config via environment, code identical across environments.** The artifact never contains environment names or secrets; behavior differences come only from injected config. Secrets from a secret manager, never files in the repo (see security-baseline).
- Parity killers to check when "works in staging, fails in prod": data volume, concurrency, config drift, third-party sandbox-vs-live behavior.

## Containers (default packaging)

Multi-stage Dockerfile (build stage → slim runtime image), pinned base image versions, non-root user, `.dockerignore` (secrets, .git, node_modules), healthcheck endpoint baked in. Image tagged with the git SHA - every running container traceable to a commit. Compose file for local dev that matches production topology in miniature.

## Deployment strategies

- Default: **rolling deploy behind a health check** - new instances must pass readiness before receiving traffic; deploy halts on failures.
- Higher stakes: blue/green (two full environments, instant switch/rollback) or canary (small % of traffic to new version, watch error rate, ramp).
- **Feature flags decouple deploy from release**: ship dark, enable per-cohort, kill instantly without redeploy. Risky changes go behind flags by default; flags removed after full rollout (flag debt is real).
- DB changes always precede code that needs them, always backward-compatible with the still-running old version (expand/contract, see database-design). This single rule is what makes rollback possible.

## Rollback (design for it before deploying)

- Rollback = redeploy previous artifact tag; must be one command/click and rehearsed, not improvised at 3am. If migrations followed expand/contract, old code runs fine on the new schema - never write a deploy whose rollback requires a down-migration under pressure.
- Deploy log: who/what/when, so "what changed?" during an incident takes seconds.
- Post-deploy verification is part of the deploy: smoke test + watch error-rate/latency dashboards for the bake period; auto-rollback on threshold breach if the platform supports it.

## Observability (the three pillars, from day one)

- **Structured logs** (JSON): request id propagated across services, level discipline (ERROR = human should look, not decoration), no PII/secrets. Centralized and searchable.
- **Metrics**: the four golden signals per service - latency (p50/p95/p99, never averages alone), traffic, error rate, saturation (CPU/mem/conn-pool/queue depth). Plus business pulse metrics (signups, orders) - they catch what technical metrics miss.
- **Traces** for multi-service paths: where did this request spend its 3 seconds?
- **Alerts page on symptoms users feel** (error rate, latency SLO burn), dashboards show causes. Alert hygiene: every page is actionable + linked to a runbook section; a noisy pager trains ignoring, which is worse than no pager.

## Operational readiness checklist (before first prod deploy)

1. One-command deploy and one-command rollback, both tested? 2. Health/readiness endpoints? 3. Logs centralized, metrics dashboarded, alerts wired to a human? 4. Backups automated *and restore rehearsed* (an untested backup is a hope, not a backup)? 5. Runbook with top failure modes (see docs-and-comments)? 6. Secrets in manager, TLS on, debug off? 7. Load tested at 2-3x expected peak? 8. On a solo/agent-built project, the answer to "who gets paged" is you - so thresholds tuned to what you'll actually respond to.
