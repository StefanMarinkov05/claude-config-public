# Static analysis

The cheapest layer, and the one with the clearest boundary: it proves things
about the *shape* of the code and nothing about its behaviour.

## What it proves, and what it does not

| Tool class | Proves | Does not prove |
|---|---|---|
| Syntax check | The file parses | Anything |
| Formatter/linter | Style consistency | Correctness |
| Type analyser | Types line up across call sites | That the logic is right |
| Dependency audit | No known CVEs in installed packages | Your own code is safe |

**The standing warning: green static checks against wrong behaviour is the
most common shape of a real bug.** A function can have perfect types and return
the wrong answer. Never report "static analysis passes" as evidence a change
works.

## The gate

Run in this order — cheapest first, so a failure costs the least time:

```bash
<formatter> --test          # style; fails fast, fixes are mechanical
<type analyser> --level max # types
<test runner>               # behaviour
```

All three must be green before a change is considered done. A change that
passes tests but fails the formatter is not finished.

## Where static analysis genuinely earns its place in security

One case worth naming: a type analyser catches a **wrongly-typed or misspelled
security constant at compile time**. If a form references a validation constant
by name, the analyser refuses to compile a typo — which means a test asserting
"the right constant reached the right method" is redundant.

That is the correct division: let the analyser prove the wiring, and spend test
budget on behaviour it cannot reach.

## Traps

**Memory limits.** A type analyser's parallel workers can exhaust a container's
default memory limit and report a crash **in the same format as a real
finding** — e.g. `Found 1 error`. If a run reports exactly one mysterious
error, raise the limit before investigating the "finding."

**IDE diagnostics disagreeing with the container.** When dependencies live in a
container and not on the host, the editor will report framework classes as
undefined. These are noise. **The analyser running where the dependencies are
is the authority** — say so rather than chasing them.

**Baseline files.** A baseline suppresses existing errors so new ones surface.
It also silently hides real bugs forever. Review it periodically; a baseline
that only grows is a ratchet in the wrong direction.

**Regeneration that reports success and changes nothing.** Code generators can
report a successful run while leaving stale definitions in place. Verify the
output changed, not just the exit code.

## What to add beyond the defaults

- **Strict types** at the highest level the codebase can sustain.
- **A rule against debug statements** (`dd()`, `dump()`, `console.log`) so they
  cannot reach a finished branch.
- **Architecture tests**, where the toolchain supports them: "every class in
  `Actions/` has exactly one public method", "no controller references a model
  directly". These encode conventions that would otherwise rely on review.

## Checklist

- [ ] Formatter, type analyser, and tests all green
- [ ] Memory limit sufficient — a single unexplained error checked for this first
- [ ] IDE diagnostics not treated as authoritative when deps live elsewhere
- [ ] Baseline reviewed, not merely inherited
- [ ] Generator output verified to have changed
- [ ] Never reported as evidence that behaviour is correct
