# Thinking in invariants

The habit that turns testing from "click things and see" into "name what must
always be true, then attack it." Most of the other references are techniques;
this one is how to decide **what to point them at**.

An invariant is a statement that must hold **at every moment a request could
observe the system** — not merely at the end of a happy path. Testing is the
business of finding the moment where it doesn't.

## Why this beats enumerating features

Feature-driven testing asks "does add-to-cart work?" and stops when it does.
Invariant-driven testing asks "can `reserved_quantity` ever exceed
`current_quantity`?" — and that question survives every refactor, reaches code
paths nobody listed, and produces tests that stay meaningful when the UI is
rewritten.

The practical difference: a feature test tells you the feature works today. An
invariant test tells you the *rule* holds, including through paths the author
of the test never saw.

## Finding the invariants

Four places to look, in decreasing order of how obvious they are.

### 1. The schema already states some

Every `NOT NULL`, `UNIQUE`, `CHECK`, and foreign key is an invariant somebody
already committed to. Read the migrations and list them. These are the cheapest
to test and the ones most likely to already hold, because the database enforces
them for you.

Two things worth checking anyway:
- **Does the application refuse *before* the database has to?** A `CHECK`
  producing a raw driver exception at the UI is a defect in the failure
  *shape*, even though the data stayed correct.
- **Do the application's validation rules and the column definition agree?**
  A `max:255` rule against a `varchar(100)` column is a bug that only appears
  at a specific input length.

### 2. The ones the schema *cannot* express

This is where the real bugs live. A constraint spanning two tables, or
depending on a count, or on a state machine, cannot be a `CHECK`. Examples of
the shape:

- "An available product must have at least one variation" — two tables.
- "Total redemptions must not exceed the coupon's cap" — a count against a
  limit in another row.
- "An order's status may only move along the transition matrix" — a state
  machine.
- "A shipment may not exist for a cancelled order" — cross-aggregate.

Each of these is an **application invariant**, held only by code. Every one is
a candidate for both a race (`concurrency-testing.md`) and an authorization
bypass (`security-review.md`), because nothing underneath will catch a
violation.

**Write these down explicitly.** A list of "invariants the database cannot
express" is the single highest-value testing artifact a project can have — it
is exactly the list of things that break silently.

### 3. The ones implied by domain language

Read the specification for words like *must*, *only*, *never*, *at most*,
*before*. Each is an invariant in prose:

> "A customer may view **only** their own orders."
> "Stock is released when an order is cancelled."
> "The final total is calculated on the server."

The third is interesting because it is an invariant about **what the system
must not trust**, which maps directly onto a test: can a crafted request
influence the total at all?

### 4. The ones nobody wrote down

Ask, of any piece of state: *what would make this obviously wrong to a
human?* Negative money. A quantity that isn't a whole number. An order whose
items sum to a different figure than its total. A history row that says a
transition happened that the matrix forbids.

These are usually true by accident rather than by construction — which means
they're the ones that break when the code changes.

## Turning an invariant into an attack

Once named, an invariant suggests its own tests. For each, ask five questions:

| Question | What it produces |
|---|---|
| **Who can violate it directly?** | An authorization test — can the wrong role write this? |
| **What input violates it?** | An input-abuse case (`input-abuse-techniques.md`) |
| **Can two requests violate it together?** | A concurrency test (`concurrency-testing.md`) |
| **What happens at the boundary?** | Off-by-one: exactly the cap, one over, zero, empty |
| **What if it's *already* violated?** | Does the system detect it, or render broken data? |

That last question is the one most often skipped, and it produced a real
finding: a row existing is not a promise the file behind it exists. Code that
branched on "does a record exist" rather than "is the thing it points at
usable" rendered a broken image on three surfaces. The invariant was "an image
record implies a displayable image," and nothing enforced it.

## The state-machine invariant, specifically

Any status/state column carries two separate invariants, and they need
separate tests:

1. **Legality** — is this transition in the matrix at all?
2. **Authorization** — may *this actor* make a transition that is legal?

They fail differently and must be tested separately, with a **control**:

| Case | Actor | Move | Expected |
|---|---|---|---|
| A | authorized | **illegal** move | refused by the matrix |
| B | **unauthorized** | legal move | refused by the policy |
| C | authorized | legal move | **accepted** |

C is the control, and it is what makes A and B mean anything. If all three are
refused, the refusals prove only that the call was broken.

Check the **ordering** too: legality should be decided before authorization, so
a nonsense move is refused regardless of who asks; and a self-transition no-op
should come *after* authorization, so a denied actor sees a refusal rather than
a silent success that leaks whether the move would have been legal.

## Invariants about *absence*

Some of the most valuable invariants are negative, and they need a different
technique — you cannot observe the absence of a thing by looking at a page.

- "No user-supplied value reaches the template unescaped." → grep the whole
  view layer for the raw-echo syntax; count should be zero. Then verify one
  case against **rendered output**, not source.
- "No query is built by string concatenation." → read every query path.
- "The total is never taken from the request." → confirm the component has no
  such property at all, so the framework cannot bind one. That is a stronger
  guarantee than validating it away.

That last pattern is worth internalising: **making a thing structurally
impossible beats validating against it.** A property that doesn't exist can't
be injected; a route registered outside the session middleware group can't have
CSRF accidentally re-added; a permission split into its own ability can't be
granted by someone holding the neighbouring one.

When you find such a design, test it by trying to *undo* it — that is the
deletion method (`test-quality.md`) applied to architecture.

## The invariant written twice, in opposite directions

A specific and very findable defect: one rule expressed as two different
inline conditions in two places.

```php
// in the checkout component
if ($method !== PaymentMethod::Card) { sendConfirmation(); }

// in the listener that fires when payment succeeds
if ($method === PaymentMethod::CashOnDelivery) { return; }
```

With exactly two cases these agree, every test passes, and the code reads
fine. Add a third — a deposit, a wallet, store credit — and they disagree
**silently and in opposite directions**: the negation sweeps the new method
into "confirm immediately", the equality sweeps it into "wait for payment".
Nothing fails to compile and no test covers a case that does not exist yet.

How to find it: grep for direct comparisons against enum cases
(`=== Status::`, `!== Method::`). Every hit is a rule that should probably
live on the enum. Then ask of each: *if I add a case tomorrow, does this
line still mean what its author intended?*

The fix is a method on the enum with a `match` and **no default arm**, so
adding a case is a compile-or-runtime failure rather than a silent
reclassification. Name it after the question being asked
(`concludesContractAtPlacement()`), not after the case it currently
matches (`isCashOnDelivery()`) — the latter is the same trap wearing a
method's clothes.

Watch for two genuinely different questions that happen to have the same
answer today. "Does this need an online gateway" and "is the contract
concluded at placement" coincide for card-versus-COD and diverge for a
deposit, which needs a gateway *and* concludes at placement. Collapsing
them into one flag is a bug scheduled for later.

## Invariants degrade at the edges

Three recurring places where an invariant that holds in the middle stops
holding at the boundary:

- **Empty and one.** A "sorted set" invariant is trivially true for zero and
  one elements. Most set-replacement bugs appear at two.
- **Exactly at the cap.** A partial refund taking *exactly* the remainder
  should reach the terminal state, not the partial one. A redemption at
  exactly the limit is legal; one past it is not.
- **Repeat.** The second identical request is a different case from the first.
  Is it idempotent by design, refused, or double-applied? All three are valid
  answers — but only one is intended, and it must be stated.

## Writing invariants down

In the codebase, as a docblock on the Action or model that owns the rule —
stating the invariant, why the schema cannot express it, and what enforces it
instead.

In the docs, as a per-aggregate "write rules" page: what a change does to
state that already exists, what is refused, and what happens in a race. Keep
one page per aggregate rather than one giant list, and state each outcome in
exactly one place — an outcome repeated in two documents is how the two drift.

**Mark each invariant as verified or unverified**, and mean it: verified means
a test has been observed failing when the mechanism was removed. Anything else
is an assumption with a test-shaped decoration.

## Checklist

- [ ] Schema invariants listed from the migrations
- [ ] **Invariants the schema cannot express** listed separately — the high-value set
- [ ] Domain-language *must/only/never* statements extracted from the spec
- [ ] For each: who can violate it, what input, what race, what boundary, what if already violated
- [ ] State machines tested for legality **and** authorization, with a control
- [ ] Negative invariants checked by sweep + one rendered-output confirmation
- [ ] Structural impossibilities tested by trying to undo them
- [ ] Each invariant marked verified/unverified honestly
