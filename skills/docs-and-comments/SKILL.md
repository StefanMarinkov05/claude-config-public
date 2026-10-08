---
name: docs-and-comments
description: Standards for code comments and project documentation written for learning and teaching. Use whenever writing code that should carry explanatory comments, creating READMEs, API docs, architecture docs, runbooks, or tutorials, or when the user asks to "document this", "add comments", "explain the code", or wants a codebase understandable for students/juniors/future maintainers. Apply automatically to all substantial code produced in learning-oriented projects.
---

# Documentation & Teaching Comments

Documentation is the interface to the humans. In learning-oriented codebases, comments teach the *reasoning*; docs teach the *system*. Both rot unless kept next to what they describe and reviewed with it.

## Two readers, failing differently

Everything written is read by people and by agents, and **they fail differently. A person who cannot find a document asks someone. An agent that cannot find a document proceeds without it — confidently, and with a plausible answer built on a wrong premise.**

Three consequences:

- **Reachable beats merely available.** Knowledge has to be linked from the place where it is needed — a router file the agent always reads, a pointer in the relevant module — not merely present somewhere in the tree. An agent arrives by a named path, not by browsing.
- **Filing errors cost little; missing links cost a lot.** A document in a slightly wrong category is fine if something links to it. An unlinked document effectively does not exist.
- **Anything not yet built says so at the top.** Documentation describing intentions in the present tense is *worse than none*, because it cannot be distinguished from documentation that is merely out of date. Mark status explicitly ("built and running" vs "installed, not wired in") and the reader keeps the ability to tell drift from plan.

**If the project has its own documentation-design doc** (an `explanation/documentation-design.md`, a `docs/README.md` section on structure, a CONTRIBUTING doc on doc conventions), that doc is authoritative for this project — read it first and defer to it wherever it conflicts with anything below. This skill fills the gaps it leaves, not the other way around.

## Comments: what to write

The code says *what*; comments earn their place by saying **why, why-not, and watch-out**:

- **Why**: the reason this approach was chosen. `// Keyset pagination instead of OFFSET: page 10,000 would scan-and-discard 200k rows.`
- **Why not**: the tempting alternative and why it loses. `// Not a Set: we need insertion order for the replay log.`
- **Watch out**: invariants, units, ranges, non-obvious contracts. `// amountMinor is in cents; callers must never pass floats.`
- **External context**: links to the spec, RFC, issue, or paper implemented. `// Implements RFC 6455 §5.2 frame parsing.`
- **Teaching notes** (learning codebases): brief explanations of the technique itself at first use - what an idea is and why it exists, one short paragraph, once, at the clearest example: `// Circuit breaker: after N consecutive failures we stop calling the`
  `// dependency for a cooldown window, converting slow failures into fast`
  `// ones so threads don't pile up waiting on a dead service.`

**Never write**: comments restating the line (`i++ // increment i`), change history (git owns that), commented-out code (delete it; git remembers), or lies - an outdated comment is worse than none, so comments are reviewed in every PR touching their code.

**Structure of a well-commented unit**: a block comment at the top of each non-trivial function/module answering *what role does this play in the system and what must callers know*, then inline comments only at the genuinely non-obvious lines. Give the block comments in one family a **fixed closing shape** so the same class of fact is present or explicitly absent everywhere - e.g. every Action ending with what it authorizes, what it locks, and where the reasoning lives. Without one, each file documents whatever seemed notable the day it was written, and a reader cannot tell "takes no lock" from "nobody mentioned the lock". State the "nothing" explicitly: silence reads as an oversight, and the next person adds a lock that was never needed. If a function needs a comment every 3 lines, refactor for clarity first - comments are not makeup for confusing code.

**Doc-comments** (docstrings/JSDoc/XML docs) on every public API: one-line summary in the imperative, params with units/ranges, return shape, exceptions/error cases, and one minimal usage example. Examples in doc-comments are the most-read documentation you'll ever write - keep them copy-paste runnable.

## The shape: a claim, then a pointer

Two audiences read every comment and they want the same thing. A developer is deciding whether it is safe to change this line. An LLM is deciding the same with a fixed context budget, and a paragraph it must read to discover it was irrelevant is spent budget with nothing bought.

So write **the claim inline, the argument in the doc**:

```php
// Child before parent: the reverse is error 1451.
// reference/product-write-rules.md
```

The first line is self-sufficient — a reader who stops there still knows not to reorder. The second is for a reader who needs the reasoning, and costs one line rather than fifteen. Never invert this: `// See ADR-0008` alone forces a context-switch just to learn whether it was relevant.

**Reference a doc when the reasoning is longer than the claim**, and always for: a decision an ADR governs, a rule that spans files, an invariant with a worked example, and anything a reader might be tempted to "simplify". Use a stable path (`explanation/x.md`, `ADR-0008`), never a line number, and never another source file — see the doc-not-code rule below.

**Budget.** A class or function docblock earns roughly five lines; an inline comment one or two. Past that, ask what moved to a doc. Comment density above about a third of a file is a smell worth auditing — not a limit, but at that ratio some of it is convention or restatement.

**The test for every line: would a competent reader have been slower, or wrong, without it?** Not "is it true" and not "is it interesting". If they knew it already, it is a tax charged on every future read, and its real cost is diluting the comments that matter.

## Where rationale lives: code or docs

Both can hold a *why*, and putting the same why in both is how they drift apart. One test decides: **would deleting this comment make a future change more likely to be wrong?** Yes → code. No → docs.

- **Local why-this-line stays in code.** Anything that looks like an oversight until you know the constraint - a deliberate-looking-wrong branch, an external system's quirk, a value that must not be "cleaned up". Nobody reads `docs/` before editing one line of a match/switch block.
- **Comparative claims go to docs.** "Stricter than X", "unlike Y", "we do this everywhere except Z" - these span files and rot silently the moment the other file changes. One canonical place, and for a decision that place is an ADR.
- **Explaining an absence usually goes nowhere.** A comment on every file that *lacks* a feature, saying the lack is deliberate, trains readers to skim past comments. Record which cases are excluded, once, in the decision doc.
- **A comment that only restates the code goes nowhere** - but check what it's really doing first: "grouped by effect on stock rather than by type" looks like restatement and isn't, because it tells the next person which group a *new* case joins.

- **Point at a doc, not at another source file.** "See OtherClassTest" makes the reader open a file, find the passage, and judge whether it still applies — and it rots silently when that file is renamed or rewritten. A doc has a stable name, a heading to land on, and one owner. Reserve code-to-code references for genuine *composition* ("delegated to X, which owns the ledger refusal"), where the relationship is the thing being described. The tell that a doc is missing: the same explanation appears in three files, and the third one says "same as the first".
- **A convention goes in a doc, once, never at each site that follows it.** If the rule holds everywhere, repeating it at every occurrence teaches readers that comments restate policy and trains them to skim. "Authorization is checked before domain validation" is a convention: state it in the how-to, and let the code show the order by having it. The exception is a site that *departs* from the convention - that one gets a comment, because there the code no longer shows the rule.

### The one test that settles most cases

**Without this written down, would the next competent reader plausibly do it differently?** Only "yes" earns the words. Three corollaries worth stating because they get missed:

- **Record decisions, not defaults.** A pattern earns documentation only when it reflects a *choice*: the project took one valid option where the framework or common practice offered others. A framework default steers nobody — it is what the reader would write unprompted, so writing it down buys nothing and costs a maintenance obligation.
- **Skip what a tool already enforces; keep what a tool would fight.** If the formatter, linter or a Rector-class rewriter produces the form automatically, documenting it is a no-op. The high-value case is the inverse: code that deliberately *holds* a shape a tool would refactor away. No tool can reproduce that choice, and the next agent defaults the other way — so that against-the-grain hold is exactly what to write down.
- **A consistent deliberate absence is a convention.** "No repository layer — controllers query Eloquent directly" documents the project's *altitude* and stops the next contributor from over-engineering. Silence reads as an oversight; state the nothing explicitly.

Where a project's documented convention and this skill disagree, the project wins (see the note at the top) — and if the code is genuinely mixed, describe the split rather than recording the style you wish had won. Documenting an aspiration as though it were the convention is how a doc starts lying.

**What fails the bar**, in rough order of how often it appears:

- Restating a language or framework convention the reader already brings (`fill()` ignores non-fillable keys; a docblock explaining why a type annotation sits above the line it annotates).
- Re-deriving something the linked doc already argues. Keep the *warning*, link the derivation: `// increment(), never read-modify-write: if the lock is lost this writes a value the CHECK rejects rather than a plausible one. See explanation/concurrency-and-locking.md.`
- Design rationale at a call site. Why the class is shaped this way belongs in its docblock; the call site needs only what breaks if the line moves.
- The same fact in a docblock and again inline twenty lines down. One of the two is in the wrong place - and the inline copy is the one that survives an edit while the docblock silently becomes a lie.

Passes the bar - keep these even when they look chatty, because the *obvious* edit breaks them:

- Ordering that looks arbitrary and is not: `// Child before parent. The reverse is error 1451.`
- A query modifier whose removal changes results silently: `// withTrashed(): the scope would hide exactly the rows that cause 1451.`
- An off-by-one that reads like a mistake: `// Count the *others*, not all-minus-one.`
- A weaker call chosen deliberately: `// first() rather than firstOrFail(), so the missing case is answered deliberately.`

**Audit for overlap separately from volume.** Trimming long comments and removing duplicated ones are different edits; doing only the first leaves the duplication behind.

**Referencing a decision from the code it governs.** When an ADR constrains a specific construct, point at it from that construct - and phrase it as an instruction, not a citation: `// Governed by ADR-0004 - read it before widening or narrowing this table.` ADR numbers are stable (a superseded ADR keeps its number and gains a `Superseded by` line), so the pointer never dangles. Put it on the code that gets edited, not on every file in the neighbourhood. The pointer supplements the local why; it never replaces it, because "see ADR-0004" alone forces a context-switch just to learn whether it was relevant.

## Project documentation set

Keep docs in-repo (`README.md` + `docs/`), versioned with the code. These are the standard **jobs** a healthy doc set covers, not fixed filenames — a project may name or group its files differently (an `explanation/` folder instead of a single `architecture.md`, troubleshooting split by area instead of one runbook). Map new content to the job it does; don't rename a project's existing files to match this list.

- **Front door** (usually `README.md`) - what this is (2 sentences), who it's for, quickstart that works on a clean machine in <5 minutes (this is the most important doc in the repo - test it on a clean clone), links to the rest.
- **System-on-one-page** (often `docs/architecture.md`, or an `explanation/` overview) - a diagram (Mermaid or equivalent, lives in the repo, diffable), the main components and their responsibilities, how one representative request flows end to end, and the key invariants. Write it for the new team member on day 2 - or, if there is no day-2 reader, for the agent that needs orientation before its first change (see "The four kinds of docs" below on when a full tutorial path is warranted instead).
- **ADRs** (`docs/adr/`) - one file per significant decision: context, decision, alternatives, consequences (see engineering-reasoning skill). ADRs are append-only history; supersede, don't edit.
- **API reference** - generated from doc-comments/OpenAPI where possible (generated docs can't drift), hand-written guides only for the concepts generation can't cover.
- **Operational knowledge** (often `docs/runbook.md`, or split by symptom/area) - how to deploy, roll back, read the dashboards, and a section per known failure mode with symptoms → diagnosis → fix. Written for someone paged at 3am who has never seen this service.
- **Contributing/setup** - environment setup, test running, conventions, PR process.

## The four kinds of docs (Diátaxis) - don't mix them

Diátaxis splits on two axes: whether the reader is *studying* or *working*, and whether they need *practical steps* or *theory*.

| | Practical | Theoretical |
|---|---|---|
| **Studying** | Tutorial | Explanation |
| **Working** | How-to | Reference |

- **Tutorial**: a newcomer with no goal of their own yet, learning by doing - a guaranteed-success guided path, followed in order, assumes nothing. The reader arrives once and reads start to end; the value comes from the sequence, not any one step in isolation.
- **How-to guide**: a recipe for a specific task, for someone who knows the basics ("how to add a new endpoint").
- **Reference**: complete, accurate lookup material; structured like the code, no narrative.
- **Explanation**: background and reasoning ("why we chose event sourcing"); deepens understanding, no steps.

**One document does one job.** Most bad docs mix these (a reference page that tries to teach; a tutorial that digresses into theory; a how-to that argues rationale instead of linking to it). Decide which one you're writing before writing.

**An empty quadrant is a legitimate state, not a gap to fill.** Diátaxis is explicit about this: "it certainly does not mean that you should create empty structures for tutorials/howto guides/reference/explanation with nothing in them. Don't do that. It's horrible." Never scaffold all four categories on a new project by default - populate a category when content that actually belongs to it exists, and record the omission in the project's own documentation-design doc if one exists.

**Tutorials specifically are worth a harder look before writing one**, for two reasons beyond the general "don't create empty structures" rule:

- Its maintenance cost is the highest of the four - Diátaxis notes that a change "cascades through the entire story," unlike a reference table or an explanation page where an edit stays local.
- Its mechanism (a reader following a chosen sequence to build confidence) assumes a reader who doesn't yet exist on many projects: a small team where everyone already knows the system has no newcomer to guide, and an AI agent reader retrieves the chunk matching its current task rather than reading a narrative start to end - narrative sequencing is wasted on it, or actively worse than a fact-dense reference page. Confirm a reader who actually needs guided sequential practice exists before building a tutorials/ folder; if the real need is agent orientation, that's better served by a short router doc (what the system is, what to read next) than by a tutorial.

## Writing rules

- Lead with the point; details after. Readers scan.
- Short sentences, active voice, concrete examples over abstractions - every claim about behavior gets a code snippet or command the reader can run.
- Define each term once at first use; consistent vocabulary thereafter (one name per concept - not "user/account/customer" interchangeably).
- State prerequisites and versions explicitly; docs that fail silently on version drift destroy trust.
- Every doc gets an owner and a "last verified" date; stale docs are deleted or fixed, never left to lie.

## Definition of done for any feature

Code + tests + doc-comments on public surface + README/architecture/runbook updated if the feature changed setup, flow, or ops. Documentation debt is tracked like tech debt - visibly.
