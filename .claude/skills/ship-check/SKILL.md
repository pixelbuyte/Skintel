---
name: ship-check
description: Final production-readiness gate for the Skintel iOS app. Reviews completeness, design fidelity, native quality, build, release configuration, tests, performance, security, privacy, StoreKit, App Store compliance, docs, unresolved TODO/FIXME, placeholder data and mocked production functionality. Returns READY TO SHIP / READY AFTER EXTERNAL APPLE SETUP / NOT READY with exact blockers.
---

# /ship-check

Do not pass because it compiles. Work through every line and cite evidence:

1. **Completeness** — every feature in `MIGRATION_MAP.md` marked REUSE/API/PORT/NATIVE exists and is wired
   (grep the view names). No `TODO`, `FIXME`, `fatalError("unimplemented")`, `Text("Coming soon")`.
2. **No fakes** — no hard-coded product arrays, no mocked API responses outside `#if DEBUG`/previews, no fake progress.
3. **Design fidelity** — run `/design-review` if it hasn't run since the last UI change.
4. **Build** — `/qa` results are green (core on any machine; app on a Mac). Release configuration has no dev URLs.
5. **Security/privacy** — `/security-review` has no open Critical/High.
6. **StoreKit + backend** — products in `SubscriptionService.ProductID` match `api/_apple.ts` `APPLE_PRODUCTS`;
   migration `supabase/migrations/0004_apple_iap.sql` applied; env `APPLE_APP_APPLE_ID` set; Server Notifications URL registered.
7. **App Store** — `/appstore-check` has no FAIL.
8. **Docs** — `README.md`, `IOS_ARCHITECTURE.md`, `IOS_SETUP.md`, `DESIGN_REVIEW.md`, `APP_STORE_CHECKLIST.md` current.

Verdict (one of):
- **READY TO SHIP**
- **READY AFTER EXTERNAL APPLE SETUP** — list each remaining step verbatim from `IOS_SETUP.md`.
- **NOT READY** — numbered blockers, each with file:line and what "done" looks like.
