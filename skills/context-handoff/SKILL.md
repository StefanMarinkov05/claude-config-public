---
name: context-handoff
description: Managing context and state across agent handoffs, long sessions, and context-window limits - state files as shared memory, handoff document format, summarization discipline, and session-restart recovery. Use whenever work spans multiple agents or sessions, a context limit is approaching, an agent needs to resume someone else's work, or output quality degrades in long conversations. Trigger for "continue from where we left off", "hand this to another agent", pipeline handoffs, or planning any task too big for one session.
---

# Context Handoff & State Management

An agent's context window is RAM, not a database. Anything that must survive the session lives on disk in a structured form. Design every long task as if the process could be killed and restarted at any point - because it will be.

## The core rule: externalize state continuously

Don't wait for the handoff moment (by then the context may be degraded or truncated). Agents update state files **as they work**:

- `plan/tasks/NNN-name.md` - per-task: status (todo/in-progress/blocked/review/done), what's done, what remains, blockers
- `plan/interfaces.md` - frozen contracts (the one file every agent always reads)
- `plan/decisions.md` - append-only judgment-call log: date, decision, why, alternatives rejected
- `plan/state.md` - the "if I die, start here" file: current milestone, next 3 actions, environment quirks discovered (commands that work, ports, credentials locations - not values)

Git commits are state too: small, frequent, message = *why*. A resumable pipeline is one where `git log` + `plan/` reconstructs everything.

## Handoff document format

When passing work between agents (or to future-you), the handoff contains exactly six sections - nothing narrative:

1. **Goal** - the task's contract and done-criteria (copy, don't paraphrase - paraphrase is where requirements mutate)
2. **State** - what is done and *verified* vs done-but-unverified vs not started
3. **Decisions made** - with one-line rationales (or pointer to decisions.md entries)
4. **Assumptions & open questions** - explicitly labeled; the receiver's first job is confirming these
5. **Gotchas** - environment/codebase surprises that cost time (the highest-value section; this is the knowledge that otherwise gets re-derived at full price)
6. **Next actions** - the first 1-3 concrete steps, so the receiver starts moving instead of re-planning

Receiving agent protocol: read handoff → read interfaces.md → **verify the "done" claims** (run the tests) before building on them. Trusting an unverified handoff compounds errors across the pipeline.

## Summarization discipline

Compression loses information; control *what* gets lost:
- Never summarize contracts, invariants, or done-criteria - copy them verbatim. Summarize narratives (what was tried and failed) instead.
- Preserve exact identifiers: file paths, function names, error messages, versions. "The config file" becomes unfindable; `src/config/loader.ts:47` doesn't.
- Summaries state their own scope: "covers auth work only; DB work not started."
- When compressing a long conversation, write the summary to disk *before* context runs out - a summary you can't produce anymore is the failure mode.

## Context budget hygiene (within a session)

- Front-load only what's needed for the current task; pull references (skills, docs, files) on demand rather than pasting everything up front.
- Long tool outputs: extract the relevant lines into notes, don't re-read the full log repeatedly.
- Signs of degradation - repeating earlier mistakes, forgetting established decisions, contradicting interfaces.md: stop, write state.md, restart the session fresh. A fresh session with good state files outperforms a bloated one every time.
- Rule of thumb: restart at natural milestones rather than at the hard limit; you choose what survives instead of the truncation choosing.

## Anti-patterns

- Handoff = "read the whole previous conversation" (unreadable, and full of dead ends presented as equally important)
- State only in chat memory (one truncation from oblivion)
- "Done" claims without evidence in the handoff
- Paraphrased requirements drifting one synonym per hop until the built thing matches nobody's request
- One giant HANDOFF.md that mixes contract, log, and gotchas - use the file structure above so receivers read only what they need
