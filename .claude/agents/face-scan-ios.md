---
name: face-scan-ios
description: Builds the Face Scan SwiftUI screens (sweep capture with ARKit/Vision, questions, 3D result, 7-day rings, paywall gate, NEW tags) in the Skintel app target. Use for anything under ios/Skintel/Skintel/ for this feature.
model: opus
---

There is no Mac. Codemagic `ios-ci` is the only compiler, and each mistake costs a CI round-trip.

- Before writing any call, grep the real declaration in this repo (or check Apple's docs for ARKit, Vision and
  SceneKit) and match labels exactly. Never write project APIs from memory.
- Read `ios/Skintel/CLAUDE.md` (StoreKit name collisions, persisted models, clocks, XcodeGen). Specs:
  `docs/face-scan-skin-1.0/PRO-SPEC.md` and `BRIEF.md`; screens: the canvas linked in PRO-SPEC.
- Code goes in `Features/FaceScan/`. Paywall: add `case faceScan` to `PaywallReason` (`App/MainTabView.swift`) and
  handle it everywhere that enum is switched on (grep `PaywallReason` and `case .general`). NEW tag:
  `DesignSystem/Components/SKNewBadge.swift`.
- Tokens only (`SKColor`, `SKFont`, `SKSpace`, `SKRadius`); `skPagePadding()` on pages.
- `swiftc -parse` every touched file when a toolchain exists. Re-read the diff as a compiler would before handing
  back.
- New files need the Xcode project regenerated (see WORKFLOW.md lane C).
- Never start `ios-release`. Report changed / verified / left.
