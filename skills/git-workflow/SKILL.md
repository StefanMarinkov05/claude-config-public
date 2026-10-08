---
name: git-workflow
description: Git conventions for solo, team, and multi-agent development - branching model, atomic commits, conventional commit messages, PR discipline, merge order, conflict resolution, and history hygiene. Use whenever committing code, creating branches or PRs, coordinating parallel agents on one repo, resolving merge conflicts, or when the user asks about rebase vs merge, commit messages, or repo organization. Apply automatically in any pipeline where multiple agents write to the same repository.
---

# Git Workflow (Human & Agent Teams)

Git is the coordination substrate of a multi-agent team: the branch model *is* the concurrency model. Sloppy git turns parallel agents into a merge-conflict generator.

## Branching model

- `main` is always green (builds + full suite passes) and always deployable. Red main = stop-the-line; nothing merges until fixed.
- **One branch per task**, named `type/NNN-short-desc` matching the task file: `feat/012-keyset-pagination`, `fix/031-null-email`. Branch from fresh `main`, live ≤ a few days - long-lived branches are conflict farms.
- Agents: **one agent, one task, one git worktree** (`git worktree add ../proj-012 feat/012-desc`) - full working-directory isolation, so parallel agents can't trample each other's uncommitted files or fight over checkouts; branches alone isolate commits, not the working tree. Detect existing isolation before creating one (`git rev-parse --git-dir` differs from `--git-common-dir` in a worktree - but also in submodules, so check `--show-superproject-working-tree` first); `git worktree remove` at merge time. An agent never commits to another agent's branch or to main directly.
- Merge via PR only, after gates pass (verification-gates skill). Merge order follows the task DAG: contract/schema changes land first, dependents rebase on them.

## Commits

- **Atomic**: one logical change per commit; the build passes at every commit. "WIP" and "fixes" commits get squashed before PR review.
- Never mix a refactor with a behavior change in one commit - it makes both unreviewable. Refactor commit first, behavior commit second.
- **Conventional messages**: `type(scope): imperative summary ≤72 chars`, types: feat, fix, refactor, test, docs, chore, perf. Body answers *why* (the diff already shows what): motivation, alternative rejected, links to task/issue. Agent commits include the task id: `feat(orders): add keyset pagination [task 012]`.
- Commit early and often on the branch (each green micro-step) - commits are the agent's checkpoint/restart mechanism (see context-handoff).

## Merging & conflicts

- Keep feature branches current by **rebasing onto main** (linear, readable history); never rebase shared/pushed-and-pulled-by-others branches - merge instead. Into main: squash-merge for noisy branches, merge-commit for well-crafted multi-commit branches; pick one repo-wide default.
- Conflict resolution is a *semantic* task, not textual: understand both changes' intent, re-run the full suite after resolving. Agents resolving conflicts must state in the PR what both sides intended and what the resolution preserves; non-trivial conflicts (same function, both sides changing behavior) escalate to human.
- Prevention beats resolution: task decomposition along file boundaries (agent-orchestration skill), contract files land before parallel work starts, rebase frequently.

## PRs

- One task per PR; ≤ ~400 lines of real diff or split it.
- Description = the task's contract + evidence per done-criterion (test names, command outputs) + decisions.md entries made. Reviewer works from this + diff alone.
- CI runs the full gate stack on every PR; a PR with red CI is not reviewable yet.

## History & repo hygiene

- Never force-push shared branches; never rewrite main. `revert` for landed mistakes (preserves history), `reset` only on private unpushed work.
- Tag releases (`vX.Y.Z`); every deploy is traceable to a commit.
- `.gitignore` complete before first commit (build artifacts, env files, IDE cruft). Secrets never enter history - if one does, rotate the secret immediately; scrubbing history is damage control, not the fix.
- Lockfiles committed; generated files either committed consistently or ignored consistently, never both.
- Bisect-friendliness is the payoff of atomic green commits: `git bisect` finds the breaking change automatically only if every commit builds.

## Recovery cheatsheet

Wrong branch committed → `git switch correct; git cherry-pick SHA; git switch wrong; git reset --hard HEAD~1`. Lost work → `git reflog` (it's almost never actually lost). Undo a landed PR → `git revert -m 1 MERGE_SHA`. Amend last unpushed commit → `git commit --amend`. When unsure, branch/tag the current state first - the mistakes that hurt are the ones made *during* recovery.
