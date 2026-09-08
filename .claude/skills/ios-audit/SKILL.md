---
name: ios-audit
description: Audit the Skintel native iOS code for Swift/SwiftUI architecture, Swift 6 concurrency, navigation, state, memory, service boundaries, duplication, networking, build configuration and performance. Returns actionable findings and fixes high-confidence ones.
---

# /ios-audit

Scope: `ios/Skintel/Skintel/**` (app) and `ios/Skintel/SkintelCore/**` (core). Spec: `ios/Skintel/project.yml`.

Check, with file:line evidence:
- **Concurrency** — `@MainActor` on every `@Observable` class; no non-Sendable captured across actors;
  no `Task {}` spawned in view bodies; cancellation for obsolete work (search debounce, refresh coalescing).
- **State** — one store per concern (`ProductStore`, `SubscriptionStore`, `ScanStore`, `RoutineStore`, `JournalStore`);
  views derive, never duplicate. Flag any view holding server data in `@State`.
- **Navigation** — every push goes through `AppDestination`; sheets/covers are local. No stack invents its own scheme.
- **Boundaries** — views never touch `URLSession`; all HTTP is in `SkintelCore/API`. Errors reach views only as `APIError`.
- **Networking** — 402 → paywall, `FREE_PLAN_LIMIT` → paywall, 401 → sign-in, no retries on non-idempotent calls.
- **Persistence** — Keychain for the session; Application Support + file protection for local stores; UserDefaults only for prefs.
- **Design system** — no hard-coded hex/point values in features; tokens from `DesignSystem/Tokens`.
- **Build** — `project.yml` settings (Swift 6, iOS 17, portrait, strict concurrency), Info keys, fonts registered.
- **Performance** — image resize before upload, no full-list recomputation in hot paths, `LazyVGrid` where lists are long.

Then: run `cd ios/Skintel/SkintelCore && swift build && swift test`. Fix high-confidence issues directly and
list what you changed. Leave judgement calls as findings.
