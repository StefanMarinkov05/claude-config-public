# Documenting a testing pass

A finding that is not written down will be rediscovered. A pass that is not
dated is a claim about nothing in particular. This file is how to record what
was done so that a reader can judge the coverage rather than take a summary on
trust.

## The three document types, and how to tell them apart

Mixing these is the most common documentation failure, because each answers a
different question and a reader arrives with only one of them.

| Type | Answers | Shape | Goes stale? |
|---|---|---|---|
| **Procedure** (how-to) | "How do I run this?" | Commands, configuration, traps | Slowly |
| **Record** (reference) | "What was found on date X?" | Findings, evidence, gaps | Never — it's dated |
| **Inventory** (reference) | "What is configured, and what did it reach?" | Tables of measured numbers | With the config |

A record is **not** updated when the code changes. It is a claim about the code
as it stood on one date. Write a new record instead; leave the old one alone.

## Every pass carries a date and a scope

Open with them. Without both, nothing below can be evaluated:

> **Date of record:** 2026-09-04. Driven against the running Docker stack with
> the Playwright MCP, guest session, demo catalogue seeded (171 products, 24
> articles, 2 orders).

State the *environment*, the *data*, and the *tooling*. A finding against an
empty database and one against a seeded catalogue are different findings.

## When to screenshot

Screenshots are expensive to produce, review, and store. Take one when the
**visual state is the evidence** and prose would be a claim rather than a
proof.

**Screenshot:**
- A rendered defect — a broken image, a mislaid layout, a leaked stack trace.
- An authorization result a reader would otherwise take on trust: the 403 page
  itself, the sidebar showing exactly three resources.
- A before/after pair for a visual fix. Name them `-BEFORE-fix` / `-AFTER-fix`
  so the pair is obvious in a directory listing.
- A UI state that is hard to describe precisely (a filter panel's full set of
  controls, a variant picker's disabled combinations).

**Do not screenshot:**
- A status code. `curl -o /dev/null -w "%{http_code}"` is better evidence,
  because it is text a reader can re-run.
- Anything whose proof is a number, a count, or a database row.
- A passing test run. Paste the summary line.
- "The page loaded." That is not a finding.

**Rules for the ones you take:**
- Put them in a dedicated assets directory, not loose beside the document.
- Give every image alt text that states **the claim it proves**, not what it
  depicts. `![403 Forbidden for content_editor at /admin/users]` beats
  `![screenshot]`.
- Place the image immediately after the sentence it evidences.
- Never crop away the URL bar or the status when those are the point.

## When to use bug-bounty format

Use it for anything that is a **defect with a security or correctness
consequence** — not for a note, a gap, or a preference. One finding, one entry,
with a stable ID (`SEC-001`, `PERF-003`) that other documents can cite.

The required sections, in order:

```
### SEC-008 — Short imperative title naming the actual problem

**Severity:** Low–Medium (latent — requires X first) · **Type:** Privilege
escalation / broken function-level authorization

**Status:** Open | Fixed (confirmed by exploitation, then by regression test)

**Finding.** What is wrong, in plain terms, from the attacker's side. What can
someone do that they should not be able to do?

**Reason (root cause).** Why the code permits it. Quote the offending lines.
If a docblock already names the danger without acting on it, quote that — it is
the strongest possible evidence the gap was known.

**Reproduction.** Exact, runnable, and *safe*. Prefer a rolled-back
transaction over anything that mutates state. Paste the real output.

**Fix.** What closes it. If not applied, say so and say why — "this changes
what an administrator may do to their own role, which is a policy decision, not
only a security patch" is a legitimate reason to stop and ask.

**Logic for future pentests.** The generalisation. What *class* of bug is this,
and where else would it appear? This is the section that pays for the entry.
```

### Severity, honestly

Do not inflate. A latent issue requiring an administrator mistake is not
"Critical". State the precondition in the severity line itself:

> **Severity:** Low–Medium (latent — requires an administrator to grant the
> permission first; not exploitable on `main` today)

And prove the "not exploitable today" claim rather than asserting it — a query
showing no role holds the permission is evidence; "I believe nobody has it" is
not.

## Recording a negative result

**A pass that found nothing is worth documenting**, and is frequently more
useful than one that found something — it tells the next person not to re-run
it. Give it the same weight:

> ### SEC-005 — Full active scan: no injection vulnerability found
> **Severity:** n/a — this records a *negative* result · **Status:** Complete

State what was attacked, with what, how thoroughly, and why the negative is
credible. A negative from a tool that never reached the app is worthless, so
include the coverage numbers that make it meaningful.

## The "what did not hold" section

Every record needs one, even when the answer is "nothing." Put it *after* what
held, and be specific about the difference between:

- **Confirmed** — reproduced live, with the output pasted.
- **Inferred** — the schema/code says so, but it was not run. Say which.
- **Unproven** — structurally identical to a confirmed case, but the data to
  test it does not exist. Name what is missing.

Claiming five confirmations when four were confirmed and one was inferred is
the failure this distinction prevents.

## The "not covered" section is mandatory

This is the section that makes the rest trustworthy, and the one most often
omitted because it reads as an admission of failure. It is the opposite: a
record without stated limits is a record whose limits are unknown.

List, specifically:
- What surface was not reached, and why.
- What tooling was not run, and the reasoning (deliberate omission vs. no time).
- What role/browser/device/data state was not exercised.
- What the *next* pass should start with.

Vague is useless. "Some admin pages not tested" tells nobody anything;
"the scan's session expired after 44 admin paths and 4,550 later requests were
redirected to login" is actionable.

## Measured numbers, not adjectives

Every coverage claim should be a number taken from tool output or server logs,
labelled as a limit where it is one:

| | Default parallelism | `threadPerHost: 2` |
|---|---|---|
| `/admin/*` → `200` (authenticated) | 92 | **587** |
| `/admin/*` → `302` (session lost) | 4,550 | **3** |

That table proves a configuration change mattered. "Improved scan coverage"
proves nothing and cannot be re-checked.

## Recording a method failure

**When a probe produces a false result, document the false result and how it
was caught.** This is not self-flagellation; it is the highest-value content in
a testing document, because the same trap will be walked into again.

The shape:

> **A false result caught mid-pass, recorded because it is the trap this kind
> of sweep invites.** The first run reported all five values "refused", which
> read as a clean pass. They were refused — on a missing `sku`, because the
> probe's payload used the wrong key shape, so the column under test was never
> reached. The control row is what exposed it.

Then state the rule that prevents recurrence, and apply it retroactively to
the rest of the document.

## Writing style

- **Dry and factual.** No marketing tone. No "successfully verified" — either
  it held or it did not.
- **Record why, not just what.** An entry saying what was fixed without why it
  recurs is half an entry.
- **No instructions to the reader** in a reference or explanation document.
  "You should check X" belongs in a how-to; a reference states what is true.
- **Quote the code.** A docblock that names a danger, or a comment that
  contradicts the code beneath it, is evidence — paste it.
- **Link, do not duplicate.** State each outcome in exactly one document.
  Repeating it in two is how the two drift apart.

## Where a finding goes

| Finding | Document |
|---|---|
| A security defect | The dated security record, bug-bounty format |
| A behaviour defect found while testing | The changelog's gaps section + the relevant record |
| A recurring error with a non-obvious cause | The troubleshooting guide — symptom, cause, fix, **why it recurs**, prevention |
| A tool's configuration and reach | The tooling inventory |
| What a UI pass clicked | A dated per-pass record, one file per pass, not one growing file |

**One file per pass, not one growing file.** A record that is appended to
forever loses its date, and a reader cannot tell which claims are current.

## Checklist

- [ ] Date and environment stated at the top
- [ ] Findings in bug-bounty format with stable IDs
- [ ] Severity honest, with preconditions stated
- [ ] Confirmed / inferred / unproven distinguished
- [ ] Negative results recorded with their coverage numbers
- [ ] Screenshots only where visual state is the evidence, alt text states the claim
- [ ] "Not covered" section present and specific
- [ ] Any false result during the pass documented, with the rule it produced
- [ ] Each outcome stated in exactly one place
