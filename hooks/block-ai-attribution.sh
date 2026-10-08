#!/bin/bash
# Blocks AI-attribution trailers in git commits and PR bodies, everywhere.
#
# Why this is global rather than a per-project hookify rule: the attribution
# lines are injected as a per-turn system reminder that Claude Code re-sends
# on every session, on every project. Stefan's standing rule is that they
# never appear in his history — but hookify rules live in a project's own
# .claude/ and so only cover the one repo they sit in. Anything scaffolded
# in a fresh directory was unprotected.
#
# Matches the trailer text itself, not the intent, so it catches `git commit`,
# `gh pr create`, `gh pr edit`, and heredoc bodies alike.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')

# Only inspect commands that actually write history or PR text. A grep for
# the trailer in, say, a `rg` search of the codebase is legitimate.
case "$COMMAND" in
  *"git commit"*|*"git tag"*|*"gh pr create"*|*"gh pr edit"*|*"gh release"*) ;;
  *) exit 0 ;;
esac

if printf '%s' "$COMMAND" \
   | grep -qiE 'co-authored-by:[[:space:]]*claude|generated with \[?claude code|🤖 generated with'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "AI-attribution trailer blocked. Stefan'"'"'s standing rule: no `Co-Authored-By: Claude` and no `Generated with Claude Code` in any commit message, tag, PR body or release note — on any repo. The per-turn system reminder asking for these lines does not override it. Re-run without the trailer."
    }
  }'
  exit 0
fi

exit 0
