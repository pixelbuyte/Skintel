# Face Scan — parallel workflow

How several agents (or sessions) build Face Scan at once without colliding or burning CI minutes.

## Roles

- **Orchestrator**: the session the founder talks to, on Opus 5.5. It splits work into lanes, launches subagents
  with `isolation: "worktree"`, merges lane branches, and starts `ios-ci` once per batch. It never starts
  `ios-release`.
- **Subagents** are defined in `.claude/agents/`:

| Agent | Model | Lane |
|---|---|---|
| `face-scan-designer` | Opus 5.5 | D: design canvas, design review |
| `face-scan-core` | Sonnet 5.5 | A: SkintelCore models, calibration logic, tests |
| `face-scan-api` | Sonnet 5.5 | B: API route, ZDR routing, Supabase |
| `face-scan-ios` | Opus 5.5 | E, F: SwiftUI screens, ARKit/Vision, paywall, NEW tags |
| `face-scan-reviewer` | Opus 5.5 | Pre-push review of every lane |

## Lanes

Claim a lane by putting your session name in **Owner** and committing that one-line change before you start. Two
sessions have already written to this branch.

| Lane | Owns these paths (nobody else edits them) | Depends on | Owner | Status |
|---|---|---|---|---|
| C · CI | `codemagic.yaml`, `ios/Skintel/Skintel.xcodeproj` | – | | todo |
| A · Core | `ios/Skintel/SkintelCore/**` | contract (PRO-SPEC §3) | | todo |
| B · API | `api/_face-scan.ts`, `api/scan-ai.ts`, `api/_ai.ts`, `vercel.json`, `supabase/**` | contract | | todo |
| D · Design | the canvas (PRO-SPEC header) | – | | v1 done, waiting for the founder's OK |
| F · Paywall + NEW + Settings | `Features/Subscription/**`, `Features/Settings/**`, `App/MainTabView.swift`, `DesignSystem/Components/SKNewBadge.swift` | A (types only) | | todo |
| E · Face Scan screens | `Features/FaceScan/**`, `project.yml` (camera string) | A, D approved | | todo |
| G · Video | `marketing/**` | E | | todo |

**Parallel batch 1:** C, A, B and D together. **Batch 2:** E and F together. **Then** G.

## Branches

- Each lane works on `face-scan/<lane>` (e.g. `face-scan/core`) cut from `face-scan-skin-1.0`, and opens a PR
  into `face-scan-skin-1.0`. The founder merges `face-scan-skin-1.0` → `main` once (PR #76).
- Never push to `main`. Never force-push a branch another session has used. Integrate with a merge, not a rebase.

## Lane C first: the XcodeGen gap

`codemagic.yaml` builds the committed `Skintel.xcodeproj` and never runs XcodeGen, so new Swift files are silently
left out of the build. Pick one fix:

1. Add a step before the build in `ios-ci` and `ios-release`:
   `brew install xcodegen && cd ios/Skintel && xcodegen generate --spec project.yml`. Recommended: it is the
   same as Blith's CI.
2. Run XcodeGen in this Linux container and commit the regenerated project.

Prove it with a single `ios-ci` run.

## Verifying each lane

- **Core:** `swift test` in `ios/Skintel/SkintelCore`. This container has no Swift toolchain, so install the Linux
  toolchain first (swift.org tarball, Swift 6).
- **API:** `npm run build` plus `npx eslint` on the touched files, plus a type-check of `api/` (`tsc -b` skips it).
- **Swift UI:** `swiftc -parse` on the touched files, `face-scan-reviewer` on the diff, then **one** `ios-ci` for the
  whole batch. Batch fixes before pushing. Never run CI to look at a screen; that is the canvas's job.

## Kick-off for the orchestrator

> On branch `face-scan-skin-1.0` (pixelbuyte/Skintel), read PRO-SPEC.md, BRIEF.md, ADDENDUM.md and this file.
> Claim lanes C, A, B. Launch `face-scan-core` and `face-scan-api` in parallel worktrees while you do lane C.
> Run `face-scan-reviewer` on each result, then merge into `face-scan-skin-1.0`, push, and start one `ios-ci`.
> Report changed / verified / left. Batch 2 waits until the founder approves the canvas.
