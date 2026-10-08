#!/usr/bin/env bash
#
# Publish a CV-free snapshot of this skill library to the public mirror.
#
#   ./sync-public.sh                 # rebuild + push the public repo
#   ./sync-public.sh --dry-run       # build the snapshot, don't push
#
# How it works: builds a fresh copy of the repo in a scratch directory,
# deletes skills/cv-and-applications/ before it is ever committed, patches
# the two doc mentions of that skill, then force-pushes ONE new commit as
# the entire history of the public repo. No shared git history with the
# private repo — the CV data (name, phone numbers, address, photo) never
# exists in any commit the public repo can reach, not even an old one.
#
# This means the public repo's history is NOT incremental — every run
# replaces it wholesale. That's deliberate: incremental history is exactly
# what would let a future accidental CV commit linger in the public log
# after being "removed" in a later commit.

set -euo pipefail

cd "$(dirname "$0")"

PUBLIC_REMOTE="git@github.com:StefanMarinkov05/claude-config-public.git"
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

echo "Building snapshot in $SCRATCH ..."

# Only copy what git actually tracks here — this automatically respects
# .gitignore, so credentials/transcripts/caches are never even considered.
git ls-files -z | rsync -a0 --files-from=- . "$SCRATCH"

# --- The one directory that must never reach the public repo. -------------
rm -rf "$SCRATCH/skills/cv-and-applications"

# --- Guard: refuse if anything CV-shaped survived the deletion. -----------
if find "$SCRATCH" -iname '*cv*' -o -iname '*resume*' | grep -q .; then
  echo "ABORT: a CV-shaped file survived the exclusion:" >&2
  find "$SCRATCH" -iname '*cv*' -o -iname '*resume*' >&2
  exit 1
fi

# --- Patch the two doc mentions so the public index doesn't dangle. -------
python3 - "$SCRATCH" <<'PYEOF'
import re, sys
root = sys.argv[1]

skills_readme = f"{root}/skills/README.md"
with open(skills_readme, encoding="utf-8") as f:
    text = f.read()

# Token-cost table row.
text = re.sub(
    r"\| `cv-and-applications` \|.*\|\n", "", text
)
# "Personal / non-engineering" section entry.
text = re.sub(
    r"## Personal / non-engineering\n\n- \*\*cv-and-applications\*\*.*?\n\n",
    "",
    text,
    flags=re.S,
)
with open(skills_readme, "w", encoding="utf-8") as f:
    f.write(text)
print("patched skills/README.md")
PYEOF

# --- Top-level README: note the exclusion explicitly rather than silently
#     having a skill vanish with no explanation. -----------------------
cat >> "$SCRATCH/README.md" <<'EOF'

## What this public mirror excludes

This is a filtered copy of a private repo. `skills/cv-and-applications/` —
personal CV/job-application material (contact details, a photo) — is
deliberately not published here, in this commit or any other. The mirror is
rebuilt from scratch and force-pushed as a single commit each time, so
excluded material never enters this repo's history at all.
EOF

# --- Guard: no credential-shaped strings, same check sync-skills.sh uses.
#     Excludes sync-skills.sh/sync-public.sh themselves, which legitimately
#     contain this exact regex as their own detection pattern. -------------
if grep -rnE '(sk_live_|sk_test_|whsec_|ghp_|github_pat_|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY)' "$SCRATCH" \
   --exclude-dir=.git --exclude='sync-skills.sh' --exclude='sync-public.sh' ; then
  echo "" >&2
  echo "ABORT: the snapshot contains something shaped like a credential." >&2
  exit 1
fi

# --- Build it as one fresh commit, no parent. ------------------------------
(
  cd "$SCRATCH"
  git init -q -b main
  git add -A
  git commit -q -m "Public snapshot of claude-config (auto-generated, excludes skills/cv-and-applications)"
)

FILE_COUNT=$(git -C "$SCRATCH" ls-files | wc -l | tr -d ' ')
echo "Snapshot built: $FILE_COUNT files."

if $DRY_RUN; then
  echo "Dry run — not pushing. Inspect at: $SCRATCH"
  trap - EXIT   # keep the scratch dir around for inspection
  exit 0
fi

git -C "$SCRATCH" push --force "$PUBLIC_REMOTE" main:main
echo "Pushed to $PUBLIC_REMOTE"

# Marks "synced as of now" for hooks/remind-public-sync.sh, which otherwise
# has no way to tell a fresh push apart from one that's overdue.
date +%s > /tmp/claude-last-public-sync
