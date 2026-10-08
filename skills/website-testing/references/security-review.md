# Security review — the reasoning layer

Reading the request path to find authorization bugs, IDOR, trust-boundary
violations, and business-logic flaws. **This is the phase that finds the bugs
worth finding**, and the one a model downgrade silently destroys (see
`SKILL.md`, "Model and effort").

A scanner finds headers. This finds the bug that lets one customer read
another's order.

## Why this cannot be automated

Finding an IDOR is a *chain of inferences*: this property is public → therefore
client-writable → therefore the check in the setup method is bypassable →
therefore the draft leaks. A tool that pattern-matches, or a model that answers
without reasoning through the chain, stops at "there's a visibility check,
looks fine" — which is exactly the surface reading that misses the bug.

## What to read, in order

### 1. Routes

Every route taking an ID or a scalar parameter is a candidate. Classify each:

- **Typed model binding** — structurally safe from malformed input; still needs
  an ownership check.
- **Plain scalar** — reaches your code raw. Both a crash risk and the usual
  home of IDOR.

### 2. Every client-writable property that holds an identifier

This is the highest-yield sweep in the whole review.

In a reactive framework, a public property is **re-hydrated from the client on
every update**. So a check performed in the setup/mount step protects only the
first render. If the property feeds a query afterwards, the client can change
it and the check never re-runs.

**The check-at-mount / use-later pattern** is the bug class. Two real findings
of exactly this shape:

- A visibility check ran in `mount()` but the computed property that actually
  fed the page did not re-apply it — so setting the id to an unpublished
  record's after mount leaked it.
- A bare unscoped `find()` on a client-writable id printed another customer's
  order serial.

**The fix is two-part, and both parts matter:**
1. **Re-apply the scope where the id is *used*, not only where it arrives.**
   This is the load-bearing half.
2. **Lock the property** against client re-hydration (`#[Locked]` or the
   framework's equivalent). Defence in depth.

**The standing rule:** any public property holding an identifier or feeding an
authorization decision needs both.

Sweep *all* such properties, not only the suspicious one. Record the ones that
are **not** findings today and why — a property reaching only public catalogue
data is fine now and becomes a finding the moment a non-public column is added.
That watch-list is worth more than the clean result.

### 3. Query scoping

```php
Order::findOrFail($id);                      // WRONG — any id
auth()->user()->orders()->findOrFail($id);   // RIGHT — scoped to the owner
```

A policy denies access to a record **already loaded**; scoping stops it being
loaded at all. Do both — but if only one, scope.

### 4. Policies, and the super-admin trap

Read every policy method and ask what it *cannot* express.

**The trap:** if a `Gate::before`-style callback short-circuits every check for
an administrator, then any "nobody may do X" rule written inside a policy is
**dead code** for the one role that can reach it.

A real instance: a self-role-assignment guard written as
`&& $model->id !== $user->id` inside the policy never executed, because only
administrators held the ability. The rule had to move to a form-mutation hook,
where the short-circuit cannot reach.

So: **for every "nobody may do X" rule, confirm it lives somewhere the
super-grant does not bypass.**

Also check that policies for models in *package* namespaces are registered
explicitly — convention-based resolution may not find them, leaving the model
that controls permissions as the one ungated model in the system.

### 5. Permission catalogue design

Look for **abilities whose subject is the permission system itself**.

Ordinary abilities are safe to expose as checkboxes: their blast radius is one
resource. An ability like `update_role` is *reflexive* — its blast radius is
the entire catalogue, because the thing it edits is the thing that decides
everything else. Granting it to a role lets that role grant itself everything.

Any such ability needs a self-reference guard at a seam the super-grant cannot
bypass, and it needs it **when the ability is added to the catalogue**, not
when a UI for it is built.

The same reasoning applies to splitting abilities: if "edit a user" and "grant
a user a role" are one permission, everyone who can edit a user can promote
themselves.

### 5b. Injection classes beyond SQL

SQL injection gets the attention; these are the ones a review forgets. Each is
a *probe*, not just a code read — see `input-abuse-techniques.md` for payloads.

- **Command injection.** No shell string building. Use exec APIs taking an
  argument array; better still, do not shell out for what a library does.
- **Path traversal.** Any file access with a user-influenced name must resolve
  to an absolute path and verify the result is **under the allowed root**
  before opening. `../` is the obvious probe; also try encoded and
  double-encoded forms, and absolute paths.
- **SSRF.** A user-supplied URL fetched server-side needs scheme **and** host
  allowlists. Probe private ranges and the cloud metadata endpoint
  (`169.254.169.254`) specifically — that one turns an SSRF into credential
  theft.
- **Unsafe deserialization.** Never deserialize untrusted data with a format
  that can execute (pickle, Java native, YAML full loader). JSON plus schema
  validation.
- **Template/expression injection**, where user input reaches a template
  engine or expression evaluator rather than merely being rendered by one.

### 5c. Sessions and tokens

- **Session id regenerated on login** (and on privilege change). Without it,
  a fixation attack survives authentication.
- **Cookies:** `httpOnly`, `Secure`, `SameSite`.
- **Server-side revocation must be possible** — a token that cannot be
  invalidated is a token that outlives a compromise.
- **JWTs:** verify the signature **and** an algorithm allowlist. `alg: none`
  and algorithm-confusion (RS256 verified as HS256 against the public key) are
  the two classic bypasses; probe both.
- **Uniform failure.** Same message *and* comparable timing for wrong-email and
  wrong-password, with account state folded into the same query rather than
  checked afterwards — otherwise the difference enumerates accounts.
- **Rate limiting on auth endpoints**, keyed on both the identifier and the
  source address so one attacker cannot lock out a real user.

### 5d. File uploads

The deferred-forever check, and worth doing once properly:

- **Content type verified by magic bytes, not the extension** and not the
  client-supplied `Content-Type` header. Both are attacker-controlled.
- **Size limits** enforced server-side.
- **Stored outside the web root** or in object storage, never at an
  executable path.
- **Generated filenames**, so an upload cannot collide with or overwrite an
  existing file — and cannot be guessed.
- Probe: a valid image with a script appended, a file whose extension and
  magic bytes disagree, a filename containing `../`, and a zip bomb if archives
  are accepted.

### 6. Trust boundaries

For each, ask **what the server recomputes** versus what it accepts:

- **Totals and prices.** Must be recomputed server-side from stored data. The
  strongest form is structural: if the component has no price property at all,
  the framework cannot bind one — a stronger guarantee than validating it away.
- **Webhooks.** Signature-verified *and* CSRF-exempt by construction (registered
  outside the session middleware group) rather than by opt-out — an exemption
  that is structural cannot be accidentally undone.
- **Uploaded files.** Type, size, dimensions, and the stored filename.
- **Anything from a third party.** Amounts, currencies, and ids. Verify the
  amount *and* the currency; never fall back to the figure you yourself sent,
  which makes the guard compare your own number against itself.

### 7. Output escaping

Grep the entire view layer for the raw-echo syntax. The count should be zero,
or every instance justified and sanitised. Then verify **one case against
rendered output** (`input-abuse-techniques.md`, attribute breakout) — source
absence and rendered safety are different claims.

### 8. Mass assignment

Every model uses an allow-list (`$fillable`), never a deny-list. Confirm that
role/permission relationships are structurally unreachable from a create call.

### 9. Idempotency

Anything that must happen once (payment capture, redemption, status history)
should rest on a **UNIQUE constraint plus a caught violation**, never
check-then-act. Note that a check-then-act version will *pass its tests*
because the index backstops it — so the test proves the index, not the check.
Establish which half does what by removing each in turn.

### 10. Secrets, and where they leak

Check all five places, not just the repository:

- **Source and git history.** A secret that ever entered history is
  compromised — rotation is the only fix, not a later deletion commit.
- **Client bundles.** Anything in a frontend environment variable is public.
- **Logs.** Log ids, never payloads: no passwords, tokens, card numbers.
  Redaction is a launch blocker, not polish.
- **Error responses.** Stack traces and versions go to logs only; users get a
  generic message plus a correlation id. Confirm debug mode is off wherever it
  matters — and note which environment your check actually covered.
- **The example env file.** It must carry the required variable *names* and no
  real values, and must not contradict itself with two blocks for the same
  service.

### 11. Error handling as an information channel

An unhandled exception is two findings: the crash, and what the crash *shows*.

Probe every route parameter and form path for an unhandled failure, then read
the **response body**, not the status code. A debug page hands an anonymous
visitor the framework version, the internal directory layout, and proof of a
reachable crash to build on.

Note the shape: with debug off it degrades to a bare 500, which is *harder to
diagnose*, not safer. The finding is the crash underneath, not the leak.

## Resource exhaustion: abuse through logic the user is allowed to run

A class distinct from everything above, and easy to miss precisely because
nothing in it involves anyone doing something they are not permitted to do.
Every request is authorized, every input valid. What is unbounded is the
*cost*.

Ask of every public write: **what does a loop of this do, and what does it
hold while it does it?**

### The three questions

1. **Does it take a lock?** A row lock held on a contested resource turns a
   cheap endpoint into a way to serialise everyone else's work. Map them:
   which locks can an unauthenticated path reach, and what else waits on
   that row.
2. **Does it call out?** An external API on a public form means an attacker
   spends *your* rate limit and *your* latency budget, and a slow provider
   becomes your outage.
3. **Does it reserve something scarce?** Stock, a seat, a code, a slot. If
   so the question is not only how much one actor can take but **for how
   long it stays taken** — which is usually the half nobody bounded.

### The worked case: a cart that holds stock

An inventory-backed shop reserves stock when an order is placed, before
payment. Everything about that is correct. The abuse is:

- add the last unit of a product to a cart,
- reach the payment step, which reserves it,
- close the tab.

No account, no payment, no invalid input. The product is now unbuyable by
anyone. Repeat across a catalogue and the shop sells nothing.

Three separate bounds are needed, and having one or two is not enough:

| Bound | Without it |
|---|---|
| A cap on **distinct lines** per cart | Each line is a rendered row, an insert, and a lock at checkout — an unbounded cart makes every one of those arbitrarily expensive |
| A cap on **total units** per cart | One session reserves an entire product's inventory |
| A **TTL on the hold**, swept automatically | The reservation is permanent; the caps only set how much is taken, not for how long |

The third is the one usually missing, and it is the one that turns a
nuisance into a denial of service. Check for it explicitly: find where the
reservation is created, then find what releases it *when nobody returns*.
If the only release paths need the customer to come back and act, there is
no release path.

### The rule

**Rate-limit every public write that takes a lock or calls out**, and key
the limit on the actor, never on the value being submitted. Keying a
coupon-code limit on the code hands a guesser the full allowance *per
code* — the opposite of a limit. Put the throttle **before** the cheap
rejection branch, too: if the "unknown code" check returns first, the
enumeration path is the one path that was never limited.

### In review

- New public write → is it throttled? Keyed on what?
- Does it lock a row anyone else needs? Which?
- Does it reserve something scarce? What releases it if the user vanishes?
- Is there a cap on how much one session can accumulate — count *and*
  volume, which are different costs?

## Confirming a finding

**A static finding is a hypothesis until exploited.** Reproduce it live against
the running app before writing it up as real.

Make the reproduction **safe**: a rolled-back transaction proves the chain
without leaving the system changed.

```
DB::beginTransaction();
… grant the permission, perform the escalation, print the result …
DB::rollBack();
```

Then verify the state is unchanged afterwards and say so.

## Writing it up

Bug-bounty format, per `documentation-standards.md`. The section that pays for
the entry is **"Logic for future pentests"** — the generalisation. Name the
*class*, not the instance:

- "check-at-mount / use-later" — a check that runs where the id arrives but not
  where it is used.
- "an ability whose subject is the ability system" — reflexive permissions.
- "a rule the super-grant makes dead" — policy code that never executes.

## The per-change review checklist

The full review above is a pass over an existing system. This is the short
version to run on a single change touching a trust boundary:

1. **New input paths** → where is the validation, and what type is it after
   parsing?
2. **New queries** → parameterized? ownership in the `WHERE`?
3. **New endpoints** → auth required? authorization *per resource*?
   rate-limited if sensitive? Does it take a lock, call out, or reserve
   something scarce — and if it reserves, what releases it when the user
   never comes back?
4. **Anything secret touched** → in the manager, absent from logs, errors, and
   the client bundle?
5. **Escape hatches** (`raw`, `dangerously*`, `exec`, `eval`, `{!! !!}`) →
   each individually justified?
6. **Dependency changes** → audit clean, and is the new package's supply chain
   acceptable?
7. **Error paths** → do they leak internals?
8. **The question that catches most of it:** could user A read or modify user
   B's data through any new path?

Severity vocabulary: injection, authorization bypass, secret exposure, and
broken session handling are always blockers, never "should fix".

**Deny by default:** a new endpoint requires auth unless explicitly marked
public. The opposite default fails open every time someone forgets.

## Checklist

- [ ] Every route parameter classified (typed binding vs scalar)
- [ ] Every client-writable identifier property swept; non-findings recorded as a watch-list
- [ ] Ownership scoping present at the query, not only in the policy
- [ ] Every "nobody may do X" rule confirmed to live outside the super-grant's reach
- [ ] Package-namespace policies explicitly registered
- [ ] Reflexive permissions identified and guarded
- [ ] Totals/webhooks/uploads/third-party values recomputed or verified, not trusted
- [ ] Raw-echo count zero; one attribute-breakout case checked against rendered output
- [ ] Idempotency on a UNIQUE constraint, with each half's role established by removal
- [ ] Command injection, path traversal, SSRF, deserialization probed — not only SQL
- [ ] Session regeneration, cookie flags, JWT alg allowlist checked
- [ ] Uploads verified by magic bytes, stored outside the web root, names generated
- [ ] Secrets checked in all five places, including git history and client bundles
- [ ] An unhandled failure's response body read, not just its status code
- [ ] Every finding exploited live, safely, before being written up
