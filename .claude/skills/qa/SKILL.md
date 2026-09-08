---
name: qa
description: Practical engineering QA for the Skintel iOS app — build, unit tests, UI tests, compiler and Swift 6 concurrency diagnostics, git diff checks, and critical-flow verification. Reports only actionable failures and important warnings; never claims success without running the commands.
---

# /qa

Run, in order, and paste real output (trimmed):

1. Core (works anywhere with a Swift 6 toolchain, including Linux):
   `cd ios/Skintel/SkintelCore && swift build && swift test`
2. On a Mac only:
   `cd ios/Skintel && xcodegen generate` (if `project.yml` changed)
   `xcodebuild -project Skintel.xcodeproj -scheme Skintel -destination 'platform=iOS Simulator,name=iPhone 16' build`
   `xcodebuild ... test -only-testing:SkintelTests`
   `xcodebuild ... test -only-testing:SkintelUITests`
3. `git diff --check` and `git status --short`.
4. Backend routes touched by iOS: `npx tsc --noEmit --ignoreConfig --strict --target es2023 --module esnext --moduleResolution bundler --types node --skipLibCheck --verbatimModuleSyntax api/_apple.ts api/apple-verify.ts api/apple-notifications.ts`

Then exercise (simulator or by reading the flow if no simulator): launch → welcome → sign-up/sign-in → onboarding
(profile, camera) → home → scanner (barcode / type it / photo) → found → verdict → save → product detail → routine
→ compare → journal → culprits → paywall → settings (restore, export, sign out, delete).

Report format: **Failures** (must fix, with the exact error) · **Warnings that matter** (concurrency, deprecations) ·
**Flows verified** · **Flows not verifiable here and why**. If you could not run something, say so — do not infer a pass.
