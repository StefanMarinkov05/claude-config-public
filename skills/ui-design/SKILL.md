---
name: ui-design
description: Stefan's UI, visual, and frontend-aesthetic layer. Use whenever Stefan builds a website, landing page, component, or any visual/interactive frontend, or asks for animations, 3D models/scenes, high-end CSS/JS, or modern Figma-style design. Also use when he wants paste-ready prompts to generate UI in Claude Code. Modern, entertaining, responsive, motion-rich work. Pairs with coding-standards for the underlying code, but owns all visual/animation decisions.
---

# UI Design

Stefan's aesthetic layer: modern, Figma-style, entertaining, motion-rich, responsive, high-end CSS/JS with 3D where it earns its place. For deep aesthetic direction (palette/type/signature/self-critique process, and the current anti-generic checklist) load the `frontend-distinctive-design` skill FIRST - this skill adds Stefan's stack, defaults, and prompt-generation on top. Do not restate that skill's checklist here; it rotates as new AI-design tells emerge, so a copy here would silently go stale.

## Aesthetic direction (Stefan's defaults)
- Modern Figma-style: generous whitespace, confident type scale, soft depth (layered shadows/glass where appropriate), crisp grid, intentional accent color per project
- Entertaining and alive: motion is a first-class material here, not decoration - but per frontend-distinctive-design, an orchestrated moment beats scattered effects, and over-animation reads as AI-generated. Spend boldness in one signature place
- Responsive to mobile as a floor, not an afterthought; visible keyboard focus; motion respects the user's reduced-motion preference (motion-rich does NOT mean motion-forced)
- Run frontend-distinctive-design's anti-generic checklist before writing CSS - do not rely on memory of it here

## Technical stack for motion & 3D
- **Animation**: Framer Motion (React) for component/layout/gesture animation and orchestrated sequences; GSAP + ScrollTrigger for timeline and scroll-driven work; CSS transforms/transitions for cheap micro-interactions (hover, focus). Prefer transform/opacity (GPU-composited) over layout-triggering properties
- **3D**: React Three Fiber + drei (React) or raw Three.js; model loading via glTF/GLB (draco-compressed), `useGLTF`/loaders; lazy-load and code-split 3D so it never blocks first paint; provide a static/reduced fallback for reduced-motion and low-power devices
- **Performance discipline**: 3D and heavy animation are the biggest perf risks - budget them. Lighthouse-conscious: defer offscreen 3D, compress textures, cap devicePixelRatio, dispose geometries/materials, throttle scroll handlers. A beautiful site that janks is a failed site
- In Claude artifacts (React), Three r128 constraints apply (no OrbitControls, no CapsuleGeometry - use documented alternatives)

## Environment build rules
- Read `frontend-distinctive-design` for the plan-first process (token system → critique against defaults → build → self-critique)
- Watch CSS specificity collisions (type vs element selectors canceling padding/margins) - a known trap
- Single-file where the target is an artifact; component structure per coding-standards for real projects (heavy pedagogical comments still apply - Stefan learns from and briefs agents with the code)

## PASTE-READY UI PROMPT GENERATOR

When Stefan wants to generate UI in Claude Code / another chat, produce a complete prompt he can paste. Good UI prompts are specific about subject, mood, motion, and constraints - vague prompts yield the templated defaults. Template:

```
Build [component/page]: [one-line subject + its single job].

Aesthetic: [modern figma-style / specific direction]. Palette: [4-6 named hex or a described direction]. Type: [display face + body face + role]. Signature element: [the one memorable thing].

Motion: [specific - e.g. "page-load stagger on hero, scroll-triggered reveal on sections, hover lift on cards"; name the library: Framer Motion / GSAP]. Respect prefers-reduced-motion.

3D (if any): [what, where, why it earns its place]. R3F + drei, glTF, lazy-loaded, static fallback.

Stack: [Next.js 14 / React / plain HTML]. TypeScript strict. Responsive to mobile. Visible focus states. Heavy explanatory comments (I learn from and brief agents with this code).

Do NOT: ship the current AI-default look clusters (check frontend-distinctive-design's anti-generic checklist for the current list - it rotates); over-animate; block first paint with 3D.
```

Fill every bracket from the actual brief before handing it over - an unfilled template produces generic output. If the brief is thin, ASK the 1-3 questions needed to fill subject/mood/signature first (elicitation pattern).

## Ask-first
Visual work is subjective - if mood, brand, or the single signature idea is unspecified, ask before building rather than defaulting. One good clarifying round saves a full rebuild.

## Interaction
- Underlying code quality, data, agents → coding-standards
- The pedagogical-comment rule and secrets rules carry over from coding-standards
- Aesthetic process depth and the anti-generic checklist → frontend-distinctive-design
