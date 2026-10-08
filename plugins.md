# Plugins — what is installed and why

The plugin *code* is not in this repo. `~/.claude/plugins/` is 123 MB of
third-party clones (Stripe's repo, semgrep's, Chrome's) that `claude plugin
install` re-downloads on demand. Vendoring it would bloat the repo and go
stale. This file is the manifest instead: what to reinstall, and why each
one earns its place.

Restore everything with `./restore-plugins.sh`.

## Installed

| Plugin | Scope | Why |
|---|---|---|
| `hookify` | user | Runs markdown rule files that block unwanted commands. The enforcement layer for rules that must not depend on remembering |
| `playwright` | user | Browser MCP. The only way to verify responsive layout, and to drive a real checkout through 3D Secure |
| `chrome-devtools-mcp` | user | Performance traces, network waterfall, console with source-mapped stacks. Answers *why is it slow*, where Playwright answers *does it work* |
| `semgrep` | project | SAST engine. The real value is custom rules encoding a project's own invariants, not the generic ruleset |
| `stripe` | user | Stripe's own skills and MCP. Used while building the payment slice in `Online_Shop_TeamB` |
| `session-report` | user | Local token/usage report. Currently **disabled** |

## Deliberately not installed

Evaluated and rejected. The reasoning matters more than the list, because
the same reasoning applies to the next plugin that looks appealing.

- **`commit-commands`** — automates commit messages and pushing. Conflicts
  with any project whose standard is hand-written, reviewed commit
  messages. A plugin that automates the thing a rule forbids is a liability.
- **`frontend-design`** — ~85% overlap with `frontend-distinctive-design`.
  The three genuinely additive parts (current-generation AI tells, the
  plan-then-audit gate, the CSS specificity trap) were merged into that
  skill instead. Two skills answering one question is worse than one good
  skill.
- **`code-review`, `pr-review-toolkit`, `code-simplifier`, `superpowers`,
  `mattpocock-skills`, `feature-dev`, `ralph-loop`, `remember`** — each
  duplicates a skill already in `skills/`. See `skills.md`.
- **`php-lsp`** — actively harmful under Docker when `vendor/` is a named
  volume. The LSP indexes an empty host directory and reports every
  framework class as undefined, which looks more authoritative than it is.
  Check `ls <app>/vendor/laravel/` before considering it.
- **Auth providers** (`auth0`, `workos`, `duende-skills`) — conflict with
  projects standardised on one framework-native auth library.

## Reinstalling

```bash
./restore-plugins.sh
```

Or by hand:

```bash
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install hookify@claude-plugins-official
claude plugin install playwright@claude-plugins-official
claude plugin install chrome-devtools-mcp@claude-plugins-official
claude plugin install stripe@claude-plugins-official
```

`semgrep` installs at *project* scope — run it inside the project that
needs it, not globally.

## The cross-platform trap

If every plugin reports `failed to load: cache-miss`, check
`~/.claude/plugins/known_marketplaces.json` for a Windows path
(`C:\Users\...`) on a Linux machine. Config synced between operating
systems writes absolute paths that do not resolve on the other side.

The CLI suggests removing and re-adding the marketplace. Check first —
usually the clone is fine on disk and only the recorded `installLocation`
is wrong, in which case correcting that one field fixes everything without
reinstalling. `installed_plugins.json` can carry the same corruption per
entry.
