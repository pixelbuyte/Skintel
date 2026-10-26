# face-scan-skin-1.0 — session brief

Branch: `face-scan-skin-1.0` (cut from `main` at f0ca97d, after PR #70).
Goal: ship **Face Scan** in the native iOS app — the user scans their face, the AI reads their skin zone
by zone, and the result plugs into what Skintel already knows (shelf, check-ins, Triggers). Plus the
paywall, "NEW" tags, a Settings clean-up, and launch videos.

Read this whole file before touching code. Every path below was checked against `main` when this was written;
re-check anything you depend on, because `main` moves.

---

## 0. Ground rules (non-negotiable)

1. Read `CLAUDE.md` (repo root) and `ios/Skintel/CLAUDE.md` first. Load the `ios-ship-playbook` skill.
2. **The founder has no Mac.** Swift is only compiled by Codemagic `ios-ci`. Cross-check every API, member and
   initializer against real declarations in this repo or Apple's docs before committing. `swiftc -parse` every
   touched file; `cd ios/Skintel/SkintelCore && swift test` for core logic. Do not say it "builds" until `ios-ci`
   is green. Never start `ios-release`.
3. Adding/removing Swift files ⇒ `cd ios/Skintel && xcodegen generate --spec project.yml`.
4. **Vercel Hobby has exactly 12 functions and `api/` already has 12.** No new `api/*.ts` endpoint. Add the face
   analysis as `?action=face` on an existing function (e.g. `api/scan-ai.ts`) with a `vercel.json` rewrite, logic in
   a new `api/_face-scan.ts` module — the same pattern `apple.ts`, `account.ts`, `recommend.ts` use.
5. Brand is Skintel (see note in §9 about PR #74 "official name is Skinstel" — ask the founder before renaming
   anything user-facing). Design system wins: cream `F4EDE0`, clay `A35848`, ink `1A1814`, Instrument Serif /
   DM Sans / JetBrains Mono, no yellow. Tokens live in `ios/Skintel/Skintel/DesignSystem/Tokens/`.
6. Small commits, one concern each. Push to `face-scan-skin-1.0`; the founder reviews and merges.

## 1. What the founder asked for (verbatim intent)

- **Face scan, AI only.** No "ask a specialist / book a dermatologist" feature. The answer comes straight from
  Skintel's AI. (Keep the existing safety line in `api/_assistant.ts:252` — "see a dermatologist" for severe,
  spreading, painful reactions. That is a safety rail, not a feature.)
- **Paywall changes**, because Face Scan makes Skintel+ "a little different" — it needs its own moment on the paywall.
- **Small "NEW" tags** on the new features everywhere they appear.
- **Remove the Skintel+ upsell from the profile Settings.** See §5 — confirm the exact scope with the founder.
- **3D output**: when the scan result shows, show their face in 3D with the zones on it — make it feel first-of-its-kind.
- **Launch videos** for the feature (engine is already in this branch, §7).

## 2. Feature spec — Face Scan

### 2.1 Capture (on device)
- Entry points: a Today card ("Scan your face · NEW"), the centre **+** button sheet, and Insights.
- Front camera, guided: oval framing guide, live checks with **Vision** (`VNDetectFaceLandmarksRequest`,
  `VNDetectFaceCaptureQualityRequest`) for face present / centred / not too dark / eyes open / no heavy motion blur.
  Auto-capture when all checks pass for ~0.6 s (haptic + shutter), manual button as fallback.
- Optional 3-angle mode (front, left 3/4, right 3/4) — better cheek/jawline coverage. Default: front only.
- **TrueDepth devices**: run `ARFaceTrackingConfiguration` during capture to grab one `ARFaceGeometry`
  (1,220-vertex mesh) + the camera frame. This is what powers the 3D result. Check `ARFaceTrackingConfiguration.isSupported`;
  non-TrueDepth devices get the 2D result (§2.3).
- Downscale before upload (long edge ~1024 px, JPEG ~0.8). Never upload the mesh — it stays on device.

### 2.2 Analysis (server, AI)
- `POST /api/face-scan`, rewritten in `vercel.json` to `/api/scan-ai?action=face` (same shape as the existing
  `{ "source": "/api/assistant", "destination": "/api/recommend?action=assistant" }`) → logic in `api/_face-scan.ts`.
  Auth like the other routes.
- Model routing through `api/_ai.ts` (`complete()` / `openRouterChat()`), a vision-capable model; keep the
  Anthropic fallback pattern already there. Return **strict JSON**, validated server-side:
  ```json
  { "zones": [ { "zone": "forehead|nose|left_cheek|right_cheek|chin|jawline",
                 "breakouts": 0, "redness": 0-3, "oiliness": 0-3, "dryness": 0-3, "texture": 0-3,
                 "dark_spots": 0-3, "note": "short cosmetic observation" } ],
    "overall": { "summary": "...", "skin_type_guess": "oily|dry|combination|normal", "confidence": 0-1 },
    "photo_ok": true, "retake_reason": null }
  ```
- Cosmetic language only: "visible breakouts", "redness", "shine". **Never** diagnose ("acne vulgaris",
  "rosacea", "infection"), never prescribe. Low confidence or bad photo ⇒ `photo_ok:false` + retake reason.
- **Personal layer (Skintel's edge):** after the vision call, join the zones with the user's own data — shelf
  products with "Broke out" tags, recent check-ins, Triggers top suspect — to write 1–2 lines like
  "Your chin breakouts started 4–6 days after Rose Cloud Moisturizer joined your shelf." Reuse the context the
  assistant already builds in `api/_assistant.ts` rather than re-querying.
- Don't retain the photo server-side. Log no image data.

### 2.3 Result screen
- **3D face map (TrueDepth):** render the captured `ARFaceGeometry` with SceneKit/RealityKit, textured with the
  captured frame (or a soft clay-tinted material), zones lit with a subtle heat overlay (clay for breakouts, warm
  pink for redness, sheen for oil). Slow auto-rotate, drag to turn, tap a zone to open its card. Respect Reduce Motion.
- **2D fallback:** the photo with zone outlines from Vision landmarks, same tap-to-open cards.
- Below: overall summary, zone cards, the personal line(s), and actions: "Log today's check-in from this scan",
  "Ask Skintel about this" (opens Ask with the scan attached as context), "Compare with last scan".
- **History:** each scan saved locally (photo + JSON, never the mesh off-device), a timeline with side-by-side
  compare and per-zone trend sparklines. This is the retention hook.
- Haptics + one restrained "reveal" animation when results land. Everything in `SK*` components.

### 2.4 Data, privacy, App Review (do this properly — it's the #1 rejection risk)
- Consent sheet before the first scan, same style as the existing AI consent (`RecommendView.swift:413`):
  what is sent (one photo), to whom (third-party AI provider via OpenRouter/Anthropic), not stored, not used for ads.
- ARKit face data rules (Apple guideline 5.1.2 and the ARKit face-tracking terms): no advertising/marketing use,
  no sharing with third parties of face *geometry*, disclose in the privacy policy. The mesh never leaves the device.
- No face recognition / identity matching. No age/ethnicity/gender inference — strip it from the prompt and output.
- Update: privacy policy `src/pages/Privacy.tsx`, `ios/Skintel/Skintel/Resources/PrivacyInfo.xcprivacy`, Info.plist camera
  string (front camera for face scan), App Store privacy nutrition label notes for the founder.
- "Delete my data" must delete scans too (account deletion flow already exists — extend it).

### 2.5 Models in `SkintelCore`
- `FaceScan`, `FaceZone`, `FaceScanResult` (Codable, tolerant decoding — see the persisted-model decoding traps in
  `ios/Skintel/CLAUDE.md`), a `FaceScanStore` (local), and the API call in the existing API client.
- Unit tests in `SkintelCore` for decoding (incl. missing/extra fields), zone mapping, trend math. They run on Linux.

## 3. Paywall (Skintel+)

Current: `ios/Skintel/Skintel/Features/Subscription/PaywallView.swift`; gating reasons in
`ios/Skintel/Skintel/App/MainTabView.swift:498` (`enum PaywallReason { scanner, productLimit, compare, recommend,
routine, journalAnalysis, culprits, assistant, general }`).

- Add `case faceScan`. When opened from Face Scan, the paywall hero is the 3D face map (looping, pre-rendered or a
  live SceneKit demo face — **no real person's face**; use a stylised/neutral mesh), headline about seeing your skin
  zone by zone.
- Free tier proposal (confirm with founder): **first scan free, full result**; after that Face Scan is Skintel+.
  History/compare is Skintel+ from day one.
- Add Face Scan to the paywall feature list with a **NEW** tag.
- Keep every existing StoreKit 2 rule: restore, terms text, trial copy, the `missingPlanIDs` test-build notice. Run the
  `appstore-check` skill on the result.

## 4. "NEW" tags

- New component `SKNewBadge` in `ios/Skintel/Skintel/DesignSystem/Components/` — tiny pill, clay background, cream
  JetBrains Mono "NEW", 10–11 pt, uppercase, tracking. Accessible label "New feature".
- Show on: Today Face Scan card, the + sheet row, Insights entry, paywall feature row, Settings row if any.
- Auto-hide per placement after the user opens Face Scan once **or** 21 days after first seen (`@AppStorage` keys).
- Optional one-time "What's new" sheet on first launch after update (Face Scan + 3D map), dismissible.

## 5. Settings: remove the Skintel+ upsell

`ios/Skintel/Skintel/Features/Settings/SettingsView.swift` (as of f0ca97d):
- ~line 391–400: plan card — "Skintel Free / Skintel+ / Founding member" with "Get Skintel+" or "Manage".
- ~line 675: `SettingsGroup(title: isPro ? "Your Skintel+ benefits" : "What Skintel+ adds", …)`.

Default plan (ask the founder in the PR before merging): **remove the line-675 benefits group entirely**, and slim the
plan card to a single row: plan name + "Manage subscription" (opens App Store subscriptions) — no upsell copy.
Keep a way to restore purchases somewhere reachable (App Review expects it).

## 6. Repos and references to evaluate (verify license + activity before using any)

Prefer Apple frameworks — zero dependencies, nothing to fight in XcodeGen.
- **Apple sample "Tracking and Visualizing Faces"** (ARKit, developer.apple.com sample code) — face mesh + texture
  mapping; the closest reference for the 3D result.
- **Apple Vision** — `VNDetectFaceLandmarksRequest`, `VNDetectFaceCaptureQualityRequest` for the capture guide.
- **Google MediaPipe Face Landmarker** (`google-ai-edge/mediapipe`, Apache-2.0) — 478 3D landmarks from any camera,
  useful for the 2D fallback / non-TrueDepth "3D-ish" view. Note: its iOS SDK ships via CocoaPods; check SPM support
  before adopting — this project is SPM + XcodeGen only.
- **Web demos for marketing** (three.js + MediaPipe facemesh examples) — render a 3D face-map teaser for videos/site.
- Single-photo 3D face reconstruction research (DECA, EMOCA, 3DDFA_V2) — impressive but heavy/GPU, licenses vary;
  probably not for v1. Only if TrueDepth coverage turns out too low.
- Skin datasets/models on Hugging Face (acne/redness detection) — **research only**; most datasets are non-commercial.
  Do not ship a model trained on them without a license check. v1 uses the vision LLM.
Use the Hugging Face connector (`hf_fs search hf://models …`) and web search; write findings into
`docs/face-scan-skin-1.0/RESEARCH.md` with license + last-commit date for each.

## 7. Launch videos (engine is in this branch)

`marketing/video-engine/` — see its README. It renders TikTok/Reels videos from HTML: live Skintel screens
composited onto real hand-held phones, parallax people, kinetic type, voiceover, synthesized sound effects.
- Add Face Scan screens to `marketing/video-engine/ugc/app.js` (capture guide, analysing, 3D result) once the real
  UI exists — mirror the shipped SwiftUI exactly (founder rejects anything that looks like an old/fake design).
- Scripts: use the `content-principles` skill (one viewer, line 1 sells line 2, specific numbers, open loops).
  Hook ideas from the scrape (`marketing/` research): "I scanned my face and it showed me where my breakouts come
  from", "Your chin breakouts and your cheek breakouts aren't the same problem", "POV: your skin map in 3D".
- Voice: local Kokoro TTS works (README). **ElevenLabs is now connected** for better voices/SFX — ask the founder
  before spending credits. Higgsfield had ~0 credits at handoff.
- Sound: founder wants **sounds, not music** — voiceover + effects + light room ambience. Meme-style effects are
  synthesized in `tools/audio.py` (original, safe for ads). Trending TikTok sounds are not cleared for brand ads.
- Disclose AI-generated people (TikTok AI label). No fake testimonials, no medical claims.

## 8. Build order and acceptance

1. **Plan PR comment** listing the decisions you need from the founder (§9). Don't block on them — build behind them.
2. Core: models + decoding tests + API client call (`swift test` green).
3. API: `?action=face` + `_face-scan.ts` + rewrite; JSON validation; `npm run build` + `npx eslint api` clean on
   touched files (remember `tsc -b` does not cover `api/`).
4. Capture screen (Vision guide, auto-capture) → push → `ios-ci`.
5. Result screen 2D → then 3D (TrueDepth) → push → `ios-ci`.
6. History + compare.
7. Paywall `faceScan`, NEW badges, Settings clean-up → `appstore-check` + `design-review` skills.
8. Privacy policy, privacy manifest, consent, data deletion → `security-review` skill.
9. Videos (§7).
Done = `ios-ci` green, `SkintelTests` + `SkintelUITests` pass, a UI test that walks Face Scan with a stubbed API,
skills above report no FAIL, PR description lists every founder decision taken by default.

## 9. Open questions for the founder (ask once, in the PR)

1. Free tier: first scan free, then Skintel+? Or scans free and only 3D/history paid?
2. Settings: remove only the "What Skintel+ adds" group, or the plan card too (keeping Manage/Restore)?
3. ~~Name~~ — answered: `CLAUDE.md` now says the official name is **Skinstel** for everything people see; code
   identifiers stay `Skintel`. New user-facing strings in this feature say Skinstel.
4. 3-angle capture in v1, or front-only?
5. OK to spend ElevenLabs credits on the launch videos?

---

## 10. Additions (marketing session, Oct 26) — read before §8

Facts these rest on were checked on `main` at f0ca97d (Supabase queried with counts only).

### 10.1 Make Face Scan the first thing a new user does
- **The funnel is leaking at the sign-in wall.** App Store: 3 downloads Oct 22–24. Supabase: **no new account since
  Oct 21**, and the auth logs for Oct 22–25 show **zero** sign-in or sign-up attempts (Apple sign-in works: 3 accounts
  came through it, the latest Oct 21). The app routes signed-out users straight to `AuthFlow`
  (`App/AppRouter.swift:16`) — WelcomeView pages, then the account form.
- So: put **"Scan your face — free"** on the welcome flow and let a signed-out user run **one** scan and see the full
  result (2D or 3D) before any account. Then "Save this scan and track your zones → Continue with Apple". The scan
  JSON + photo wait locally and attach to the account after sign-in.
- The server route must accept that one pre-account scan: per-device token (App Attest if feasible, else
  `identifierForVendor` + a server-side counter) and a hard rate limit, so the free scan can't be farmed.
- App Review 5.1.1(v) favours letting people use features that don't need an account — this helps review, not hurts.
- Add this as founder question §9.6; build it behind a flag so it can ship either way.

### 10.2 The 3D result — how to make it feel first-of-its-kind
- **TrueDepth (iPhone X and later with Face ID):** `ARFaceGeometry` from the capture frame, rendered in SceneKit
  (`ARSCNFaceGeometry` needs an AR session; for the result screen copy vertices/indices/UVs into a plain
  `SCNGeometry` so it renders without the camera). Texture: the captured frame projected through the face UVs, or the
  clay "sculpture" material with zone heat on top — prototype both; the sculpture look avoids showing a raw selfie
  mesh and reads more premium.
- **Everyone else:** MediaPipe's **canonical face model** — a 468-vertex mesh with UVs,
  `google-ai-edge/mediapipe` → `mediapipe/modules/face_geometry/data/canonical_face_model.obj` (Apache-2.0, verified
  present). Bundle the .obj as a resource (no MediaPipe SDK needed), fit it roughly to Vision's 2D landmarks (scale,
  rotate, translate), map zone colours onto its UV regions. It's a stylised face, not theirs — label it "your zones",
  not "your face".
- **Reveal moment:** mesh fades in as a wireframe, zones light up one at a time with a soft haptic per zone, then
  settles into a slow turn. Under 2 s; Reduce Motion ⇒ instant.
- **Shareable card:** the 3D zone render (sculpture style, never the selfie) as an image for Stories — the growth loop.
- Zone polygons: define each zone once as a vertex-index set on the canonical mesh; ARKit's mesh has a different
  topology, so keep a small mapping table (nearest canonical vertex per ARKit vertex, computed once offline and
  bundled). Write it in `SkintelCore` with tests.

### 10.3 Accuracy and fairness (vision LLMs are uneven — test it)
- Build a small eval set **from consented photos only** (founder + testers who agree in writing), across skin tones,
  lighting and angles. Score the model's zone output against a human label for each. Track: retake rate, zone
  agreement, run-to-run consistency (same photo twice ⇒ near-same JSON).
- Lower temperature, fixed schema, server-side clamping of every score; `photo_ok:false` beats a confident wrong answer.
- Check that redness/dark-spot reads don't skew on darker skin tones; if they do, drop that field for v1 rather than
  ship a biased number.
- No single "skin score" or "skin age" number in v1 — they invite comparison claims we can't back. Zone levels +
  trends are honest and still feel like progress.

### 10.4 Cost and abuse
- Log model + tokens per scan (no image data) so the founder sees cost per scan. Cap image size on the server too.
- Rate limits: free ⇒ 1 scan lifetime (per account and per device); Skintel+ ⇒ a sane daily cap (e.g. 5/day).

### 10.5 Measure it
- New `AnalyticsEvent` cases (`Core/Analytics/Analytics.swift`): scan started, capture passed checks, retake reason,
  result shown (2D/3D), paywall shown from faceScan, sign-in after pre-account scan. That's the funnel the founder
  can't see today.

### 10.6 Small things that are easy to miss
- `NSCameraUsageDescription` (`ios/Skintel/project.yml:108`) only mentions barcodes — add the face scan, and
  `NSFaceIDUsageDescription` is **not** needed (ARKit face tracking isn't Face ID). Check whether ARKit face tracking
  needs any plist/capability entry and add the App Store Connect privacy-label note for the founder.
- ARKit/Vision are not imported anywhere yet — new frameworks: confirm XcodeGen links them (system frameworks are
  implicit with `import`, but verify on `ios-ci`).
- "What's new" text for the App Store release notes and a refreshed screenshot set with the 3D map
  (`marketing/app-store/` has the slide renderer).

### 10.7 Launch videos — what actually performs (from this session's scrapes)
- Native, raw, short beats polished: app reveals got 4.8M (582 followers) and 2.2M (675 followers). Make the
  face-scan launch as **"name of this app is Skinstel"**-style screen recordings of the real 3D reveal
  (`marketing/video/stock/build_reveal.py`, `reveal.html` — reuse them) and a carousel (`carousel.html`).
- Every post has sound (voice + effects, or a trending song added in-app). Silent posts sat at the ~100-view floor.
- Real faces beat AI faces: founder or paid creators who actually used the scan (label #ad). No AI person presented as
  a user; no before/after skin claims.

### 10.8 More founder questions (add to §9)
6. Let a signed-out user do one free scan before making an account (§10.1)?
7. 3D look: real photo texture, or the clay "sculpture" with heat zones (recommended)?

---

## Kick-off prompt for the next session (copy-paste)

> Work on branch `face-scan-skin-1.0` in pixelbuyte/Skintel. Read `docs/face-scan-skin-1.0/BRIEF.md` fully, then
> `CLAUDE.md` and `ios/Skintel/CLAUDE.md`, and load the `ios-ship-playbook` skill. Post the §9 questions (incl.
> §10.8) as one PR comment, then follow §8 in order, folding in §10 (pre-account scan behind a flag, 3D via ARKit +
> MediaPipe canonical mesh, eval set, analytics). Swift only compiles on Codemagic `ios-ci` — cross-check every API before pushing,
> `swiftc -parse` touched files, `swift test` in SkintelCore. No new `api/*.ts` endpoints (12-function limit).
> Never start `ios-release`. Report each step: changed, verified, left.
