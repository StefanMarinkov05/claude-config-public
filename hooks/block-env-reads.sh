#!/bin/bash
# Blocks reading/printing/copying a .env file, on every project.
#
# Promoted from Online_Shop_TeamB's hookify rule, which only covered the one
# repo it lived in. The failure it prevents is not repo-specific: reading
# .env puts live credentials into the session transcript, where they persist
# after the task is over and outlive any rotation you forget to do.
#
# .env.example is explicitly allowed — the negative lookahead on [.\w-] after
# `.env` is what distinguishes them.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')

[ -z "$COMMAND" ] && exit 0

READERS='cat|head|tail|less|more|bat|nl|od|xxd|strings|grep|rg|awk|sed|cp|scp|source|dotenv'

if printf '%s' "$COMMAND" \
   | grep -qiE "\b($READERS)\b[^|;&\n]*?(^|[[:space:]=])([[:alnum:]./_-]*/)?\.env(\$|[^.[:alnum:]_-])"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Reading .env is blocked. Live credentials must never enter the transcript — they persist after the session ends. Instead: read `.env.example` for which keys exist; check whether a key is set without printing it (e.g. `config(...) !== ''` in tinker, or `[ -n \"${VAR:-}\" ]`); to change a value, tell the user which key to set. `.env.example` is allowed and does not trigger this."
    }
  }'
  exit 0
fi

exit 0
