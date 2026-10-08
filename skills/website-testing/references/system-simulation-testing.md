# System simulation testing — driving the full business lifecycle through real methods

A layer above `automated-testing.md`'s feature tests and below a manual
`ui-testing-mcp.md` pass: a **scripted, repeatable run of the entire business
lifecycle**, from an empty data layer to a fully populated one, using only
the application's own real write paths — no direct database inserts for
anything the application itself has a method to create. The output is not
just "tests passed" but a database that now contains one real instance of
every state the business logic can reach, produced the way a real user or
a real event would produce it.

This walk is usually driven at the **Action/service layer** — fast,
deterministic. Driving the same walk through a **real browser**, every
customer-facing step a real click, is `automated-browser-testing.md`'s
"System-simulation E2E" spec: slower, but it also proves the JS, the forms,
and the rendering, and it carries the modal-hang and one-session-per-journey
traps.

## Why this is a distinct layer, not "more integration tests"

An integration test proves one Action does what it claims, in isolation,
with hand-built fixtures. It does not prove that the sequence a real user
actually walks — browse, cart, checkout, pay, get shipped, return, refund —
produces a database that looks the way that sequence should leave it,
because no single test spans the whole sequence and nothing checks that the
state left behind by step 3 is what step 4 actually needed.

**A system simulation is the thing that would have caught**: a coupon
redemption count that's correct after one redemption but wrong after two
redeemed by different users in sequence; a webhook's cumulative-vs-delta
handling that's correct for one refund and wrong for a second; a status
transition that's legal in isolation but never reachable through the actual
UI because nothing links to it. Each of those needs *state accumulated
through real prior steps*, not a fixture asserting the end state directly.

## The one hard rule: no side doors

**Every row created during the simulation goes through the same method a
real caller would use** — the same Action, the same webhook handler, the
same console command — never a direct model `create()` standing in for a
step the business logic itself should have performed.

This is not a purity rule for its own sake. A fixture that inserts an
"already paid" order directly has skipped every invariant the payment
Action enforces — the row *looks* like a paid order and has never actually
proven that paying an order produces one. The entire value of this layer
comes from refusing that shortcut, even though it's slower and even though
it means the simulation script depends on every layer beneath it also
being correct (which is itself useful — a system simulation failing because
an unrelated lower layer broke is exactly the coverage a unit test at that
lower layer would have missed if the *composition* was the bug).

**The one narrow exception**: seeding data that has no real-world creation
event at all — a product catalogue that exists because a company's
inventory already existed before the software did, an initial chart of
accounts. Draw that line explicitly and narrowly per project; if in doubt,
find the real Action first before falling back to a direct insert.

## Structuring the walk

### Enumerate every terminal and intermediate state first

Before writing the simulation, list every state each entity's lifecycle can
reach — the full transition graph, not just the happy-path terminal state.
For an order-like entity this typically includes: created but unpaid,
paid, in each fulfillment stage, delivered, a customer-initiated return
at each of its own stages, an admin-initiated cancellation, a payment
dispute, a partial refund, a full refund following a partial one. **Reaching
"paid" is not reaching "tested" — every other reachable state needs its own
walk.**

### Reach each state through the shortest *real* path, not a shared long one

Resist the urge to walk one giant order through every state sequentially —
that produces one example of "cancelled-after-partial-refund" and zero of
plain "cancelled," because you only ever cancel the thing already midway
through the other path. Create one instance per state, and for states
reachable multiple ways (cancelled from `pending`, cancelled from
`confirmed`), create one of each if the business logic treats them
differently — check the transition matrix, don't assume symmetry.

### Cover both actor perspectives for anything with two

A financial or order-like transaction usually has an initiating side and a
receiving side, and the two often have distinct write paths that should
converge on the same state — an admin-initiated refund and a customer's own
return-initiated refund, say. **Walk both paths to the same terminal state
and assert they actually agree**, rather than assuming the second path was
tested because the first one was.

### Interleave, don't just sequence

The highest-value simulations deliberately create realistic *concurrent*
pressure on shared state within the otherwise-sequential walk — two
different customers redeeming the same limited coupon in the same run, a
second order competing for the last unit of stock the first order is
mid-checkout on. This is a lighter-weight cousin of `concurrency-testing.md`
proper (it does not need two real OS processes to demonstrate the
*business-logic* accounting is right, only to demonstrate a *race*
specifically) — use it to prove the accounting holds under realistic
sequencing even when you are not proving lock behaviour.

## Two walks worth adding to any multi-step flow

Both are cheap, both found real bugs, and neither is obvious from a
single-step test.

### The abandonment walk: stop, and do nothing

Walk the flow to the last step before completion — then **stop**. Close the
tab. Do not cancel, do not fail, just leave.

This is the state most flows never test, because every scripted walk either
completes or errors. What to assert after stopping:

- **Nothing was claimed on the customer's behalf.** No "thank you for your
  order" email for goods never paid for, no confirmation of a contract that
  was never concluded. A confirmation sent at step 4 of 5 is a lie the
  moment step 5 does not happen.
- **Nothing scarce stays held.** Whatever step 4 reserved must come back —
  and the mechanism that returns it must exist independently of the
  customer, because by definition they are gone.
- **The state is queryable.** This is the subtle one. If the abandoned
  record is indistinguishable from a normal in-progress record, no sweep
  can find it. Check that the flow *marks* the state it is in, not just
  that a sweep exists — a sweep selecting a status nothing ever sets
  matches zero rows and passes its own tests.

### The N-tab walk: the same session, N times

Open the flow in several tabs from one session and drive each to the
write. One cart, N checkouts.

Assert one completed write, and — separately — that the *scarce resource
moved once*, not N times. Those are different assertions and the second is
the one that matters: a flow can correctly produce one order while having
reserved the stock four times.

Then check **how** the losers failed. A form error is right. A 500 is a
bug. And identify which guard actually fired: in one real case the
predicted guard (a unique constraint on the write) was never reached at
all, because the winner consumed the shared resource and the losers
short-circuited earlier on "your basket is empty". The constraint was a
genuine backstop that the UI path never touched — worth knowing, because
relaxing the earlier check would silently move the failure to a different
layer with a different message.

## Logging the walk, not just asserting at the end

**A simulation script's log is itself a deliverable**, not incidental
output — it is the thing that lets a human (or a future debugging session)
see exactly which step produced which state, in order, without re-running
anything.

Log, at minimum, per step:

- What was called (the Action/method name and its key arguments)
- What state existed immediately before
- What state resulted, read back from the data layer — not asserted from
  memory of what the call *should* have done, but actually re-queried
- Elapsed time for the step, if the simulation doubles as a coarse
  performance smoke test (see `performance-testing.md`)

```
[cart:building]      customer=guest-1  add product=42 qty=2      -> cart#7 total=39.80
[checkout:place]     cart=7  payment_method=card                 -> order#ORD-000012 status=new
[payment:intent]     order=12                                    -> intent=pi_abc status=requires_payment_method
[payment:confirm]    intent=pi_abc  card=success-token            -> status=succeeded
[webhook:deliver]    event=payment_intent.succeeded               -> payment#9 pending -> paid
[order:ship]         order=12  actor=warehouse-1                  -> status=shipped, stock decremented
[return:request]     order=12  actor=customer                     -> return#3 status=requested
[return:approve]     return=3  actor=admin-1                      -> status=approved
[refund:issue]       payment=9  amount=partial                    -> refunded_amount updated, status=partially_refunded
```

**This log is what makes "did the demo/staging environment get built
correctly" a one-command check** rather than a manual click-through: re-run
the script, diff the log against a known-good prior run, and any divergence
in a step's *resulting* state (not its wall-clock time) is worth
investigating immediately.

### Where the log lives, and its relationship to test assertions

The log is evidence for a human; it is not a substitute for the assertions
a test suite runs. If this simulation is wired into automated tests, keep
the log as a debugging aid (write it to a file, print it under a verbose
flag) and let the actual pass/fail come from `expect()`/`assert()` calls
against the real data layer — the same assertion-strength discipline as
`test-quality.md`: assert the state, not that a step merely "ran without
throwing."

## Populating a demo or staging environment this way

The same script, run once with real seed data instead of throwaway test
values, **is the highest-fidelity way to build a demo environment that
shows every feature working** — because every row it leaves behind was
produced by the same code path a real customer or a real webhook would
produce it through, so every admin screen, every customer-facing status
badge, and every conditional UI branch has real data to render against
instead of an empty or synthetic-looking state.

This is also why keeping the simulation demo-safe matters: seed accounts,
seed payment credentials pointed at a sandbox never a live processor, and a
clear separator so nobody mistakes simulation-produced records for real
customer data later. Never let a system-simulation script run with
production credentials — the entire point is that it exercises real write
paths, which for a payment integration means it will genuinely attempt real
transactions if pointed at a real processor account.

## Checklist

- [ ] Every entity's full state graph enumerated before writing the walk, not just the happy path
- [ ] Every row created through the same method a real caller uses — no direct inserts standing in for a business step
- [ ] Every reachable state has at least one instance, including non-terminal intermediate states
- [ ] States reachable by more than one path each get their own instance where the business logic could plausibly diverge
- [ ] Both actor sides of any two-sided transaction produce and are checked against the same terminal state
- [ ] At least one deliberately interleaved/concurrent step exercising shared state
- [ ] The walk is logged per step: what ran, before-state, after-state re-queried from the data layer
- [ ] Assertions check re-queried state, not that a call merely completed
- [ ] Demo/staging runs are pointed at sandbox credentials only, never production ones
