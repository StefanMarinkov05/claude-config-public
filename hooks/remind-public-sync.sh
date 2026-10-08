#!/bin/bash
# Reminds at the end of a turn when skills/ changed but the public mirror
# (claude-config-public) wasn't re-synced in this same turn.
#
# Does NOT push automatically — sync-public.sh force-publishes a fresh
# history and should be a deliberate act with the diff seen first, not
# something that fires silently off the back of an unrelated edit. This
# only makes the omission visible instead of relying on remembering it
# across every future session.
#
# Scope: skills/ only, and never skills/cv-and-applications/ — that
# directory is excluded from the mirror by design, so churn there is not
# a sync-lag signal.

cd /home/azis/.claude || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

CHANGED=$(git status --porcelain -- skills/ 2>/dev/null | grep -v '^.. skills/cv-and-applications/')
[ -z "$CHANGED" ] && exit 0

# Already synced in this session? sync-public.sh's last commit message is
# fixed, so "public mirror is current" means no skills/ diff survives
# against what was last published. Cheap proxy: has sync-public.sh run more
# recently than the newest change under skills/ (excluding the CV skill)?
LATEST_CHANGE=$(git -C . log -1 --format=%ct -- skills/ ':(exclude)skills/cv-and-applications/' 2>/dev/null || echo 0)
LAST_SYNC_MARKER="/tmp/claude-last-public-sync"
LAST_SYNC=$(cat "$LAST_SYNC_MARKER" 2>/dev/null || echo 0)

# Uncommitted changes always count as "not yet synced" regardless of marker.
if [ -n "$(git status --porcelain -- skills/ 2>/dev/null | grep -v '^.. skills/cv-and-applications/')" ] \
   || [ "$LATEST_CHANGE" -gt "$LAST_SYNC" ]; then
  jq -n '{
    systemMessage: "📤 skills/ changed and the public mirror (claude-config-public) may be behind. Run `~/.claude/sync-public.sh --dry-run` to review, then `~/.claude/sync-public.sh` to publish — nothing pushes there automatically."
  }'
fi

exit 0
