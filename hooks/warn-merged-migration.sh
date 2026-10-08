#!/bin/bash
# Warns before editing a migration that is already merged to the main branch.
#
# Generalised from Online_Shop_TeamB's hookify rule. The principle is not
# Laravel-specific: once a migration has run in any environment, editing the
# file changes what it *claims* to do without changing what that environment
# *did*. A fresh database then diverges silently from a migrated one.
#
# Unlike the repo-local rule, this checks git rather than pattern-matching a
# fixed path, so it stays quiet for a migration you just created and only
# speaks up when the file actually exists on the main branch.

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')

[ -z "$FILE" ] && exit 0

# Common migration layouts: Laravel, Rails, Django, Alembic, Flyway, Prisma.
case "$FILE" in
  *migrations/*|*migrate/*|*db/migrate/*) ;;
  *) exit 0 ;;
esac

cd "$(dirname "$FILE")" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Which branch is "main" here?
MAIN=""
for candidate in main master; do
  git show-ref --verify --quiet "refs/heads/$candidate" && { MAIN="$candidate"; break; }
done
[ -z "$MAIN" ] && exit 0

REL=$(git ls-files --full-name -- "$(basename "$FILE")" 2>/dev/null | head -1)
[ -z "$REL" ] && exit 0   # untracked = brand new = editing is fine

# Does it exist on main, and does the working copy already differ from it?
if git cat-file -e "$MAIN:$REL" 2>/dev/null; then
  jq -n --arg f "$(basename "$FILE")" --arg b "$MAIN" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: ("⚠️  \($f) already exists on \($b) — migrations are append-only once merged. Every environment that has run it keeps the old schema while the file claims the new one, so a fresh database diverges silently from a migrated one. Add a NEW migration for this change instead of editing this file. (If you are deliberately amending an unreleased migration, say so and proceed.)")
    }
  }'
fi

exit 0
