---
name: design-review
description: Compare the Skintel iOS implementation against the final design spec (designs/skintel-ios-designs.html + previews) for layout, typography, spacing, colour, components, states, motion, native behaviour and accessibility. Fixes obvious fidelity gaps; documents subjective redesigns in DESIGN_REVIEW.md instead of applying them.
---

# /design-review

Sources of truth: `designs/skintel-ios-designs.html` (18 surfaces, `#s-*` anchors), `designs/previews/*.png`,
tokens in `designs/README.md`. Where the design and the shipped product disagree, `MIGRATION_MAP.md` §Conflicts
already decided — don't reopen those.

For each surface (splash, ob1–3, login, home, scan, found, verdict, product, compare, routine, journal, culprits,
paywall, settings) compare the SwiftUI view to the preview, in this priority:
1. layout · 2. typography (Instrument Serif / DM Sans / JetBrains Mono, sizes from `SKFont`) · 3. spacing (`SKSpace`) ·
4. colour (`SKColor`) · 5. components (`SKCard`, `SKChip`, `SKButton`, ring, tab bar) · 6. imagery/iconography ·
7. navigation · 8. animation (`SKAnimation.ios/emil`, Reduce Motion) · 9. sheets · 10. loading · 11. empty · 12. error ·
13. native behaviour (keyboard, safe areas, Dynamic Type) · 14. accessibility (labels, traits, 44pt targets, contrast).

Classify every gap:
- **Clear fix** (wrong size/colour/spacing, missing state, bad tap target) → fix it, note the file.
- **Subjective** (layout or copy that departs from the spec on purpose) → append to `DESIGN_REVIEW.md` with
  current behaviour, proposed change, reason, expected benefit. Do not implement.

Finish with a table: surface · fidelity (high/medium/low) · fixed · deferred.
