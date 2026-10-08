# Payment provider testing (Stripe)

Testing a third-party payment integration end to end without ever putting
your own suite's success on the provider's servers being reachable. The
tension this file resolves: **fake the provider in your test suite, but
still verify against the real one at least once** — those are different
activities with different owners.

## The two-track model

| Track | What it proves | Runs where |
|---|---|---|
| **Faked client, in the automated suite** | Your own arithmetic, state machine, and endpoint behaviour | CI, every run |
| **Real sandbox API, driven manually** | The provider accepts the exact request shapes you send | A dated, recorded pass — not CI |

Neither substitutes for the other. A suite that only fakes the client has
never proven the provider's real API accepts your payload shape. A pass that
only hits the real API, with no faked-client suite backing it, has no
regression protection and re-verifies nothing on the next change.

**State the gap honestly rather than implying either one covers the other.**
"Every test fakes the client, so what is proven is this application's own
arithmetic, state machine, and endpoint behaviour — not that the provider
accepts the exact shapes sent" is the correct sentence. "Payments are
tested" is not, regardless of which track produced it.

## Mocking the right seam

A payment SDK client is frequently a magic-accessor object: `$client->foo`
delegates through a generic getter to the real service object. Mocking the
top-level magic method and leaving the delegation untouched produces a
confusing failure — a mock that answers to the *wrong* call, or a
`BadMethodCallException` naming a method you never intended to invoke
because the delegation ran for real underneath your mock. Mock the concrete
method the code actually calls at the bottom of that delegation chain, not
the syntactic sugar on top of it.

## The real-API pass: what to actually drive

Not a smoke test — a specific set of behaviours only the real API can
confirm, because a fake only returns what you told it to return.

### Every stage of an intent's lifecycle

| Stage | What only the real API proves |
|---|---|
| Creation | The provider accepts your amount/currency/metadata shape |
| A card requiring no extra step | The base confirm→charge path |
| **A card that forces the 3-D-Secure-equivalent step** | Your integration actually renders and survives the challenge — most integrations are never driven through this by their own author |
| The success webhook | Signature verification and idempotency against a *real* signed event, not one you constructed by hand |
| A partial refund | The refund amount, the webhook it triggers, and your own accumulation logic against a **cumulative** total (see below) |
| The same webhook event redelivered | Idempotency holds against the provider's real retry behaviour, not just your own duplicate-POST simulation |
| The same payload, unsigned | Signature verification actually rejects it |

**Use the provider's own designated test values for each state**, not
arbitrary card numbers — the documented approval, decline, and
challenge-triggering test cards exist because inventing your own does not
reliably route to the provider's respective code paths.

**The challenge step is a browser flow**, not an API call — the customer is
redirected to (or shown an iframe of) the provider's hosted 3DS page and
clicks through it. `automated-browser-testing.md`'s "Payment challenge
flow" spec is how to drive it repeatably: cross-frame fill of the Elements
iframe, follow the `redirect_to_url`, click **Complete** on the hosted
page, then poll the payment row until the *webhook* (not the redirect)
flips it to paid, with a loud timeout. That spec `->skip()`s in CI (no
provider secrets there, ever) and is kept as a local runbook.

### Delivering a webhook when the CLI forwarder is unavailable

A provider's CLI forwarding tool is a convenience, not the mechanism. When it
cannot reach your local endpoint — network policy, a tunnel that will not
authenticate, or the account-mismatch trap below — fetch the real event
object from the provider's API directly and deliver it yourself:

1. Fetch the event object by id from the API (not fabricated JSON — the real
   object, with the real field shapes).
2. Compute the provider's signature scheme over the raw payload bytes with
   your own webhook secret.
3. `POST` it to your own endpoint with the signature header, exactly as the
   provider's own forwarder would have.

This exercises the real middleware with real bytes, which is the property
that matters — it is not a lesser test than the forwarder, just a manual
substitute for one link in the chain.

### The trap that produces "it's not working" with every symptom pointing elsewhere

**A CLI tool and your application's API keys can be authenticated to two
different accounts on the same provider**, and every symptom this produces
points away from the actual cause:

- The forwarder reports itself ready and connected.
- Your application logs show no error.
- The payment state on the provider's own dashboard says it succeeded.
- Your local database still shows it pending, indefinitely.

The forwarder is working exactly as configured — forwarding a *different
account's* events, of which there are none matching what you just did,
so nothing arrives. **A matching webhook signing secret is not evidence the
accounts match** — that secret is typically generated per CLI session, not
tied to the account, so it validates whatever *does* arrive regardless of
which account produced it.

**The check**: compare the account identifier the CLI reports itself
authenticated as against the account identifier your application's own
client resolves at runtime. If they differ, re-authenticate the CLI or point
the application's keys at the account the CLI already holds — do not debug
the webhook handler first.

## What the intent should and should not carry

**Put the minimum on the payment object; recompute everything else from your
own records.** A provider's payment object is frequently visible to more of
your own staff and tooling than your primary database is (a dashboard login
is a lower bar than a full database credential) — treat it as a boundary,
not an internal record.

Concretely: an id linking back to your own row, the amount, and the
currency are usually sufficient. Shipping addresses, contact emails, and any
other **customer PII does not need to live there** if your own order record
already has it — putting it on the payment object only widens who can read
it. Confirm what you actually send by reading the object-creation call
directly, not by assuming from the SDK's optional-field list.

**A URL the provider redirects the browser back to, carrying data in the
query string, persists in three places you likely did not intend**: the
customer's own browser history, your web server's access log (most access
log formats capture the full request line by default), and anywhere that
access log is subsequently shipped or aggregated. If a redirect-back token
grants any read access to payment state — and many do, by design, so the
return page can show a result without a separate authenticated lookup —
scrub it from the URL on arrival rather than leaving it to expire out of
history and logs on its own. A same-page redirect to the clean URL closes
all three; a log-format change closes only one of them.

## Assertion-strength traps specific to payment amounts

**A provider reporting a cumulative refunded total, read by code that
accumulates its own total, double-counts every refund after the first.**
Refund 25 then 40 and a naive accumulator reads 65 (25+40) against the
correct 40 (the provider's own already-cumulative figure) — or the reverse,
depending which side is naive. Read the provider's own field documentation
for whether a given figure is a delta or a running total, and write the
receiving side to match; do not assume symmetry between what you send and
what you receive back.

**A no-op needs its own test, and the naive assertion gets it backwards.**
When the target state already equals the current state (a webhook echoing
back an admin-initiated action, a retried delivery of an already-applied
event), the correct behaviour is often "record that this arrived, change
nothing" — and a test asserting "the amount changed" fails against exactly
correct behaviour. Assert that the *write happened once* (one ledger row,
not two) rather than that a value moved.

## The abandonment trap: confirming a sale that never happened

The single highest-value thing to check in a card flow, and it is not about
Stripe at all — it is about what *your* code does when Stripe is never
heard from.

A card payment has two independent paths: the browser's redirect, and the
webhook. The standard advice is that only the webhook may mark a payment
paid, and that is correct. The trap is one layer up: **what does order
placement itself do before either path reports anything?**

If the order-confirmation email is sent when the order is *created*, then a
customer who reaches the card form and closes the tab receives "thank you
for your order" for goods they never paid for — and, in an inventory-backed
shop, the stock stays reserved indefinitely.

Check, in this order:

1. Find where the confirmation email is dispatched. If it is at order
   creation, ask whether the contract is actually concluded at that point.
   For a card sale it is not; the conclusion is the successful payment.
2. Check whether a **cash-on-delivery-style** method exists. If so the
   answer differs per method — COD genuinely does conclude at placement —
   and the branch deciding this belongs on the payment-method enum, not
   written inline at each call site.
3. Check the inline spelling of that branch. `!== Card` and
   `=== CashOnDelivery` are the same condition today and diverge silently
   the moment a third method is added, in opposite directions. A `match`
   with no default arm forces the new case to be answered.

The test that proves it: drive checkout to the payment step on the card
path, assert **no** mail was queued, then drive the payment to success and
assert exactly one. Two assertions, because "sent at the wrong time" and
"never sent" both pass a test that only checks the end state.

## Checklist

- [ ] Faked-client suite covers arithmetic, state machine, and endpoint behaviour
- [ ] At least one dated pass against the real sandbox API, separate from CI
- [ ] Every lifecycle stage driven with the provider's own designated test values, including the challenge-step trigger
- [ ] Webhook delivered from a real fetched event when the CLI forwarder can't reach the endpoint
- [ ] CLI account identity checked against the application's own resolved account before debugging anything else
- [ ] Payment object payload read directly from the creation call — no PII beyond what a boundary needs
- [ ] Any redirect-back URL scrubbed of provider tokens on arrival
- [ ] Cumulative-vs-delta amount fields confirmed from provider docs, not assumed
- [ ] A no-op/idempotent case asserts write-count, not value-change
