#!/usr/bin/env bash
#
# PreCompact guard: a manual /compact is confirmed, never taken on the first
# press.
#
# Compaction is not reversible from inside the session — once the transcript
# is summarised, the detail is gone. /compact also sits next to commands
# people press often, so a misclick is cheap to make and expensive to undo.
#
# First press is refused with an explanation. A second press within the
# window goes through, so a deliberate compact costs one extra keystroke and
# an accidental one costs nothing.
#
# Automatic compaction (trigger "auto") is never blocked: that fires because
# the context window is genuinely full, and refusing it would wedge the
# session rather than protect anything.

set -uo pipefail

WINDOW_SECONDS=45
STATE_DIR="${TMPDIR:-/tmp}/claude-compact-confirm"
mkdir -p "$STATE_DIR" 2>/dev/null || true

payload="$(cat)"

# jq is not guaranteed to be present; fall back to grep so the hook degrades
# to "always ask" rather than to "never fire".
if command -v jq >/dev/null 2>&1; then
  trigger="$(printf '%s' "$payload" | jq -r '.trigger // "manual"')"
  session="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"')"
else
  trigger="$(printf '%s' "$payload" | grep -o '"trigger"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  session="$(printf '%s' "$payload" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  trigger="${trigger:-manual}"
  session="${session:-unknown}"
fi

# Auto-compaction is the context window filling up, not a click. Let it run.
if [ "$trigger" != "manual" ]; then
  exit 0
fi

stamp_file="$STATE_DIR/$(printf '%s' "$session" | tr -c 'A-Za-z0-9_.-' '_')"
now="$(date +%s)"

if [ -f "$stamp_file" ]; then
  last="$(cat "$stamp_file" 2>/dev/null || echo 0)"
  case "$last" in (*[!0-9]*|'') last=0 ;; esac
  if [ "$((now - last))" -le "$WINDOW_SECONDS" ]; then
    rm -f "$stamp_file"
    printf 'Compaction confirmed — proceeding.\n'
    exit 0
  fi
fi

printf '%s' "$now" > "$stamp_file"

cat <<'MSG'
Compaction was NOT run.

/compact is irreversible inside this session: the transcript is replaced by a
summary and the detail cannot be recovered. This guard exists because the
command is easy to hit by accident.

  • Meant it?      Press /compact again within 45 seconds and it will run.
  • Misclicked?    Do nothing. Nothing has changed.

(Automatic compaction, when the context window genuinely fills, is never
blocked by this guard.)
MSG

exit 2
