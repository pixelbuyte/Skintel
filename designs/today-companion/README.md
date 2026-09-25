# Today: Skinstel companion homepage

Implemented in the existing native SwiftUI `HomeView.swift` on `draft/mascot-animation`.

## What changed

- Weekly check-in strip uses `JournalStore.week`. A drop sticker means a real entry exists. Missing days stay empty. Condition text accompanies each sticker; color is not the only signal. Journal opens the existing history sheet.
- Morning/evening selector drives a large routine-completion ring. Its fraction comes from resolved shelf products and the existing saved ticks. It is not a skin-health score. Empty routines do not display a completion percentage.
- Native `SkinstelMascot` sits inside the ring, waves when tapped, sleeps in the evening and celebrates briefly after the user completes the routine. Existing package behavior respects Reduce Motion, visibility and scene activity.
- Check-in and morning/evening care cards use the transparent `DropCheckIn`, `DropSunscreen` and `DropNight` assets. Ask, review and recommendations use their matching existing catalog assets.
- All checklist actions, product detail navigation, journal saves, assistant context and routine editor remain connected to the existing app services.
- The routine editor accepts an initial AM/PM slot so the selected Today routine is the one that opens. Today also rolls the store's daily ticks on appearance and foregrounding.
- Larger accessibility text stacks the action cards, allows scrolling through the week, and moves the percentage outside the fixed ring.

All Swift changes are in existing files already referenced by the Xcode project. No new native source files, package dependencies, asset names, backend routes or persisted fields were introduced.

## Review preview

`preview.html` is an interactive browser design reference with **example data**, not a screenshot or compilation of the native screen. It uses the repository's fonts and transparent illustrations via relative paths. Its hero image approximates the native animated pose.

Open it from a checkout, retaining the repository folder structure. The Morning/Evening selectors, checklist ticks, completion action, check-in choices, scenario selector and size selector work locally. Assistant/editor dialogs identify the corresponding native destinations rather than calling live services.

## Validation and next build

- `git diff --check` passed.
- Preview JavaScript parsed using Node's VM parser; referenced PNGs exist and have RGBA color type.
- Native calls were checked against `RoutineStore`, `JournalStore`, `RoutineView`, `JournalView`, `SKDrop`, and the `SkinstelMascot` package declarations.
- No Swift/Xcode toolchain is available here. **The native target is not compiled or simulator-tested.** Run the existing Codemagic `ios-ci` workflow for this branch before merging.
- Browser rendering was not verified: the cloud browser rejected local `file:` navigation. No screenshot is claimed.

## Claude handoff

Fetch `draft/mascot-animation`, read this file, and inspect the four changed Swift files. Run `ios-ci` (not `ios-release`). Check populated, empty, partial, completed, failed-loading and evening states on small and large iPhones. Confirm that toggling a step updates the ring, undoing a step cancels celebration, switching AM/PM opens the correct editor, journal errors have retry, and check-in/assistant sheets still work. Check VoiceOver and accessibility text sizes. Keep this as draft work until the build and device review pass; do not merge or release automatically.
