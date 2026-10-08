# Input abuse techniques

What to actually send at every input a client controls, and why each case
matters. This is the highest hit-rate technique in the whole suite — it found
four separate crashes of the same class in one codebase, plus a silent
wrong-answer bug that a passing test had been covering for.

## Why the browser's constraints do not apply

`<input type="number" min="1" max="99">`, a `maxlength` attribute, a
`<select>`'s fixed options — none of these are enforced by anything but the
browser rendering the form. Three ways around all of them, in increasing order
of realism:

1. **DevTools.** Edit the attribute, submit through the normal UI.
2. **The URL**, for any query-bound property. No browser involved.
3. **`curl`, or a component test.** Bypasses the browser entirely. This is the
   realistic path — an attacker is not clicking spinner arrows, they are
   sending a request.

**A disabled or hidden control is not security.** A disabled field is not
submitted, which means a test driving the UI can pass with the server-side
guard deleted, because the payload never carried the field. Target the seam a
crafted request reaches — the mutate hook, the Action, the endpoint.

## The value playbook

Try each against **every** property a form, filter, or endpoint exposes,
regardless of whether it looks numeric, textual, or enum-like.

| Value | What it catches |
|---|---|
| A number past the language's int range (`99999999999999999999999999999999`) | Crashes a strictly `int`/`float`-typed property at the framework's **hydration** step, before any validation runs. String-typed properties are structurally immune. |
| A number within range but past the column's range (MySQL `int`: ±2.147 bn) | Should be caught by a domain check before the `INSERT`. A raw driver exception means the check is missing or on the wrong side of a boundary. |
| A malformed numeric-shaped string (`100..0`, `1e400`, `+-5`) | Whatever accepts "numeric-looking" input must reject cleanly, not cast to garbage. |
| A negative number where none makes domain sense | Must be refused, not partially applied. |
| A decimal where a whole number is expected (`3.5` quantity) | Reject; do not silently floor unless that is documented behaviour. |
| Empty string, `null` | Must mean "not applied", never `0` or the string `"null"`. |
| **A nested array** (`?ids[0][0]=1&ids[0][1]=2`) | Type-juggling: `intval()` of a non-empty array is **`1`**. Produces a *valid* value, not a crash. See below. |
| `<script>alert(1)</script>` | Confirms output escaping runs on every path the value reaches. |
| `" onmouseover="alert(1)` | **Attribute breakout** — see below. Different from the above and needs its own check. |
| `' OR '1'='1`, `'; DROP TABLE x;--` | Structural. With parameter binding this should have *zero* effect. If it changes behaviour at all, that is the finding. |
| A string thousands of characters long | `varchar(N)` throws if nothing validates length. Check the column length against the validation rule — do not assume they agree. |
| A value outside a fixed set (a sort column not in the allow-list) | Anything reaching `ORDER BY`, `whereIn()`, or similar structural use needs an allow-list, not merely "is a string". |
| Unicode, emoji, RTL overrides, null bytes | Encoding assumptions, column charset, log injection. |

## Attribute breakout — the `value=""` case

Distinct from ordinary XSS and easy to miss, because the payload contains no
`<script>` at all. It closes the attribute's own quote and opens a new one:

```
?search=" onmouseover="alert(1)
```

If the value is echoed into `value="{{ $search }}"` without escaping, the
rendered HTML becomes:

```html
<input value="" onmouseover="alert(1)"">
```

— a working event handler, with no tag injection required.

**How to check it properly.** Do not read the template and conclude it's safe.
Fetch the **rendered response** and grep for both forms:

```bash
curl -s 'http://localhost:8080/catalogue?search=%22%20onmouseover%3D%22alert(1)' \
  | grep -c 'onmouseover="alert(1)"'   # working form — must be 0
curl -s 'http://localhost:8080/catalogue?search=%22%20onmouseover%3D%22alert(1)' \
  | grep -c '&quot; onmouseover'       # escaped form — should appear
```

Zero of the working form and non-zero of the escaped form is the pass. This
checks output, not source — which is the point, because a template can be
correct and a helper further down can still emit raw.

**Note the asymmetry:** a value appearing escaped inside an HTML attribute is
expected and fine. Only unescaped appearance is the finding.

## URL / route-parameter injection

Every route parameter is untrusted input, and they differ sharply in risk:

- **A typed model binding** (`{product:slug}`) is structurally immune — a bad
  value never reaches your code; the framework 404s first.
- **A plain scalar parameter** (`{order}`) reaches your code as whatever was
  sent. If the signature says `int` and the value is `abc`, that is an
  unhandled type error *before* any of your logic runs.

**Sweep every route parameter in the route file, not just the one you
suspect.** In one real sweep, of every parameter in the file, exactly one was a
plain scalar — and that was where the only finding was.

Test each with: a valid id, a nonexistent id, a non-numeric string, a negative
number, an oversized number, and an id belonging to **another user** (the IDOR
case — see `security-review.md`).

## The second class: not a crash, a silently wrong answer

The playbook above catches crashes. It does **not** catch this, and neither did
an existing test written for exactly this input.

A property was already loosely typed, so nothing crashed. The bug was that
`intval()` of a non-empty array is `1` — so a nested array didn't degrade into
a harmless non-matching id, it **collapsed onto the real, filterable id `1`**
and applied that filter. A visible chip appeared for a filter the visitor never
selected; 164 products became 37.

The existing test asserted `assertOk()` and nothing more. The input was right;
the assertion was too weak. **A wrong answer returns 200.**

Two rules:

- **For any value reaching a query, assert the resulting set**, not the status
  code.
- **Casting is a per-reader decision — put it in one place.** Four readers each
  cast for themselves and diverged; only one filtered on `is_numeric` first.
  One shared `safeX()` method called by every reader closes both this and the
  hydration-crash class.

## Timing: hooks that do not fire

A framework's `updated{Property}()`-style hooks **never fire on first page load
from URL hydration.** Validation living only in such a hook is bypassed
entirely by a crafted first request.

This is the same timing that makes the hydration-crash class possible: the
value is assigned to the property *before* any of the component's own code
runs. Normalisation must happen where every read passes through — a shared
accessor, or the mount/boot step — not in a hook that fires only on
interaction.

## The lesson that cost four bugs: this is per-property

The same root cause was found **four separate times** in one codebase, across
three sessions:

1. A quantity property — crashed at hydration on an oversized number.
2. A variant-id property on the *same component* — crashed the same way,
   found only because the first fix prompted checking its neighbour.
3. A brand-id property on a *different* component that had already been
   reviewed for this exact bug class — because the property reviewed was a
   string (structurally immune), and that clean result said nothing about the
   numeric property two lines below it.
4. A category-id property, same shape again.

**A "nothing found" result on one property does not transfer to another
property, even on the same component, even in the same class.** The playbook is
per property.

**And: after the third instance, stop fixing one at a time.** Grep every
client-bound property in the codebase for a strict numeric type in one pass.
Three separate discoveries of one root cause is a pattern a systematic sweep
would have caught in one sitting.

## Running it

`ComponentTest::set('property', $value)` is the same class of check as `curl`,
faster and easy to keep as a permanent regression test. Use `curl` first when
you are still establishing whether the app is reachable in the state you
expect; switch to component tests once you know which value to send.

For each finding, write the regression test **and prove it red** by reverting
the fix (`test-quality.md`).

## Checklist

- [ ] Every client-bound property enumerated — including ones added since the last pass
- [ ] Full value playbook run per property, not per component
- [ ] Attribute-breakout checked against **rendered output**, both forms counted
- [ ] Every route parameter swept; scalars distinguished from typed bindings
- [ ] Nested-array / type-juggling case included
- [ ] Assertions check resulting data, not status codes
- [ ] Normalisation confirmed to run on first load, not only in interaction hooks
- [ ] Findings logged per property in a running inventory
