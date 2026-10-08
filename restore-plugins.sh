#!/usr/bin/env bash
#
# Reinstall the plugins listed in plugins.md on a fresh machine.
# Idempotent: re-running skips anything already installed.

set -euo pipefail

MARKETPLACE="anthropics/claude-plugins-official"
USER_PLUGINS=(hookify playwright chrome-devtools-mcp stripe)

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: 'claude' is not on PATH." >&2
  echo "If you use the VS Code extension, the binary is bundled inside it:" >&2
  echo '  ln -s ~/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude ~/.local/bin/claude' >&2
  exit 1
fi

echo "==> Adding marketplace"
claude plugin marketplace add "$MARKETPLACE" 2>/dev/null \
  || echo "    (already added)"

installed="$(claude plugin list 2>/dev/null || true)"

for p in "${USER_PLUGINS[@]}"; do
  if grep -q "${p}@" <<<"$installed"; then
    echo "==> $p — already installed, skipping"
  else
    echo "==> Installing $p"
    claude plugin install "${p}@claude-plugins-official"
  fi
done

cat <<'NOTE'

==> Done. Two things are NOT handled automatically:

  1. semgrep installs at PROJECT scope. Run this inside the project:
       claude plugin install semgrep@claude-plugins-official

  2. hookify rules live per-project as .claude/hookify.*.local.md.
     They come from the project repo, not from here.

Verify with:  claude plugin list
NOTE
