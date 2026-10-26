# face-scan-skin-1.0 — addendum (read after BRIEF.md)

Decisions the founder already made in another session, plus gaps in BRIEF.md. Where this file and BRIEF.md
disagree, this file wins.

## Answered founder question (BRIEF §9.5)

- **Q5 ElevenLabs: approved.** The founder asked for ElevenLabs voiceover and SFX. Voice "Kristen – Natural
  Upbeat Conversational Ad" (`dfeOmy6Uay63tNhyO99j`), model `eleven_v4`; SFX `eleven_text_to_sound_v2`
  (whoosh, tap, scan beep, chime). Sounds, not music. Still keep generations few — credits cost money.

## Gaps in BRIEF.md

1. **CI does not run XcodeGen.** `codemagic.yaml` builds the committed `Skintel.xcodeproj`; no step runs
   `xcodegen`. New Swift files won't compile unless the project is regenerated. Phase 0: either run
   `xcodegen generate --spec project.yml` in this container and commit the result (check that it installs on
   Linux first), or add a `brew install xcodegen && xcodegen generate` step to `ios-ci` and `ios-release`
   before the build. Verify with one `ios-ci` run.
2. **Show levels as words, not numbers.** BRIEF §2.2 returns `0–3` per kind; fine on the wire, but the UI
   shows None / Some / Noticeable with a glyph (status is never colour alone). No fake precision ("pore
   score 73"), and drop `skin_type_guess` from the UI unless the founder wants it — it overlaps onboarding.
   Never output skin age.
3. **Banned-word post-filter.** After the model returns, strip or reject diagnosis words (acne vulgaris,
   rosacea, eczema, dermatitis, melanoma, infection, condition, disease, treat, cure) and rewrite em dashes,
   like Ask does. Unit-test it in SkintelCore. Every result screen carries "A cosmetic read of a photo, not a
   diagnosis."
4. **Entitlement is server-side.** The free/teaser decision (BRIEF §10.4 limits) lives in `_face-scan.ts`;
   never trust a client flag.
5. **Locked-result paywall variant.** Alternative to "first scan free, full result": the free scan shows the
   person's own 3D face with the found zones softly lit and the cards blurred, wall slides up — "Your face
   scan is ready." Put both options in the §9 PR comment; build the founder's pick.
6. **Design first.** Before Swift for capture/result/paywall, make an HTML Design canvas artifact and get the
   founder's OK (no CI runs for looks; founder rule).
7. **3D reference from the founder's other app.** `pixelbuyte/blith-health`, `ios/Blith/Features/Body/`
   (SceneKit figure, region highlights, calm glow, drag to turn). Same founder, same taste: copy the camera
   feel and highlight style, not the assets. Fixed ARFaceGeometry topology ⇒ build the zone → vertex-index map
   once and commit it as JSON.
8. **Duo layout.** iPhone Duo inner display is regular width (951×669 pt). Use `skPagePadding()`; on the
   result screen consider the 3D face left, cards right when `horizontalSizeClass == .regular`.
9. **Duo launch film.** Besides `marketing/video-engine/`, the Skinstel Duo launch video was built with
   `renocrypt/ios27-duo-kit` (Apache-2.0, not vendored — clone it, never commit it). Storyboard: closed phone
   shows the NEW tag on Today → unfold → selfie guide → analysing → 3D face turns, zones light up → zone card
   with a shelf product → end card "Skinstel. See what your skin is doing." 16:9 + 9:16. Label mockup videos
   "sample data"; App Store previews must be real captures.

## Ideas after 1.0

Scan reminders on the check-in prompt · zone-trend charts on Insights · Triggers using scan zones as extra
evidence ("a pattern to test, not proof") · last-scan widget.
