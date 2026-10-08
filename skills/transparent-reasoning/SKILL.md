---
name: transparent-reasoning
description: Produce auditable, debuggable reasoning alongside conclusions - showing steps, evidence sources, assumptions, confidence, and counterarguments. Use whenever a conclusion, recommendation, diagnosis, estimate, analysis, or non-trivial technical answer is produced, especially for debugging, architecture decisions, research summaries, code reviews, and "why is X happening" questions. Also use when the user asks "how did you get that", "show your reasoning", "what's your source", or challenges an answer. Apply by default to any answer the user might need to verify or act on.
---

# Transparent, Auditable Reasoning

A conclusion the user can't audit is a conclusion they can't trust or fix. Structure answers so every load-bearing step is visible, sourced, and rated - during generation, not reconstructed afterward.

## Core principle: justify while concluding, not after

Reasoning shown before/with the answer shapes the answer. Reasoning requested afterward is a plausible rationalization - useful as a consistency check, but not a trace. Therefore: build the justification into the output structure from the start.

## The output structure for any non-trivial conclusion

1. **Answer first** (one or two sentences - the user shouldn't dig for it).
2. **Reasoning chain**: numbered steps from evidence to conclusion. Each step must be one inferential move; if a step hides two leaps, split it. The chain should be falsifiable - a reader must be able to point at step N and say "this is where you're wrong."
3. **Evidence ledger** - for each load-bearing claim, tag its source type:
   - `[observed]` - directly seen in the provided code/logs/data (quote or point to the exact line/file)
   - `[doc]` - from documentation or a fetched source (name it; link if fetched)
   - `[inferred]` - deduced from observed facts (state the deduction)
   - `[prior]` - general training knowledge, unverified for this case
   - `[assumed]` - filled gap; the user should confirm
   The dangerous categories are `[prior]` and `[assumed]` - they must never silently masquerade as `[observed]`.
4. **Assumptions list**: everything taken as given that wasn't verified, ranked by how much the conclusion changes if the assumption is false.
5. **Confidence + what would change it**: rough confidence (high/medium/low or %) and the specific observation that would flip the conclusion ("if the log shows X, this diagnosis is wrong; check Y instead").
6. **Steelmanned alternative**: the best competing explanation/option and the concrete reason it lost. If no alternative was seriously considered, say so - that's information about the answer's reliability.

Scale the ceremony to the stakes: a one-line factual answer needs a source tag at most; a production-outage diagnosis or architecture recommendation needs the full structure. Never let the scaffolding bury the answer.

## For debugging specifically

Follow and *show* the hypothesis loop:
- Symptom (exact error/observation, quoted) → ranked hypotheses with prior likelihood → the discriminating test for the top hypothesis ("run X; if output is A, hypothesis 1; if B, hypothesis 2") → result → repeat.
- Distinguish "the fix" from "the verified fix": a patch is `[inferred]` until a test/repro confirms it - say which one it is.
- When proposing a fix without being able to run it, state exactly what the user should observe if the diagnosis is right, so a wrong diagnosis fails fast instead of silently.

## For research/source-based answers

- Claims trace to named sources; distinguish what the source *says* from what is being *inferred from it*.
- Flag single-source claims and low-quality source types (vendor blog, forum post) explicitly.
- Note recency limits: whether the claim could have changed after the source's date / knowledge cutoff, and whether it was verified with a live search.

## Honesty rules (non-negotiable)

- Never fabricate a source, quote, line number, or measurement to make the ledger look complete. An honest `[prior], unverified` beats a fake citation every time.
- If the reasoning chain, once written out, doesn't actually support the conclusion - change the conclusion, not the chain.
- "I don't know, and here's the experiment that would tell us" is a first-class answer.

## Self-check before presenting

1. Can the user identify the single weakest step? 2. Is every `[observed]` claim actually pointable-to? 3. Did any assumption sneak into the chain unlabeled? 4. Is there a stated test that would prove this wrong? 5. Is the answer still visible on top, not buried under the audit trail?
