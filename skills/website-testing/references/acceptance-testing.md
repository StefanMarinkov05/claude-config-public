# Acceptance testing

Acceptance testing answers a different question from every other layer: not
"does it work?" but **"is it the thing that was asked for?"** A perfectly
engineered feature nobody asked for fails acceptance while passing everything
else.

**The deliverable is a traceability index, and usually no new test code.** On a
mature suite the tests that prove the contract already exist — scattered across
a hundred-plus files organised by aggregate, not by criterion. The gap is not
coverage, it is the mapping from each numbered criterion to the specific file
and case that proves it. Write that index; resist writing fresh tests to make
the table look tidy, because a test that exists only to satisfy a row proves
the row, not the system. If a criterion genuinely has no proof, that is a
finding, not a prompt to manufacture one.

## The criteria are the contract

Acceptance testing requires a written, numbered list of criteria agreed in
advance. Without one, "accepted" is a matter of opinion and the goalposts move.

Every criterion must be **binary** — met or not met, with no partial credit —
and phrased as something observable from outside the system.

| # | Criterion (verbatim) | Status | Evidence class | Proof |
|---|---|---|---|---|
| 1 | … | Met | Automated | `SomeTest.php` — `'refuses a second shipment for one order'` |
| 2 | … | Met | Confirmed live, 2026-09-11 | dated record + the regression test encoding what it found |
| 3 | … | Not met | — | what remains, not merely that it is missing |

**Status vocabulary**, kept deliberately small so it cannot be fudged:

- **Met** — satisfied and verified, with the evidence linked.
- **Not met** — a known gap, with work outstanding.
- **Open** — no decision has been made yet.
- **Pending** — nothing built that could satisfy or violate it.

"Mostly met" is not a status. If it is tempting, the criterion is two criteria.

## Evidence, not assertion

Each **Met** needs evidence a third party can check without re-running the
work: a test name, a screenshot, a dated record, a command with its output.

"Verified manually" is not evidence — it is a claim that someone once looked.

Cite it precisely enough to be checked first-hand: **file plus representative
case name**, so the reader can run the filter and confirm, rather than trusting
the table. A criterion citing a whole directory cites nothing.

### Name the *class* of evidence, don't blur it into one column

Not all Met rows are equal, and a table that presents them identically
overclaims automation. Mark which kind each row is:

- **Automated** — a currently-running case in the suite. The default, and the
  only kind that re-proves itself on every run.
- **Structural** — true by construction and enforced by the compiler or static
  analysis (an implementation that could not compile against the wrong
  interface). Real proof, but it fails at build time, not as a test.
- **Confirmed live, dated** — a one-time verification against a real external
  system, recorded with its date and what it found. Legitimate where the
  automated suite deliberately mocks that dependency: a third party's uptime is
  not yours to guarantee on every CI run. **Pair it with the regression test
  that encodes what the live run taught** — the live check found three field
  names a mock could never have caught; the mocked test now pins them.
- **Documented, not automated** — an honest statement that the strongest
  evidence is a written record. Say so in the row, not in a footnote.

The rule underneath: a live check and a mocked test prove *different* things,
and neither substitutes for the other. State which you have, and re-verify a
live claim when the code it touched changes.

## The traps

**A criterion satisfied by the demo but not the product.** Seeded showcase data
can make a feature appear to work. Verify against data the criterion's own
wording implies, not the data that was arranged to demonstrate it.

**A criterion whose wording is looser than its intent.** "An administrator can
manage products" is satisfied by a create form. It says nothing about *bad*
products — which is where the real behaviour lives. Where the wording is loose,
record both the literal reading (which is what is graded) and the honest one
(which is what matters), and do not quietly substitute one for the other.

**A criterion nobody can fail.** If no realistic implementation could violate
it, it is not testing anything. Note it and move on rather than manufacturing
ceremony.

**Acceptance drift.** Criteria written before the work often use vocabulary the
finished system does not. Map old wording to current names explicitly rather
than reinterpreting silently — and if a criterion has genuinely become
meaningless, say so in writing rather than marking it Met.

**Implementation standards are a separate axis.** Constraints on *how* the
thing is built (one formatter, no debug statements, validation server-side,
no secrets committed) are a state the repository is in at any moment, not a
feature that ships. Track them in their own table, and re-check them near the
end — they go stale silently as the codebase grows.

## Relationship to the other layers

Acceptance testing does not replace them; it consumes their output.

- A criterion about behaviour cites a **system test**.
- A criterion about authorization cites the **role matrix**
  (`security-review.md`).
- A criterion about "works on mobile" cites a **device-emulated pass**, not a
  resized window (`ui-testing-mcp.md`).
- A criterion about automated coverage cites the **suite** — and the honest
  statement of what it does not cover.

Where a criterion cannot cite anything, it is not Met.

## Method

1. Extract the criteria verbatim into a table. Do not paraphrase.
2. For each, state what evidence *would* satisfy it, before looking at whether
   it exists. Deciding the bar after seeing the result is how everything
   becomes Met.
3. Gather evidence; mark status.
4. For each Not met, record what remains, not merely that it is missing.
5. Date the table. Acceptance is a claim about one moment.

## Checklist

- [ ] Criteria extracted verbatim, numbered, binary
- [ ] Evidence bar decided before evidence gathered
- [ ] Every Met linked to checkable evidence — file **plus case name**
- [ ] Evidence *class* named per row (automated / structural / confirmed-live / documented), never blurred into one column
- [ ] Every confirmed-live row dated, and paired with the regression test encoding what it found
- [ ] No test written solely to fill a row
- [ ] Loose wording recorded both literally and honestly
- [ ] Implementation standards tracked separately and re-checked late
- [ ] Table dated
