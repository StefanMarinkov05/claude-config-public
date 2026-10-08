---
name: interview-handbook
description: Build a personalised interview-preparation handbook (LaTeX → linked PDF) for a specific job ad - job analysis, analysis of the candidate's own GitHub projects (strengths with links, ranked gaps), teaching chapters for the gaps, coding problems, model answers, STAR stories and verified study resources. Use whenever Stefan says he has an interview, pastes a job ad and wants preparation, says "new interview", or asks to extend/fix an existing handbook in the interview-prep repo.
---

# Interview handbook

One handbook per interview, in Stefan's `interview-prep` repo. The repo already contains everything
reusable; **this skill is the process, the repo is the code.** Never rebuild the LaTeX setup from
memory: copy it.

## Repo map (relative to the repo root)

| Path | Role |
|---|---|
| `CLAUDE.md` | Personal facts, identity, standing preferences. **Read first.** |
| `profile/project-analysis.md`, `profile/stories.md` | Reusable evidence about Stefan's projects + STAR stories. Start from these, re-verify, update |
| `_template/` | Skeleton copied per interview (handbook LaTeX with all boxes + link system, job-ad.md, notes.md, application/) |
| `companies/YYYY-MM-company/` | One folder per interview. `companies/2026-10-nokat/` is the complete reference example (123 pages) |
| `scripts/new-interview.sh <slug> "Name" [YYYY-MM]` | Scaffold a new interview folder from the template |
| `scripts/build.sh <folder>` | Build Handbook.pdf + Handbook-2.pdf + Handbook-same-tab.pdf and run the link audit |
| `scripts/verify-links.py`, `scripts/open-handbook.sh` | Link audit; open at 150% zoom |
| `plan/decisions.md` | Why the repo is structured this way |

## Process

1. **Scaffold.** `scripts/new-interview.sh <slug> "Display Name"`. Save the job ad verbatim in
   `job-ad.md`. Postings disappear.
2. **Job analysis.** Product (one diagram), responsibilities → concrete tasks, requirements checklist,
   likely stack **marked as inferred** ("what I would propose / ask them").
3. **Candidate analysis.** Start from `profile/project-analysis.md`; re-check GitHub
   (`gh repo list ...`, shallow clones into the session scratchpad, read-only) for new repos/changes
   and update the profile file. Credit only Stefan's own parts of team projects (ADR `Deciders:`,
   CONTRIBUTIONS tables). **Verify every claim against the files**; quote nothing from memory.
4. **Plan chapters** around the gaps (see `references/content-standards.md`). Inserted chapters use
   `\bchapterinput{N}{file}` (numbers like 1b) so chapter references never shift. Topics Stefan has
   already demonstrated go into `optional` blocks with a link to the evidence; gaps are required reading.
5. **Write.** Boxes, diagrams, runnable code, model answers, `yourwork` boxes linking his repos.
   English only.
6. **Resources.** Verified links, `[must]/[recommended]/[optional]`, a day-by-day plan.
7. **Build and verify.** `scripts/build.sh <folder>`, then the full protocol in
   `references/verification.md` (link audit, executed code, visual review, a real click test opened
   the way Stefan opens files). Report what was **not** verified.
8. **Report.** Path to `Handbook.pdf`, page count, chapter list, top gaps + reading order, what was
   verified (numbers), what wasn't, next steps. Commits happen automatically (Stop hook).

## Load a reference only when needed

- `references/link-system.md`: how chapter/contents/back-trail links work and why (two cross-linked
  copies, absolute file:// URIs, `?r=`, `#page=…&zoom=150`). Read before touching any link macro.
- `references/latex-pitfalls.md`: Tectonic setup and every error already hit, with fixes.
- `references/verification.md`: the verification protocol, including the real-click test.
- `references/content-standards.md`: chapter structure, box semantics, writing and resource rules.

## Hard rules

- No AI-attribution trailers in commits (a global hook blocks them).
- Interview folders only under `companies/`; output names are always `Handbook.pdf`,
  `Handbook-2.pdf`, `Handbook-same-tab.pdf`.
- The LaTeX link macros hardcode the handbook's absolute path: after moving a folder, update
  `\pdfselfname` in its `main.tex` and rebuild (`verify-links.py` flags stale paths).
- Don't edit an old company's handbook to "improve" it unless asked; improve `_template/` instead.
