# UI testing with an MCP browser

Driving a real browser against a running application. This is the only layer
that proves what a user actually sees — and the layer with the most ways to
produce a confident, wrong result.

## What this layer is for

**Good at:** rendering defects, interaction behaviour, console errors, real
session/authorization state, responsive layout, anything where the visual
result *is* the finding.

**Bad at:** business logic, anything off the happy path, exhaustive coverage
(too slow), and — critically — anything requiring a modal to be dismissed
programmatically.

**Use it to confirm, not to discover.** The static review finds the bug; the
browser proves it is real. A browser-first approach finds only what you happen
to click.

**This layer is a human driving a browser once, exploratively.** The
*scripted* browser suite that runs in CI on every push — smoke matrices,
responsive/overflow checks, lifecycle E2E, payment-challenge flows — is
`automated-browser-testing.md`. Findings from a manual pass here that are
worth guarding against regression get turned into a spec there.

## Session isolation

The browser keeps a profile on disk between runs, and state leaks:

- A cart from a previous session is still in the cookie.
- **A logged-in session makes an authorization check appear to pass when it
  would have redirected a fresh visitor.** This is the one that invalidates a
  role-denial pass.
- A dismissed banner stays dismissed.

Add `--isolated` to the MCP server's args to hold the profile in memory and
discard it on exit. **A changed MCP config does nothing until the session
restarts** — so decide this before the pass, not during it.

Trade-off: isolation is right for a repeatable test and annoying for
exploration (you re-log-in every session). Either leave it off for exploratory
work and turn it on for verification, or keep it on and supply a saved login
via a storage-state file.

## Device emulation

Resizing a desktop window changes the viewport **and nothing else**. The
browser still sends a desktop user-agent, still reports a mouse rather than a
touchscreen, still uses a device-pixel-ratio of 1. A media query on
`pointer: coarse` or `hover: none` — the correct way to ask "is this a touch
device" — does not fire.

So a resized window exercises the layout while leaving the device detection
untested. Use a real device profile when the claim is "works on mobile."

## Establish the console baseline first

Read the console on a known-good page **before** testing anything, and write
the number down. A dev-server setup commonly produces a fixed set of harmless
errors (CORS against the asset server, etc.).

Anything **beyond that baseline** is a finding. Without the baseline you will
either chase noise or miss a real error inside it.

**Count error *events*, not lines.** A multi-line error inflates the count —
one pass reported "70 errors" that were four errors wrapped across 896 lines.
Classify before reacting:

```bash
grep "^\[ERROR\]" console.log | sed 's/[0-9]\{2,\}/N/g' | sort | uniq -c | sort -rn
```

## Driving a reactive component

Filling a field with the driver's `fill()` sets the DOM value but does **not
always fire the events a reactive framework listens for**, so the server-side
property is never updated and the submit does nothing. Symptoms: the form
stays put, no validation error appears, and the server log shows no attempt at
all.

Three approaches, in increasing reliability:

1. `fill()` — fastest, often silently ineffective on reactive bindings.
2. Type character-by-character (`pressSequentially`) — fires input events, but
   can race a debounce.
3. **Drive the component directly** — most reliable:

```js
const el = document.querySelector('#email').closest('[wire\\:id]');
const c = window.Livewire.find(el.getAttribute('wire:id'));
c.set('email', 'user@example.com');
c.set('password', 'password');
await c.call('login');
```

Adapt the accessor to the framework. The principle generalises: reach the
component's own state API rather than simulating keystrokes.

## The modal trap — this will hang your session

**A UI action that opens a confirmation modal never returns to an awaiting
driver.** The promise does not resolve; the call sits until the MCP idle
timeout fires (30 minutes by default), and the whole turn is lost.

```js
// DO NOT DO THIS — hangs until timeout.
await c.call('callMountedTableAction');
```

Two ways around it:

- **Preferred: drive the underlying call instead.** Invoke the Action, policy,
  or endpoint the button would have reached. This is also better testing — the
  button proves the button works; the Action proves the *rule* holds against a
  request that never saw the button.
- If the modal itself is the thing under test, click to open it, then take a
  snapshot and click the confirm button as a **separate** call. Never await the
  action call that spawns it.

## Destructive actions

A live click on Delete against seeded data is unrecoverable without a reseed,
and a permission layer may (correctly) refuse it.

**Prefer a rolled-back transaction** driving the same Action:

```php
DB::transaction(function () use ($model) {
    $model->delete();          // observe what happens
    throw new RollbackOk();    // never commits
});
```

Then **verify the data afterwards** — print the row counts and confirm they are
unchanged. Say so in the write-up.

## Responsive testing, measured rather than eyeballed

"Looks fine at mobile width" is not a result. Two checks, both scriptable:

```js
// 1. The page itself must not scroll horizontally.
document.documentElement.scrollWidth <= document.documentElement.clientWidth

// 2. No element's right edge may cross the viewport boundary.
[...document.querySelectorAll('*')]
  .filter(el => el.getBoundingClientRect().right > document.documentElement.clientWidth)
  .map(el => el.tagName + '.' + el.className)
```

The second catches what the first misses: a single overflowing child inside an
`overflow-hidden` ancestor produces no page scroll and is still clipped.

**Report the width the page actually saw, not the window width.** A 375 px
window is roughly 361 CSS px to the document once the scrollbar is subtracted,
and the assertions should use the real figure.

**Check tap-target sizes** (WCAG 2.5.8 asks for 24 × 24 CSS px) — and *scope
the finding before reporting it*. "Fifteen undersized targets" is alarming;
"fifteen, all navigation chrome — no primary action is undersized, and one is
a skip-link that is correctly 1 px until focused" is the truth. A finding
reported without that scoping wastes someone's afternoon.

State the limits plainly: a pass here is a claim about **one browser at N
widths on one machine**, not about every device.

## Evidence to capture

Per `documentation-standards.md`. In this layer specifically:

- **Screenshot** the rendered defect, the authorization result, before/after
  pairs.
- **Do not screenshot** a status code — use `curl -o /dev/null -w
  "%{http_code}"`, which a reader can re-run.
- Capture the **console delta**, not the absolute count.
- Record the **URL bar** when the URL is part of the claim (a shareable variant
  link, a redirect target).

## Authorization testing in a browser

Two distinct checks, and only the second is real:

1. **What the navigation offers.** Useful as a usability signal. A sidebar
   showing exactly the expected resources is worth a screenshot.
2. **What a direct URL returns.** This is the actual test. **A hidden nav link
   is not access control.**

Request every protected route by URL for every role, including the roles that
*should* succeed — without a passing control, universal denial proves the
request was broken rather than that authorization works.

For a full matrix, driving the HTTP kernel directly is faster and more
complete than clicking, and produces a table you can paste:

```php
$req = Request::create('/'.$path, 'GET');
$req->setLaravelSession(app('session.store'));
$code = app(Kernel::class)->handle($req)->getStatusCode();
```

Use the browser to confirm a representative sample of that matrix is real.

## Interpreting what you see

- **Verify the DOM, not the pixels.** "The price updated" should be confirmed
  by reading the element's text after the click, not by looking at the image.
- **A graceful fallback is a result worth recording**, not only a break. "This
  product has no image and rendered the placeholder correctly on all three
  surfaces" is a finding.
- **A row existing is not a promise the thing it points at exists.** A record
  whose file is missing skips the "no image" branch and attempts a real request
  that 404s. Check the *usability* of the referent, not merely presence.

## Checklist

- [ ] Isolation decided before the pass; MCP config changes need a restart
- [ ] Console baseline established and written down
- [ ] Error *events* counted, not lines
- [ ] Reactive components driven via their state API, not `fill()`
- [ ] No awaited call on a modal-opening action
- [ ] Destructive probes rolled back; row counts verified after
- [ ] Authorization tested by direct URL, with a passing control
- [ ] Claims verified against the DOM, not the screenshot
- [ ] Responsive checked by measurement (scrollWidth + per-element right edge), not by eye
- [ ] Actual document width used in assertions, not the nominal window width
- [ ] Tap-target findings scoped to primary actions vs chrome before reporting
- [ ] Screenshots only where visual state is the evidence
