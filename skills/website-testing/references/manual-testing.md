# Manual and exploratory testing

Driving the application as a person would, looking for what nobody thought to
automate. This finds the bugs the test suite's author never imagined — which is
most of the interesting ones.

Its weakness is the mirror image: nobody re-runs it. **Every manual finding
worth keeping becomes an automated test.**

## The difference from scripted testing

Scripted testing verifies known expectations. Exploratory testing *generates*
expectations by interacting with the system and noticing what surprises you.

The discipline is in the noticing. Three habits:

- **Read the console on every page.** Establish the baseline first
  (`ui-testing-mcp.md`); anything beyond it is a finding.
- **Check the server-side record, not the rendered page.** After submitting a
  form, count the rows. A page saying "thank you" is not evidence anything was
  stored — nor that only *one* thing was.
- **Notice what is absent.** A missing related-products section, a missing
  review form, a spec'd page that 404s. Absence never throws an error, so only
  a person comparing against the specification finds it.

## Structuring a pass so it is repeatable

Ad-hoc clicking produces findings that cannot be reproduced. Give each pass:

1. **A stated scope.** "Every storefront page a customer reaches", "the admin
   panel's destructive actions", "what an unhandled failure shows an anonymous
   visitor". A pass with unlimited scope finishes nowhere.
2. **A fixed environment**, recorded — data volume, seeded state, roles used.
3. **A per-page procedure.** Navigate → screenshot → read console → abuse
   every input → verify the server-side record.
4. **A dated write-up** with an honest "not covered" section
   (`documentation-standards.md`).

**One file per pass, not one growing file.** A record appended to forever loses
its date and a reader cannot tell which claims are current.

## Useful pass shapes

Different framings surface different bug classes. Worth running as separate
passes rather than one sweep:

| Pass | Question | Typically finds |
|---|---|---|
| **Storefront click-through** | Does every page a customer reaches work? | Rendering, interaction, missing pages |
| **Admin-created bad data** | What does the *customer's* browser do with data an admin can legitimately create? | Rendering gaps, missing fallbacks |
| **Error-leak sweep** | What does an *unhandled* failure show an anonymous visitor? | Debug traces, leaked paths, crash classes |
| **Panel click-through** | Do the admin's own forms and destructive actions behave? | Failure-shape defects, authorization gaps |
| **Role denial** | Can each role reach only what it should? | Authorization holes |

The second is worth expanding, because it is the least obvious: the
specification says an administrator can create products; it says nothing about
*bad* products. Create genuinely broken data **through the real Actions the
admin UI calls** — not a factory shortcut, which bypasses the very code under
test — and watch what the customer sees.

That pass found a real bug: a record existing is not a promise the file it
points at exists. Code branching on "does a record exist" rather than "is the
referent usable" rendered a browser's broken-image icon on three surfaces, and
the cart's own fallback helper did not save it.

## Testing what you cannot see

**Absence needs a different technique.** To check whether a spec'd page exists,
request it directly rather than looking for a link:

```bash
for p in /delivery /payment-information /terms /privacy /cookies; do
  printf '%s %s\n' "$p" "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:8080$p")"
done
```

Inferring from the route file is weaker — a route can exist and its view can
fail to render.

## Verifying, not trusting

- **Read the DOM after an interaction**, not the screenshot. "The price
  updated" is a claim; the element's text is evidence.
- **Confirm the count server-side.** After a form submission, check the row
  count changed by exactly one. Honeypot and rate-limit behaviour is invisible
  from the page.
- **A graceful result is a result.** Record what held, not only what broke —
  "no image, placeholder rendered correctly on all three surfaces" is a finding
  worth keeping, because it stops the next person re-testing it.

## Turning findings into tests

Every manual finding gets triaged into one of:

- **A regression test**, if it is a defect — written, proven red, then fixed.
- **A documented gap**, if it is real but out of scope — recorded with why.
- **A recorded negative**, if it held — so nobody re-runs it.

A manual pass whose findings are not written down has to be run again from
scratch, which is the entire cost of the technique with none of the benefit.

## Checklist

- [ ] Scope stated and bounded before starting
- [ ] Environment and data volume recorded
- [ ] Console baseline established; deltas treated as findings
- [ ] Server-side record checked, not the rendered confirmation
- [ ] Absent pages checked by direct request, not inferred from routes
- [ ] Bad data created through real Actions, not factory shortcuts
- [ ] Findings triaged into test / gap / recorded-negative
- [ ] Dated write-up with a specific "not covered" section
