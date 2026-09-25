# SkinstelMascot

Skinstel's terracotta droplet as a native SwiftUI component. It is drawn with `Canvas`
from an editable vector rig and animated in code: no GIF, video, Lottie file, sprite sheet
or network call. Feet, arms, eyes, mouth, body and the serum bottle are separate parts,
each moving around its own pivot.

## Use

The package is linked to the `Skintel` app target through `ios/Skintel/project.yml`.

```swift
import SkinstelMascot

// Drive the action from real app state; keep real status text beside it.
HStack {
    SkinstelMascot(action: isAnalyzing ? .scan : .idle)
        .frame(width: 66, height: 80)
    Text("Reading 24 ingredients…")
}

// Walk back and forth across the spare width.
SkinstelMascot(action: .walk, travels: true)
    .frame(maxWidth: .infinity)
    .frame(height: 160)

// Kept alive but off screen (a page in a paged TabView, a retained tab): pause it.
SkinstelMascot(action: .wave, isPlaying: page == 0)
```

| Parameter | Default | Effect |
| --- | --- | --- |
| `action` | `.idle` | What the mascot is doing. Loops until you change it. |
| `isPlaying` | `true` | `false` pauses on the current pose. |
| `travels` | `false` | With `.walk`, walks across the frame's spare width and turns at the edges. A frame no wider than the character walks in place. |
| `facingLeft` | `false` | Mirrors the character. |
| `playbackID` | `0` | Change it to restart the current action from the beginning. |

The character keeps its 420 × 510 proportions (width ≈ 0.82 × height) and is centered in
whatever frame you give it.

## Actions

| Action | Motion | Reduce Motion pose | Use for |
| --- | --- | --- | --- |
| `.idle` | Breathing, blinking | Standing, eyes open, smiling | Resting companion |
| `.wave` | Right arm raised and waving | Right arm raised | Welcome, first run |
| `.walk` | Alternating steps, arm swing, bounce | Standing, feet together | Moving between moments |
| `.serum` | Hugs the serum bottle, breathing | Holding the bottle | Shelf, product moments |
| `.scan` | Holds the bottle; a green line sweeps it inside a scan frame | Line resting mid-bottle, frame shown | Analysis in progress |
| `.thinking` | Hand to cheek, eyes up, three thought dots fading in turn | Hand to cheek, dots at even opacity | Waiting for an answer |
| `.celebrate` | Both arms up, hop, happy eyes, sparkles | Arms up, happy eyes, sparkles | A real success only |
| `.sleep` | Eyes closed, small mouth, a "z" drifting up | Eyes closed, "z" beside the head | Evening, rest |

`.thinking` and `.sleep` are additions to the original five. Like the rest they are
vector parts of the same rig and have a stable Reduce Motion pose.

Actions change instantly. When a moment should be brief (a celebration, a greeting), the
host decides when to switch back to `.idle`.

## Behavior

- **Honest state.** The mascot never shows progress. `.scan` loops for as long as the host
  says work is happening, so pair it with the real status text. Use `.celebrate` only after
  something really succeeded.
- **Accessibility.** The whole view is `accessibilityHidden(true)`. It adds no VoiceOver
  element, so the text beside it carries the meaning.
- **Reduce Motion.** The clock stops and each action shows its still pose (table above).
  Travel, blinking, bobbing and drifting effects stop.
- **Pausing.** The `TimelineView` runs at up to 30 fps and pauses when the view disappears,
  when the scene isn't active, when `isPlaying` is `false`, and under Reduce Motion. Pausing
  keeps the elapsed time, so resuming continues from the same pose.
- No sound or haptics.

## Editing the art

`Sources/SkinstelMascot/Resources/MascotRig.json` holds everything visual:

- `paths` — SVG path data for each part (absolute `M`, `L`, `C`, `Q`, `Z` only).
- `ellipses` — eyes, blush, shadow, sleep mouth and thought dots as `[cx, cy, rx, ry]`.
- `pivots` — the `[x, y]` each foot, arm, the body and the bottle rotate around.
- `armRaise` — how far a shoulder shifts out of the body when that arm is raised.
- `colors`, `opacity`, `strokeWidths`, `outlineWidth` — the terracotta and cream palette,
  outline ink and line weights.
- `bottleTilt`, `bodyGradient`, `scanLine`, `scanTravel`, `sparkleOrbit`, `sleepZStart`.

The rig is read once at first use. Keep every part name; `MascotArt.missingParts` lists
any the renderer needs that the JSON lacks, and debug builds assert on them.

After editing, rebuild the browser preview (below) to check the result without Xcode.

## Files

- `Sources/SkinstelMascot/SkinstelMascot.swift` — the public view and the Canvas renderer.
- `Sources/SkinstelMascot/MascotPose.swift` — `SkinstelMascotAction` and the motion formulas.
- `Sources/SkinstelMascot/MascotRig.swift` — rig model and SVG path parser (Foundation only).
- `Sources/SkinstelMascot/MascotPlayground.swift` — every action with controls, for previews.
- `Sources/SkinstelMascot/Resources/MascotRig.json` — the editable rig.
- `designs/mascot-animation/preview.html` (repo root) — interactive browser preview built
  from the same JSON with the same formulas. Rebuild with
  `python3 designs/mascot-animation/build_preview.py`; check with
  `node designs/mascot-animation/validate_preview.cjs`.

## Scope

The character is a front-facing 2D rig, not a 3D model. The art is adapted from the
supplied Skinstel character with smooth vector fills in place of its paper texture.
