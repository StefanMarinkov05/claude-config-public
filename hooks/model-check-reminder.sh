#!/bin/bash
# Reminds a human to verify the actual model via the UI indicator before
# trusting the model's own self-reported name, which has been observed
# stale/wrong compared to the UI after mid-session /model switches.
#
# Cannot read the real model name — that's not exposed to hook commands —
# so this only forces the check, once per session (throttled via a
# per-session-id sentinel file), rather than firing on every tool call.

SESSION_ID=$(cat | jq -r '.session_id // "unknown"')
SENTINEL="/tmp/claude-model-check-${SESSION_ID}"

if [ -f "$SENTINEL" ]; then
  exit 0
fi

touch "$SENTINEL"
echo '{"systemMessage": "⚠️  Model check: verify the model shown in the UI (bottom-left indicator) before trusting any self-reported model name this session."}'
