# Skinstel animated companion

A native SwiftUI vector rig inspired by the supplied terracotta droplet character. This is executable animation code, not a sprite sheet or an animated image. It keeps the serum bottle, outline, blush, smile and droplet silhouette, with a simplified vector finish rather than the original painted texture.

## Add to the iOS app

1. In Xcode choose **File → Add Package Dependencies → Add Local**, then select this `SkinstelMascot` folder.
2. Add the `SkinstelMascot` library product to the native app target.
3. Import the module and place the view where wanted. The package bundles its vector rig automatically. No asset catalog setup, external service, API key or paid animation runtime is required.

```swift
import SkinstelMascot

// Walking feet, staying in one place — e.g. beside loading text.
SkinstelMascot(action: .walk)
    .frame(width: 120, height: 150)

// Walk across the available space and turn at the edges.
SkinstelMascot(action: .walk, travels: true)
    .frame(maxWidth: .infinity)
    .frame(height: 180)

// Bind to real app state. The mascot does not invent scan progress.
SkinstelMascot(action: isScanning ? .scan : .idle,
               isPlaying: isScreenVisible)
    .frame(width: 100, height: 125)

// Try every action in a self-contained preview.
MascotPlayground()
```

## Actions and behavior

| Action | Movement |
| --- | --- |
| `.idle` | Gentle breathing and blinking |
| `.walk` | Alternating leg rotation, body bob and slight sway |
| `.wave` | Right arm lifts and waves; left hand holds the bottle |
| `.scan` | Gentle body tilt and a scan line across the bottle |
| `.celebrate` | Small hop, lifted arm and sparkles |

`travels` only affects walking. `facingLeft` mirrors the character. `isPlaying` pauses at the current pose. The component pauses when its scene is inactive or it disappears. For a view retained invisibly by a tab or carousel, pass `isPlaying: false` yourself. Reduce Motion shows a static character with no walking displacement, blinking or bobbing. There are no sounds or haptics.

The artwork uses a 320 × 400 coordinate space and scales to fit. Travel needs a frame wider than the character; a narrow frame naturally gives walking in place. The timeline renders at up to 30 fps. The character is decorative and hidden from VoiceOver: put descriptive text such as “Reading ingredients…” beside it. Stop `.celebrate` or change it to `.idle` when the host's success moment ends.

## Files

- `Sources/SkinstelMascot/SkinstelMascot.swift`: public component, motion formulas, vector renderer and playground.
- `Sources/SkinstelMascot/Resources/MascotRig.json`: editable curves, colors and limb pivot points.
- `preview.html` in the downloadable kit: standalone interactive browser demo using the same paths and motion formulas. Open locally; it has no network dependencies.

## Scope and verification

This package is isolated on the local `draft/mascot-animation` branch. It does not change the current app screens, Xcode project, backend, Codemagic configuration, or release. Nothing was pushed or deployed.

Validation: the preview controller passed a Node DOM-shim check for five actions, alternating legs, pause, and Reduce Motion. The five vector poses were rendered and visually inspected. A full browser run was blocked because the Chromium download was unavailable. The browser demo is not a rendering from the iOS app. An Xcode build and physical-device check are still needed: this workspace has no Swift compiler or Apple SDK. Check the package in the intended target, all five actions, pause/resume, app backgrounding and Reduce Motion before enabling it in a release.

The mascot is a 2D rig. It does not include a 3D model, physics or arbitrary camera rotation. Arms and legs are separately animated; extend the rig and action switch for additional poses.
