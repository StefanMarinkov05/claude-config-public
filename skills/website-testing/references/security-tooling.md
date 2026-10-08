# Security tooling — scanners and dependency audits

The mechanical half of a security pass: DAST scanners, dependency audits, and
header checks. Cheap, repeatable, and **strictly complementary** to the
reasoning layer — a scanner finds misconfiguration and misses every
authorization bug.

Safe to run on a cheaper model tier once the reasoning pass has decided what
matters (`SKILL.md`, "Model and effort").

## What each tool is for

| Tool | Finds | Misses |
|---|---|---|
| **OWASP ZAP** (baseline) | Missing headers, cookie flags, info disclosure | Everything requiring app understanding |
| **OWASP ZAP** (full/active) | Injection with known signatures, path traversal | Business logic, authorization |
| **Dependency audit** (`composer audit`, `npm audit`) | Known CVEs in installed packages | Everything in your own code |
| **Static analyser** | A wrongly-typed security constant at compile time | Runtime behaviour |

### Deliberately not installed — record the reasoning

State absences so they are not mistaken for oversights:

- **sqlmap** — fuzzes for string-concatenated SQL, a class ruled out by reading
  every query path (parameter binding throughout, `ORDER BY` behind an
  allow-list). It would spend hours confirming a negative.
- **Metasploit** — targets known CVEs in deployed *services*, not a bespoke
  application's business logic, which is where real findings are. Relevant
  against the production host, not the app.

## Networking: the fact every scan depends on

When the scanner runs as a container alongside the app, it must reach the app
by its **internal service name**, not `localhost:<published port>`. The
published port is a host-side mapping the scanner's container does not share.

Getting this wrong produces a scan of nothing, which exits successfully.

## Baseline scan — passive, ~1 minute

Spider plus passive rules. Cheap enough for every deploy; catches the whole
header/misconfiguration class.

```bash
docker run --rm --network <app_network> \
  -v "$(pwd)/scratchpad:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t http://webserver:80/ -r zap-baseline-report.html
```

## Full active scan — attacks the target

Baseline rules **plus** attack payloads at every discovered parameter. Own dev
instance only, never a shared or production environment.

```bash
docker run --rm --network <app_network> \
  -v "$(pwd)/scratchpad:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-full-scan.py -t http://webserver:80/ \
    -r zap-full-report.html -x zap-full-report.xml
```

## Getting a session cookie when login is a reactive component

ZAP's built-in form-based auth posts credentials to a URL and reads a
response. It cannot reproduce a login implemented as a client-side component
(Livewire, Inertia, a SPA) that submits a signed snapshot of prior state
rather than a plain form body. **Authenticate outside ZAP and hand it the
resulting cookie.** The handshake, in order:

1. **`GET` the login page into a cookie jar.** This is also where the
   framework's CSRF token comes from — read it out of a `<meta>` tag or
   an embedded field, not out of thin air.
2. **Extract the component's own serialized state** from the response HTML.
   A reactive framework typically embeds this as an attribute on the root
   element the login form renders inside — look for whatever the framework
   calls a "snapshot" or "view state," not the form's visible inputs.
3. **Watch for the wrong component.** The page usually has *several* reactive
   components — a cart badge, a newsletter box, the login form itself. A
   regex greedy enough to grab "the first snapshot on the page" grabs
   whichever one happens to render first in the HTML, not the one that owns
   a `login()` method. Match on the component's own **name**, not position.
4. **POST the update** to the framework's generic update endpoint, carrying:
   the CSRF token, the exact snapshot from step 2, the field values, and a
   call naming the login method. Framework-specific headers (an X-header
   flagging the request as coming from the reactive client) are often
   required for the endpoint to accept it as anything but a page navigation.
5. **Read the response for a redirect effect**, not an HTTP redirect — a
   reactive endpoint often signals "go here next" inside the JSON body
   (`effects.redirect` or equivalent), while the HTTP status itself stays
   200.
6. **Verify before spending a scan on it.** Re-request a page only an
   authenticated session can reach, using the jar from step 1. It must
   return the real page, not the redirect-to-login an anonymous request
   gets. This is the one step with no excuse to skip — a login that silently
   failed produces a scan that silently scans nothing behind auth, and steps
   1–5 give no other signal that it worked.

**Do not forge a session row directly in the session store.** It's tempting
— one write to a `sessions` table or cache key — and it's the wrong shape:
it bypasses the exact mechanism under test, and doing it unprompted is
indistinguishable from an attack rather than a test of one.

## Authenticated scan — where the silent traps live

The only configuration that reaches an admin panel, and the one most likely to
produce a **false all-clear**. Each of these fails *silently* with a successful
exit code:

| Setting | Trap |
|---|---|
| `includePaths` | The scanner normalises away default ports. A pattern carrying `:80` matches **nothing** — the spider reports "found 0 URLs" and the run exits 0 |
| `excludePaths` for static assets | Otherwise most of the runtime goes to probing images for `.bak`/`.zip` variants |
| `excludePaths` for logout | A spider that follows the logout link **ends its own session**; every later request is scanned as a guest |
| Session injection | If login is a reactive-component POST rather than a form, form-based auth cannot reproduce it — inject the session via a request-sender script |
| Concurrency vs. session-regenerating middleware | Same session under parallel requests races the middleware that rotates the session token; low concurrency reduces (does not eliminate) the window |
| Output dir permissions | A root-owned directory makes the run exit non-zero on `Permission denied` **after** scanning successfully, losing every report |

**Measure the session-loss rate rather than assuming.** From the web server's
own access logs, same configuration except parallelism:

| | Default parallelism | Low concurrency |
|---|---|---|
| `/admin/*` → `200` (authenticated) | 92 | **587** |
| `/admin/*` → `302` (session lost) | 4,550 | **3** |

At default parallelism 98% of admin requests bounced off the login redirect — a
run that *looks* authenticated and is not.

### `threadPerHost` is not a spider parameter — and the plan will not tell you

**The single most expensive mistake in this whole procedure**, because it
fails exactly like success. `threadPerHost` is a real ZAP concept, but it is
an **active-scan** job parameter. Passed to the **spider** job in an
Automation Framework plan, ZAP does not error and does not stop the run —
it prints one line to stdout, buried among hundreds of others, and proceeds
at *default* (uncapped) concurrency:

```
Unrecognised parameter for job spider : threadPerHost
```

The run finishes, the report writes, the exit code reflects only whether
findings crossed the alert threshold — **nothing signals that the setting
you thought throttled the spider never applied.** The symptom is the same
session-race pattern above, on the spider phase specifically: the same URL
returning both `200` and `302` within the same minute, which only shows up
if you inspect the access log rather than trust the plan's own summary.

**The setting that actually throttles the spider** is a global connection
option, not a per-job parameter — pass it on the command line, not in the
YAML:

```bash
zap.sh -cmd -autorun /zap/wrk/zap-auth.yaml -config spider.thread=1
```

Confirm it took by re-checking the log for the warning line — its absence is
the only signal you get:

```bash
docker logs <container> 2>&1 | grep -i "unrecognised"
# no output = the concurrency setting actually applied
```

### Lowering concurrency reduces the race; it does not close it

A single number does not describe how much throttling is "enough," because
the underlying race is not a ZAP problem — it's whatever the application's
own session middleware does on **every** request. A framework that
regenerates or re-validates session state per-request (checking a stored
credential hash against the current one, say) can race itself the moment
two requests for the same session are in flight at once, at *any*
concurrency greater than one — a lower thread count narrows the window,
it does not remove it.

Measured directly: `threadPerHost: 2` on the active-scan job (a value that
*is* a real, accepted parameter there — unlike the spider case above) still
produced the same URL returning both `200` and `302` within the same
five-minute window. Only forcing full serial execution — one request in
flight at a time, everywhere in the plan — removed it entirely. If the
per-request cost of running fully serial is unacceptable for your time
budget, the actual fix is on the application side (a session store that
locks the row for the duration of a request, or session state that
tolerates concurrent reads without invalidating), not a ZAP tuning knob —
document the residual race rate rather than chasing a "high enough thread
count" that does not exist for this class of bug.

```bash
zap.sh -cmd -autorun /zap/wrk/zap-auth.yaml \
  -config spider.thread=1 \
  -config scanner.threadPerHost=1
```

**The general lesson, not just this one key**: an Automation Framework plan
does not validate its own parameters against each job's real schema.
A misspelled or misplaced key degrades the run silently rather than failing
it — treat every job parameter as unconfirmed until you have grepped the
container's own stdout for an `Unrecognised parameter` line, and treat a
clean grep as the confirmation, not the absence of a crash.

## Proving the scan reached the app

**This is the step that separates a real negative from a worthless one.** Do
not trust the scanner's summary; read the web server's access log:

```bash
docker compose logs webserver | grep -oP '"GET \K[^ ]+' | sort -u | wc -l
docker compose logs webserver | awk '{print $9}' | sort | uniq -c
```

Report coverage as measured numbers:

| Area | Distinct paths returning `200` |
|---|---|
| Product detail pages | 156 |
| Admin panel pages | 160 |
| **Total distinct paths served `200`** | **533** |

A "0 findings" result is only as meaningful as the surface behind it.

## Triaging scanner output

Scanners over-report. For each alert, decide and **record** one of:

- **Real** — becomes a bug-bounty entry.
- **False positive with a reason** — e.g. an alert on a header that a later
  middleware sets, or on a page the app never serves that way. Write the reason
  down; the same alert will reappear next run.
- **Permanent and accepted** — e.g. a CSP that must allow `unsafe-eval`
  because the frontend framework evaluates attribute expressions at runtime.
  Record *why* it is permanent, so nobody re-investigates.

**A CSP written to satisfy a scanner rather than the application will break the
application.** Decide what the policy genuinely enforces — commonly
`frame-ancestors`, `object-src`, `base-uri`, `form-action`, which hold
regardless of a permissive `script-src` — and pin those in a test.

## Where security headers must be registered

If an admin panel builds its **own** middleware stack, a header middleware
registered on the default web group will not apply to it — leaving the most
sensitive area unheadered. Register globally, and write a test that goes red if
the registration is narrowed.

Check static assets too: headers set by the application do not apply to files
the web server serves directly.

### A CSP is verified against the page you happened to test, not the app

A restrictive `script-src`/`connect-src`/`frame-src` is written and tested
against whatever page the reviewer had open — commonly a catalogue or
homepage. **A third-party integration loaded on a different page (payment,
maps, chat, analytics) is invisible to that review entirely**, and the first
sign of the gap is the feature silently failing in a browser, not a scanner
alert — a CSP violation is a browser-console error, not an HTTP response
code, so it produces no signal a request-based tool or a server log will
ever surface.

A payment provider's script tag is the canonical case: it typically needs
its own origin in **three separate directives** at once — the script itself,
the API calls it makes back to the provider, and a frame for a hosted
challenge or hosted field. Missing any one of the three degrades differently:

| Directive missing | Symptom |
|---|---|
| `script-src` | The library's script tag never loads; nothing downstream initializes |
| `connect-src` | The library loads and initializes, then its own network calls fail silently |
| `frame-src` (or `default-src` with none set) | The library initializes and calls out fine, but any hosted frame it tries to embed — a hosted field, a challenge step — is blocked |

**The check that actually catches this**: enumerate every external origin
referenced anywhere in the templates (`grep -rn 'https://' resources/views`
or equivalent) and diff that list against the CSP's allow-lists directive by
directive — do not eyeball the policy against "does this look permissive
enough."

**And when you fix it, prove the assertion catches a partial fix.** A test
asserting `header.contains('script-src')` and `header.contains(origin)` as
two separate expectations passes even after the origin is *removed from
script-src specifically*, if that same origin string still appears anywhere
else in the header (its `frame-src` entry, say). Parse the header into
directives first, then assert against the specific directive — the same
discipline as any other assertion-strength issue (`test-quality.md`), applied
to a security header instead of a database row.

## Dependency audits

```bash
docker compose exec app composer audit
npm audit --omit=dev
```

For each advisory, establish **reachability** before assigning severity. A
transitive dependency pulled in by a package you use for one narrow purpose may
have no reachable path to the vulnerable code. Record the reasoning — "4
advisories, 1 package, no reachable path because X" is a complete answer;
"4 advisories" is not.

## Dev-only versus production

Some hardening applies only where it is configured. `server_tokens off` and
`expose_php = Off` suppress version banners in a local Docker stack; a
production host provisioned separately still needs both set there. **Record
which environment a fix actually covers** — a header verified locally is not a
header shipped.

## Checklist

- [ ] Scanner reaches the app by internal service name
- [ ] Baseline run and triaged
- [ ] Authenticated plan checked against every silent trap above
- [ ] Login verified against a genuinely protected page before spending a scan on it
- [ ] Every job parameter confirmed against its own job's schema — grep the container log for "Unrecognised parameter"
- [ ] Concurrency throttled at the layer that actually applies (global `-config`, not a job parameter guessed by analogy)
- [ ] Session-loss rate measured from access logs, not assumed
- [ ] Coverage reported as distinct paths actually served `200`
- [ ] Every alert triaged as real / false-with-reason / permanent-with-reason
- [ ] Every external origin the app loads diffed against the CSP directive by directive, not eyeballed
- [ ] A CSP regression test parses directives individually, not as one substring search
- [ ] Headers verified on the admin stack *and* on static assets
- [ ] Dependency advisories assessed for reachability, not just counted
- [ ] Environment scope of each fix recorded
