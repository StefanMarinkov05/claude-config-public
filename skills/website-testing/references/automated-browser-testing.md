# Automated browser testing — a real browser in the test suite, on every push

Between `automated-testing.md` (no browser, no CSS, no JS) and a manual
`ui-testing-mcp.md` pass (a human driving a real browser once): a **scripted
browser suite that runs in CI**. Playwright, Cypress, Puppeteer, Selenium,
Pest 4/5's browser plugin, Laravel Dusk — the framework varies, the
techniques below do not.

## What this layer is for

**Good at, that headless tests miss:** the JS layer executing (reactive
framework updates, client-side validation, optimistic UI), CSS actually
applying (responsive layout, overflow, tap-target size, contrast), assets
resolving (a broken bundle, a 404 font), console errors, cross-frame flows
(payment iframes, OAuth popups), and "the whole page is broken" that a
string-match assertion on a 500 would pass.

**Bad at:** exhaustive coverage (each test pays a browser-context cost, see
below), business-logic edge cases (cheaper in a headless test), and anything
the happy path does not walk.

**Where it sits:** it is the regression net for what only a browser proves.
The manual MCP pass still finds what no assertion was written for; this
finds when one of those breaks later.

## The governing traps (each has cost me a false pass)

### 1. An assertion on an unstyled page is a false pass

If the CSS bundle did not load, nothing is laid out, so **nothing
overflows, every element is full-width, every layout assertion passes
green**. Before any layout/responsive/visual assertion, assert the styles
are actually in effect:

- A probe element with a known utility class computes the expected value
  (`<div class="grid">` → `getComputedStyle().display === 'grid'`; a
  padding utility → the right pixel value). Inject it, read it, remove it.
- The web font resolved, not the fallback — but this is **flaky across
  layouts** (the body may not carry the font class; a wrapper does), so
  prefer the structural probe.
- `≥ N` stylesheets attached, and the built asset (`app-<hash>.css`) not the
  raw source (`app.css`).

If the precondition fails, **fail the test there** with "styles did not
apply — is the build current?", not silently pass the overflow check.

### 2. The dev asset server is not reachable from the test's app

If the browser suite boots the app itself (in-process, or a bundled dev
server), and a separate hot-reload/dev-asset server (`vite`, `webpack-dev-server`)
is what normally serves JS/CSS, the test's app **cannot reach it** — it will
serve the raw un-compiled source, and you are back in trap #1.

Fix: force asset resolution against the **built manifest** in the test env
(remove/ignore the `hot` file, point the framework's asset resolver at the
build), and **run the production build first** in CI. A stale or missing
build is the same failure.

### 3. Each `visit()` / test is a fresh browser context

New context = new cookies = new session = new storage. A multi-page user
journey (guest builds a cart across three pages) **cannot be three separate
`visit()` calls** — the cart from page 1 is gone by page 2. Chain
navigation on **one** page object (`->navigate()`, clicking real links)
inside one test.

Corollary: this is also what makes tests isolated. Do not fight it for
isolation; fight it only for a journey.

### 4. Per-test browser-context setup dominates the clock

A browser suite is slow not because pages load slowly (they may load in
100ms) but because **spinning up and tearing down a browser context per
test costs ~10–20s**. A 25-page smoke matrix as 25 tests is ~7 minutes; the
same as **three batched tests** (visit a list of URLs, fan the assertion
out) is under one. Batch aggressively; reserve one-test-per-case for flows
that genuinely need isolation.

### 5. Modal-driven admin actions hang the driver

A UI framework whose destructive actions open a confirmation modal (Filament,
many admin kits): a driver that clicks the button and awaits the result
**never returns** — it is waiting on a dialog it did not open. For an E2E
*lifecycle* test, drive those state transitions through the real
**Action/service** the modal would call (with the real actor and its real
guards), and keep one browser assertion that the admin *can reach* the
screen. The modal path itself belongs in a dedicated admin-panel pass, not
the lifecycle.

### 6. The suite shares the test process's DB connection (sometimes)

If the browser suite boots the app in-process (e.g. Pest's browser plugin
runs the HTTP kernel in the test process), then `factory()`, `actingAs()`,
fakes, and DB assertions in the test body **are visible to the browser's
requests**. This is powerful (assert the DB after a real click) but means
the isolation model differs from a suite that hits a separate server — know
which you have. A suite against a *separate* server process gets no
transactional rollback; it needs its own database and explicit truncation
(the "no refresh trait, truncate per test" pattern).

## The specs worth writing

### Smoke matrix — "is anything totally broken"

Load every reachable route (public, then authed, then admin index). Assert
per page: HTTP 200 or the expected redirect, **zero console errors**, no
stack-trace / framework-error text in the body. Catches a broken bundle, a
missing partial, a fatal on an unhit page. Cheap if batched (#4).

### Responsive / overflow — "usable on a phone"

Device widths (375 / 768 / 1440 are the common set; note the **effective**
CSS width after the scrollbar and assert on that). Per width, per page:

1. The styles-loaded precondition (#1) — first, every time.
2. Walk every element: `getBoundingClientRect().right` vs `clientWidth`,
   and `left < 0`; `documentElement.scrollWidth` never exceeds
   `clientWidth`. Flag the **deepest** offending element, and **skip**
   elements inside an `overflow: hidden/auto/scroll` ancestor (a decoration
   deliberately drawn outside a clipped box is not a bug).
3. Use **realistic fixture content**, not the factory's filler — a
   255-char unbroken `regexify()` string blows any layout to ~2000px and
   tells you nothing about the design. (It *does* reveal a missing
   `break-words` — note that as a separate, minor finding.)

Known non-bugs (undersized nav-chrome tap targets, a grid that stops
gaining columns past a breakpoint) go in the spec as documented xfails/notes,
not new failures.

### System-simulation E2E — the lifecycle in the browser

`system-simulation-testing.md`'s walk, but every customer-facing step is a
real click in a real browser: catalogue → open product → add to cart
(reactive button) → cart → checkout (fill the real form, pick the real
options) → place → confirmation renders → track. DB-assert between steps.
Staff-side transitions via the Action (#5). One session throughout (#3).
**Mutation-test it**: stop the transitions early, skip a required form
field — confirm each turns the test red at the expected line
(`test-quality.md`).

### Render-speed / asset smoke (coarse)

Not a substitute for `performance-testing.md`, but nearly free here: from
inside the page, read `performance.getEntriesByType('navigation')[0].duration`
and the `resource` entries; assert the count is sane and nothing takes
absurdly long. Catches an un-minified bundle shipped, a synchronous
third-party script, an image served at full resolution. If the suite's
per-test time itself regresses sharply, that is also a signal.

### Payment challenge flow (3-D Secure and equivalents)

The one flow a faked payment client cannot cover (`stripe-testing.md`): a
real test key, the provider's test "challenge required" card, and the
provider's webhook forwarder running locally.

- Fill the provider's **Elements/hosted-field iframe** — a cross-frame
  target, addressed as a frame, not a top-document selector.
- Place the order → provider returns "requires action" → the driver follows
  the `redirect_to_url` / opens the challenge frame → clicks **Complete**
  (or the test-mode equivalent) on the provider's hosted 3DS page.
- Back on the app: wait for the confirmation.
- **Poll the payment row** until it flips to paid — the flip is the
  *webhook's*, arriving asynchronously, not the redirect's. Poll with a
  timeout that **fails loudly**, never hangs.
- Assert the payment-event row count is exactly 1, and that a redelivery of
  the same event keeps it at 1 (idempotency).

This needs live external infrastructure, so it **cannot run in CI** (no
provider secrets in CI, ever — `security-tooling.md`). Keep it `->skip()` in
CI with a message naming the precondition, and document it as a **local
runbook** — mirror the manual 3DS record step-for-step so a human can re-run
it before a release.

### Accessibility (if the layer supports it)

Many browser drivers can inject `axe-core` and assert zero violations, or
check contrast / focus order / ARIA directly. This is the cheapest
accessibility signal available; a dedicated audit is still a separate pass.

## CI wiring

- The browser suite is its **own job**, not folded into the fast suite.
- It needs what the fast suite does not: the browser binaries and their
  system libraries (`playwright install --with-deps`, or the equivalent), a
  Node toolchain, **the production asset build**, and possibly the socket/IPC
  the driver uses.
- It may need **no running app server** if the framework boots the app
  in-process — check before adding an `artisan serve` / `npm start` step
  that just races the tests.
- The payment-challenge spec stays skipped here.
- One browser, one CI runner, no real devices, no text-zoom, no real
  assistive tech — state these gaps honestly in the test-record doc, the
  same discipline as every other layer.

## Model and effort

| Task | Model | Effort | Thinking |
|---|---|---|---|
| Designing the lifecycle E2E walk (which steps, which selectors survive a re-render, where session binding bites) | Opus / Sonnet-high | high | on |
| Smoke matrix, responsive spec (mechanical once the probe pattern is known) | Sonnet | medium | off is fine |
| The payment-challenge spec (cross-frame, async webhook race) | Opus / Sonnet-high | high | on |
| Fixing a flaky selector, batching for speed, CI YAML | Sonnet | medium | off is fine |

The traps above are **empirical** — you find them by running the suite and
watching it lie, not by reasoning up front. Budget iterations.

## Checklist

- [ ] Styles-loaded precondition asserted before every layout/visual check
- [ ] Asset resolution forced against the built manifest; production build runs first in CI
- [ ] Multi-page journeys chain navigation on one page object, not separate `visit()` calls
- [ ] Smoke and responsive matrices batched, not one-test-per-page
- [ ] Admin state transitions in a lifecycle test go through the real Action, not a hung modal click
- [ ] Lifecycle E2E mutation-tested — proven to fail when a step is skipped
- [ ] Responsive spec uses realistic content, flags the deepest offender, skips clipped decorations
- [ ] Payment-challenge spec: cross-frame fill, follows the redirect, polls the webhook-driven row with a loud timeout, asserts event-count idempotency
- [ ] Payment-challenge spec `->skip()`s in CI and is documented as a local runbook
- [ ] Browser suite is its own CI job with browser deps + build; no app server if the framework runs in-process
- [ ] CI-only gaps (one browser, no devices, no zoom, no AT) stated in the test record
