---
name: frontend-distinctive-design
description: Distinctive, professional frontend design that avoids generic templated aesthetics. Use whenever building or restyling any UI - websites, landing pages, dashboards, web apps, components - or when the user asks for design direction, says something "looks generic/boring/like AI made it", or wants a UI to feel premium, delightful, or memorable. Applies to HTML/CSS, React, and any frontend stack. Trigger for every task with a visual deliverable, not only explicit design requests.
---

# Distinctive Frontend Design

Generic UI comes from defaulting on every axis at once. Distinctive UI comes from a deliberate concept executed consistently. Professionalism comes from restraint: few decisions, strongly committed.

**Pairs with `ui-design`, the other half.** This skill is the transferable craft — concept, the rotating anti-generic checklist, type/colour/layout discipline, self-review. `ui-design` adds Stefan's own stack and defaults on top: Framer Motion / GSAP / React Three Fiber, artifact constraints, the ask-first rule, and a paste-ready UI prompt generator. **Building something for Stefan: load both, this one first.** A general design question, or someone else's stack: this one alone.

Kept separate deliberately — the checklist below *rotates* as AI-design tells move, and a copy inside a stack-preferences file would go stale silently. The two halves change at different rates.

## Step 1 - Pick a concept before writing CSS

Write one sentence: "*This interface feels like ___ because the user is ___*" (e.g., "a well-organized lab notebook, because the user is analyzing experiments"). Every subsequent choice (type, color, spacing, motion) must serve that sentence. No concept → templated output, guaranteed.

Derive a direction from the domain, not from fashion: a finance tool can borrow from ledgers and print typography; a music app from album art and stage lighting; a dev tool from terminals and blueprints. Steal from adjacent physical/print worlds - that's where distinctiveness lives, since every web app already looks like every other web app.

### Step 1b - Audit the plan before writing code

Work in two passes, and put a gate between them. First write a compact plan, not prose: **Color** (4-6 named hex values), **Type** (the faces and their roles), **Layout** (one or two sentences, plus an ASCII wireframe if comparing options - include alignment: left, centered, justified), **Principles** (what makes this page specifically this page).

Then, before any CSS: **re-derive the plan from a generic version of the same brief and see whether you land somewhere similar.** If you would have produced this same palette and type pairing for any dashboard / any landing page / any shop, that part is a default wearing the brief's clothes. Revise it, and say what changed and why.

This is the same discipline as a verification gate: the check has to be capable of failing. A plan that "looks distinctive" without that comparison has not been audited, it has been admired. Only once the plan survives it should code start - and then the code follows the revised plan, not the original.

## Step 2 - The anti-generic checklist (the "AI-slop" tells to avoid)

Never ship all the defaults together. The recognizable template is: Inter/system font + purple-to-blue gradient + centered hero + three feature cards with icons + rounded-2xl + soft shadows + emoji bullets. Break at least type, color, and layout away from it:

**The tells rotate - these are the current cluster.** The list above is the older generation; recognizing only it is how you ship the newer one. As of now, generated design also clusters around:
1. Warm cream ground (near `#F4F1EA`) + high-contrast serif display + terracotta/warm-clay accent (often near `#D97757`, which is Claude's own interaction accent - on a user's brief it reads as a tell).
2. Near-black ground with one bright acid-green or vermilion accent.
3. Broadsheet layout: hairline rules, zero border-radius, dense newspaper columns.
4. The SaaS-card kit: identical rounded cards, one radius on everything regardless of hierarchy, the same `rgba(0,0,0,.1)` shadow under each, gradient washes as decoration.
5. **Template chrome that appears whatever the subject** - the most reliable tell, because it is subject-independent: a tracked-out ALL-CAPS eyebrow above every heading; meta strings joined with middle dots (`A · B · C`); labels built as `WORD — fragment` with a spaced em dash; tinted near-black (`#0B0B0B`, `#111`) standing in for black; a monospace face for small data labels; `→` appended to link and button text.

All of these are legitimate for *some* brief. They are defaults rather than choices when they show up regardless of subject. Where the brief pins an axis down, follow it exactly - the brief's words always win, including when it asks for one of these looks. Where it leaves an axis free, don't spend that freedom on a default.

Three typographic habits worth naming separately, since they survive even a deliberate palette:
- Accenting a single word in a headline (one word italic/bold/colored).
- ALL CAPS for every label.
- A typographic label added above content that did not need one.

- **Type**: never default-stack-only. Pick one distinctive display face + one workhorse text face (pairing contrast: serif+sans, mono+sans, high-contrast weights). Real typographic scale (e.g., 1.25 ratio), tight leading on headlines (1.05-1.15), generous on body (1.5-1.7). Type does more for distinctiveness per byte than anything else.
- **Color**: one committed accent + a disciplined neutral ramp beats a gradient. Neutrals should be tinted toward the accent (warm/cool), not pure gray. Check contrast (WCAG AA minimum, 4.5:1 body). If using gradients at all: subtle, same-hue-family, never purple-on-white hero.
- **Layout**: not everything centered. Use asymmetry, a real grid (12-col or a deliberate editorial grid), generous whitespace as a feature, and at least one confident large element (oversized headline, big number, full-bleed image). Density should match the domain - dashboards earn density, marketing earns air.
- **Depth & borders**: pick one language - flat with hairline borders, OR soft layered shadows, OR neo-brutalist hard offsets - and use it everywhere. Mixed depth languages read as templated.
- **Details**: consistent corner radius scale (pick 2 values, not 5), real icons from one set at one stroke weight, no emoji as UI, custom empty/loading/error states (these are where "delight" actually lands, because nobody expects effort there).

## Step 3 - Motion & delight, professionally

- Motion has a job: orient (where did that come from), confirm (it worked), or reveal hierarchy. Decorative-only motion is noise.
- 150-250ms for micro-interactions, ease-out for entrances, ease-in for exits; spring physics only for playful brands. Everything respects `prefers-reduced-motion`.
- One signature moment per app maximum - a memorable transition or hover on the core action - executed superbly. Ten animations at 70% feel worse than one at 100%.
- Hover/focus/active states designed for every interactive element (focus visible - keyboard users exist; it's also a professionalism tell).

## Step 4 - System, not vibes

Encode decisions as tokens (CSS custom properties / theme object): color ramp, spacing scale (4 or 8px base), type scale, radii, shadows, durations. All values in components come from tokens - that's what makes the design *coherent*, and coherence is what reads as professional.

Components own their states: default, hover, focus, active, disabled, loading, error, empty. A component missing states is half a component.

**Watch selector specificity when writing the CSS.** It is easy to generate classes that silently cancel each other - a type-based selector (`.section`) fighting an element-based one (`.cta`) over the padding and margin between sections. The symptom is spacing that is right in isolation and wrong in composition, and it hides in the gap between source and rendered output. Structure the cascade so it does not undo your own spacing, and check the rendered result rather than trusting the stylesheet.

## Non-negotiable professional baseline

Semantic HTML (nav/main/button - not div-with-onclick), keyboard operability, visible focus, alt text, contrast AA, responsive from 320px up (design mobile and desktop as first-class, not desktop-shrunk), text zoom to 200% without breakage, real content tested (long names, empty lists, 0 and 10,000 items).

## Self-review before shipping

1. Cover the logo - could this be any product, or only this one? 2. Name the concept sentence - does each screen serve it? 3. Squint test - clear hierarchy: one primary action per view? 4. The template test - how many items from the anti-generic checklist did I actually break from? 5. Tab through it - fully keyboard usable? 6. Does the empty state show as much care as the hero?
