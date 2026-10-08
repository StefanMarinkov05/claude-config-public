# Claude Code skills — personal backup

Private backup of the hand-written parts of `~/.claude`: the skill library,
the archived skills, and global settings. Everything else in that directory
— credentials, conversation transcripts, plugin caches — is deliberately
excluded.

This repo **is** `~/.claude` on the working machine, not a copy of it. Edits
made while working are what gets pushed; there is no export step and no
second copy to drift out of date.

## Where these skills come from

This library is under active, ongoing development, built and revised from my
own research and hands-on experience running it day to day. The base was
built using Claude's deep research mode, combining its findings with
[Matt Pocock](https://github.com/mattpocock)'s public work on Claude Code
skills and workflows, then adapting the result to fit my own working style —
it is not a straight copy of either source, and it keeps changing as more of
it gets used in real projects.

## What is in here

| Path | What it is |
|---|---|
| `skills/` | The active skill library — every skill lives here |
| **`skills/README.md`** | **Index: what each skill is for. Read this instead of reading the skills** |
| `hooks/` | Shell hooks wired up from `settings.json` — these run globally, on every project |
| `settings.json` | Global preferences: model, effort, plugins, `skillOverrides`, hooks |
| `plugins.md` | Which plugins are installed and why, and which were rejected |
| `sync-skills.sh` | Push local changes to this **private** repo |
| `sync-public.sh` | Rebuild and force-push the **public** mirror (see below) |
| `restore-plugins.sh` | Reinstall the plugins on a fresh machine |

`skill-archive/` is gone as of 2026-09-15 — a two-tier active/archived split
turned out to be a trap, because **only `~/.claude/skills/` is ever scanned**.
Ten skills sat in the archive unloadable and invisible until someone noticed.
Everything now lives in `skills/` and is switched off centrally instead: see
`skillOverrides` below.

## Start here: `skills/README.md`

Loading the whole library is a large fraction of a context window spent before
any work begins: **~52,500 tokens for all 32 SKILL.md files, ~137,000 if every
reference file is read too** (measured 2026-09-16; `skills/README.md` carries
the per-skill breakdown and the command to re-measure). That index exists so
the right two or three can be chosen *from it* rather than by reading all of
them to decide.

**Everything is `"off"` by default** in `settings.json`'s `skillOverrides`,
and each project turns on only what it needs via its own
`.claude/settings.local.json`. The library is a reference to draw from, not a
bundle to load.

### Keeping a skill worth its tokens

Skills go stale in one specific way: they accumulate material that something
else now owns better. Two forcing questions, applied when a skill grows:

1. **Does a first-party source now cover this?** A Boost-enabled Laravel
   project ships Laravel's own `laravel-best-practices` (≈20 rule files,
   version-aware). Anything restated from there is worse than nothing — it
   goes stale while looking authoritative.
2. **Does a sibling skill own it?** `security-baseline`, `concurrency`,
   `database-design`, `tdd` and `website-testing` each hold a topic. A
   second, shallower copy inside a stack-specific skill is the thing to cut.

**Never pin a version in a skill.** A version table cannot be kept true, and
a stale one argues for downgrading working code — `laravel-pro` pinned
Laravel 11 while the project shipped Laravel 13. Ask the project instead
(`composer show --direct`, `package.json`).

## What is deliberately excluded

`.gitignore` denies everything by default and re-allows only the three paths
above. That shape is intentional: this directory also contains

- `.credentials.json` — live auth tokens
- `history.jsonl` — prompt history
- `projects/` — every conversation transcript, ~180 MB, covering every
  project ever worked on
- `plugins/` — third-party plugin clones, re-downloadable
- `settings.local.json` — per-machine MCP config

A permissive ignore file here leaks secrets. **Do not replace the leading
`*` rule with targeted excludes** — the whole safety model depends on
default-deny.

## Syncing

```bash
~/.claude/sync-skills.sh                    # generated commit message
~/.claude/sync-skills.sh "add returns rule" # your own message
```

The script refuses to run if any of `.credentials.json`, `history.jsonl`,
`projects/`, or `settings.local.json` has stopped being ignored, and aborts
without committing if the staged diff contains anything shaped like an API
key. It exits quietly when there is nothing to sync.

## Publishing a public copy

`claude-config-public` (github.com/StefanMarinkov05/claude-config-public) is
a **CV-free mirror**, safe to point at from a résumé, a talk, or anywhere a
stranger might clone it. It excludes `skills/cv-and-applications/` — personal
contact details and a photo — which lives only in this private repo.

```bash
~/.claude/sync-public.sh              # rebuild the mirror + force-push it
~/.claude/sync-public.sh --dry-run    # build only; inspect before pushing
```

**Not a branch, and not incremental.** A branch on a public repo is still
served to anyone — `git checkout` reaches every branch — so branching this
repo would not hide the CV data. Instead, each run builds a **fresh commit
with no parent** from whatever this repo currently tracks (respecting
`.gitignore`, same as `sync-skills.sh`), deletes the CV skill before it is
ever committed, and force-pushes it as the mirror's entire history. That
means the CV data never exists in any commit the public repo can reach —
not even an old one — which incremental syncing could not guarantee: a
CV file added and later "removed" in a follow-up commit would still sit in
the history between those two commits, recoverable by anyone.

Run it after any change to `skills/` (other than `cv-and-applications`
itself) that you want reflected publicly. Nothing pushes there
automatically.

```bash
git clone git@github.com:StefanMarinkov05/claude-config.git ~/.claude-restore
cp -r ~/.claude-restore/skills ~/.claude-restore/skill-archive ~/.claude/
cp ~/.claude-restore/settings.json ~/.claude/
```

Clone to a side directory rather than straight over `~/.claude`, which will
already exist and hold live credentials.

## Per-project use

Projects link individual skills rather than loading the whole library:

```bash
ln -s ~/.claude/skills/laravel-pro .claude/skills/laravel-pro
```

Those symlinks are per-machine and belong in the project's `.gitignore` —
they point at absolute paths that will not exist on a collaborator's
machine. `Online_Shop_TeamB` documents this split in
`docs/how-to/set-up-claude-code.md`.

## What this public mirror excludes

This is a filtered copy of a private repo. `skills/cv-and-applications/` —
personal CV/job-application material (contact details, a photo) — is
deliberately not published here, in this commit or any other. The mirror is
rebuilt from scratch and force-pushed as a single commit each time, so
excluded material never enters this repo's history at all.
