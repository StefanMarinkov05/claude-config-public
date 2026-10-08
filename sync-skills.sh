#!/usr/bin/env bash
#
# Push the current state of ~/.claude/skills, skill-archive, and settings.json
# to the private backup repo.
#
#   ./sync-skills.sh                 # commit with a generated message
#   ./sync-skills.sh "why I changed" # commit with your own message
#
# Safe to run when nothing changed — it exits without creating an empty commit.

set -euo pipefail

cd "$(dirname "$0")"

# --- Guard: refuse to run if the ignore file is missing or weakened. --------
# This directory holds credentials and every conversation transcript. The
# .gitignore is the only thing keeping them out, so verify it still works
# rather than trusting that nobody edited it.
for must_be_ignored in .credentials.json history.jsonl projects settings.local.json; do
  if [ -e "$must_be_ignored" ] && ! git check-ignore -q "$must_be_ignored"; then
    echo "ABORT: '$must_be_ignored' is not ignored. Refusing to push." >&2
    echo "Check .gitignore before running this again." >&2
    exit 1
  fi
done

# --- Guard: no credential-shaped strings in what we are about to commit. ----
# Excludes sync-skills.sh/sync-public.sh's own diff hunks, which legitimately
# contain this exact regex as their own detection pattern.
git add -A
if git diff --cached -U0 -- . ':(exclude)sync-skills.sh' ':(exclude)sync-public.sh' \
   | grep -nE '(sk_live_|sk_test_|whsec_|ghp_|github_pat_|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY)' ; then
  echo "" >&2
  echo "ABORT: the staged diff contains something shaped like a credential." >&2
  echo "Nothing was committed. Inspect the lines above." >&2
  git reset >/dev/null
  exit 1
fi

if git diff --cached --quiet; then
  echo "No changes to sync."
  git reset >/dev/null
  exit 0
fi

echo "Files changed:"
git diff --cached --name-status
echo ""

msg="${1:-skills: sync $(date +%Y-%m-%d\ %H:%M)}"
git commit -q -m "$msg"
git push -q origin main
echo "Pushed: $msg"
