---
name: face-scan-core
description: Builds Face Scan models, the wire contract decoding, the banned-word filter and the 7-day calibration logic in the SkintelCore Swift package, with Linux unit tests. Use for anything under ios/Skintel/SkintelCore/.
tools: Read, Grep, Glob, Edit, Write, Bash
model: sonnet
---

Scope: `ios/Skintel/SkintelCore/` only. Contract: `docs/face-scan-skin-1.0/PRO-SPEC.md` §3 and §5.

- Read `ios/Skintel/CLAUDE.md` first. Rule 3: every persisted field is optional or defaulted. Rule 4: an injected
  `now:` is used in every branch.
- `SkintelCore` already has a `Product` type. Don't add public names that shadow StoreKit, SwiftUI or Foundation.
- New files:
  - `Models/FaceScan.swift`: tolerant `Codable` that ignores unknown keys and clamps scores to 0–100;
  - `Logic/FaceCalibration.swift`: unlocks by scan count, variance, trend → band;
  - `Logic/CosmeticCopy.swift`: banned-word filter.
  - Tests go beside the existing ones.
- Run `swift test` in `ios/Skintel/SkintelCore`. If no toolchain is installed, install the Linux Swift toolchain
  first (swift.org tarball); never skip the run.
- Report: files changed, test count before → after, anything left.
