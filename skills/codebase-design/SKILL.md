---
name: codebase-design
description: Designing deep modules - interface depth, seams, adapters, and testability-by-shape. Use when designing or improving a module's interface, deciding where an abstraction boundary goes, making code more testable, reviewing architecture for pass-through layers, or when another skill needs the deep-module vocabulary. Trigger for "how should I structure this", refactor planning, and any new module/service/class design.
---

# Codebase Design: Deep Modules & Seams

Design **deep modules**: lots of behavior behind a small interface, placed at a clean seam, testable through that interface. This is the module-level layer that sits between code-quality (line/function level) and api-design (service level). Use these terms exactly - consistent vocabulary is what lets multiple agents review each other coherently.

## Vocabulary (use these words, not synonyms)

- **Module** - anything with an interface and an implementation: function, class, package, or tier-spanning slice. Scale-agnostic on purpose. (Avoid: unit, component, service.)
- **Interface** - *everything a caller must know to use the module correctly*: signature, plus invariants, ordering constraints, error modes, required config, performance characteristics. Much wider than the type-level surface.
- **Seam** (Feathers) - the place where behavior can be swapped without editing that place; where the interface lives. Where the seam *goes* is its own design decision. (Avoid: boundary - collides with DDD.)
- **Adapter** - a concrete thing satisfying an interface at a seam (Postgres repo, in-memory fake). Names the role, not the substance.
- **Depth** - leverage at the interface: behavior a caller or test can exercise per unit of interface learned. Deep = small interface, large behavior. Shallow = interface nearly as complex as the implementation (pass-through layers, getter/setter shells, "manager" classes that forward).

## Principles

- **Depth is a property of the interface, not the implementation.** Internals can be small composed parts with their own private seams for testing - they're just not part of what callers must learn.
- **The deletion test**: imagine deleting the module. If complexity vanishes → it was a pass-through, delete it for real. If complexity reappears smeared across N callers → it was earning its keep.
- **The interface is the test surface.** Tests and callers cross the same seam. Wanting to test *past* the interface means the module is the wrong shape - fix the shape, don't add test backdoors.
- **One adapter = hypothetical seam; two adapters = real seam.** Don't introduce indirection for variation that doesn't exist yet - this is rule-of-three (code-quality) applied to architecture. The common second adapter that justifies a seam: the in-memory fake used by tests.
- **Different layer, different abstraction.** If a layer's interface restates the layer below with the same terms and shape, it's shallow - collapse it.
- **Define errors out of existence** where possible: an interface whose contract makes the error case unrepresentable (e.g., `deleteIfExists` vs `delete` that throws on missing) is deeper than one that exports the edge case to every caller.

## Designing for testability (shape, not tooling)

1. **Accept dependencies, don't create them** - the module receives its gateway/clock/random at the seam; tests hand in fakes. Constructing dependencies inside is what forces mock gymnastics.
2. **Return results, don't produce side effects** - `calculateDiscount(cart): Discount` is trivially testable; `applyDiscount(cart): void` mutating in place isn't. Push effects to the edges (same rule as code-quality's dependencies-point-inward, seen from the test's side).
3. **Small surface** - fewer methods and params = fewer tests needed and simpler setup. Interface size is a testing-cost multiplier.

Prefer **replacing adapters at the seam over layering mocks inside**: a real in-memory implementation of the interface beats a pile of per-method mocks (which couple tests to implementation - see tdd skill's anti-patterns).

## Design-it-twice

For any non-trivial interface, sketch **two radically different shapes** before choosing (different decomposition, not cosmetic renames), then compare on: interface size a caller must learn, where change concentrates when requirements shift, and whether tests need to reach inside. The first design is rarely the deepest; the second costs ten minutes and frequently wins. In agent pipelines: give two implementer agents the same contract-design task independently and have the reviewer compare - cheap parallel design exploration.

## Review checks (plug into code-review G3)

1. Any module failing the deletion test? 2. Any interface exporting its implementation (leaking internal types, requiring calls in a secret order)? 3. Any seam with exactly one conceivable adapter, ever? 4. Do tests go through interfaces, or reach inside? 5. Could this interface absorb the most likely next requirement without changing shape?
