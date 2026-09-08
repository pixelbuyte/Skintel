# iOS architecture

Two pieces: a local SwiftPM package that knows nothing about UIKit, and a SwiftUI app that composes it.

```
ios/Skintel/
├── project.yml                 XcodeGen spec → Skintel.xcodeproj (committed)
├── Config/*.xcconfig           team id + public client config (Config.xcconfig is gitignored)
├── SkintelCore/                SwiftPM · builds and tests on macOS AND Linux
│   └── Sources/SkintelCore/
│       ├── Models/             Product, ProductIngredient, Subscription, JournalEntry, Culprit, SkinProfile …
│       ├── Logic/              INCI (parse/normalise) · IngredientKnowledge · Correlate · Entitlement
│       └── API/                HTTPClient · GoTrueClient · PostgRESTClient · SkintelAPI · DTOs · APIError
└── Skintel/                    the app target
    ├── App/                    SkintelApp · AppEnvironment (DI) · AppRouter (RootView) · MainTabView · Navigation
    ├── Core/
    │   ├── Config/             AppConfiguration (reads Info.plist keys fed by xcconfig)
    │   ├── Auth/               SessionManager · KeychainSessionStore · AppleNonce
    │   ├── Persistence/        ProductStore · SubscriptionStore · ScanStore · RoutineStore · JournalStore
    │   ├── Analytics/          Analytics protocol + os_log sink (no SDK)
    │   └── Utilities/          Haptics · CameraPermission · ImageResizer · DateFormatting
    ├── DesignSystem/
    │   ├── Tokens/             SKColor · SKFont · SKSpace/SKRadius/SKAnimation
    │   └── Components/         SKButton · SKCard · SKChip · SKScoreRing · SKTextField · SKStates · SKMarks · SKNavigation
    ├── Features/               Auth · Onboarding · Home · Products · Scanner · Analysis · Journal · Culprits ·
    │                           Routine · Compare · Recommend · Subscription · Settings
    └── Resources/              Assets.xcassets · Fonts/ · PrivacyInfo.xcprivacy · Skintel.entitlements · Skintel.storekit
```

## Layers and rules

**SkintelCore** is the product's logic and its contracts with the backend. It has no UI, no Keychain, no StoreKit.
Anything here must compile under Swift 6 strict concurrency on Linux (`swift test`), which is how it is verified.
Views never import URLSession; every request goes through the three clients and every failure arrives as `APIError`.

**Stores** (`Core/Persistence`) are `@MainActor @Observable` classes, one per concern, created once in
`AppEnvironment` and injected with `.environment(env)`. Views derive from stores; they do not cache server data in
`@State`. The four counts on Home, the culprits on three screens and the score badges all read the same objects.

**Features** own their views and, where a flow has real state, a view model (`AuthViewModel`, `OnboardingViewModel`,
`ScanFlowModel`). Everything else is a plain view over the stores.

**Design system** is the only place hex values and point sizes live. Fonts are registered via `UIAppFonts` and every
`SKFont` style is `relativeTo` a text style so Dynamic Type scales it.

## Session and routing

`SessionManager` is the single owner of the Supabase session and the app's `TokenProvider`. It restores from the
Keychain at launch, refreshes a minute before expiry with coalesced refresh tasks, keeps a stale session on a
*network* failure (so an offline launch lands on Home), and signs out locally only on a definitive 401.

`AppRoute.resolve(state, onboardingSkippedLocally)` maps session state to `launching / signedOut / onboarding / main`.
`RootView` shows the splash until the Keychain has been read — there is no frame where a sign-in screen flashes before
Home. Onboarding completion is the `onboarding_complete` flag in `auth.users.user_metadata`, alongside `skin_type`,
`concerns` and `display_name`.

Navigation: each tab has a `NavigationStack`; pushes use `AppDestination`; sheets and full-screen covers are local.
The paywall is reachable from anywhere via the `openPaywall` environment action with a `PaywallReason`.

## Data flow for a scan

1. `BarcodeScannerView` (AVFoundation metadata output) → `ScanFlowModel.handleBarcode` (debounced per code).
2. `SkintelAPI.lookupBarcode` (`/api/lookup?mode=barcode`) → `ScanCandidate` — or the not-found / paste path.
3. `SkintelAPI.scan` (`/api/scan-ai`) with `Correlate.run(products).all` as `matches` → `ScanResult`.
4. `ScanStore.record` keeps the verdict on device (the `products` table has no score column, exactly as the web keeps it
   in `localStorage`). `VerdictView` renders the ring, counts and flags.
5. "Save to shelf" → `ProductFormView` prefilled → `PostgRESTClient.addProduct` (product + ingredients, compensating
   delete on failure) → `ScanStore.attach` re-keys the verdict to the new product id.

Paste, photo (`/api/scan-photo`), link (`/api/lookup?mode=url`) and search (`mode=search`) all resolve to the same
`ScanCandidate` and share steps 3–5.

## Entitlement

`Entitlement` (core) implements the server's rule — `status ∈ {active, trialing}` **and** `tier ∈ {pro, founding}` —
not the web hook's tier-only rule, so the app never shows a feature the API will answer with 402. The scanner, compare,
recommend, routine analysis and journal analysis check `entitlement.isPro` before calling and route to the paywall on
`APIError.proRequired`; the 5-product free cap is enforced by the DB trigger and surfaces as `APIError.freePlanLimit`.

StoreKit 2 (`SubscriptionService`): products are loaded by id, purchased with `appAccountToken = Supabase user id`,
and the signed transaction is sent to `/api/apple-verify`. The backend verifies it against Apple's root CA, binds it to
the bearer user, computes tier/status/period (three months from purchase for the non-renewing founding product), and
upserts the `subscriptions` row. `Transaction.updates` and `currentEntitlements` are observed for renewals and restores;
`/api/apple-notifications` keeps the row current from Apple's side. Stripe rows are never downgraded by an Apple purchase.

## Persistence

| What | Where | Why |
|---|---|---|
| Session | Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) | never UserDefaults |
| Scan verdicts | Application Support `scans.v1.json` (complete file protection) | mirrors web `localStorage['skintel:scans:v1']` |
| Routine | Application Support `routine.v1.json` | mirrors web `localStorage['skintel:routine:v1']` |
| Haptics preference, onboarding-skipped | UserDefaults | prefs only (declared in the privacy manifest) |
| Products, subscription, journal | Supabase, via the stores | source of truth |

## Concurrency

Swift 6 language mode with `SWIFT_STRICT_CONCURRENCY = complete` on every target. Stores and view models are
`@MainActor`; clients are `Sendable` structs; the camera coordinator hops to the main actor before calling back.
Long-running work (search debounce, refresh) is a stored `Task` that is cancelled or coalesced.

## Analytics events

`onboarding_completed`, `sign_in{method}`, `scan_started{mode}`, `scan_completed{verdict}`, `product_saved`,
`journal_saved`, `culprit_viewed`, `routine_analyzed`, `compare_run`, `paywall_viewed{reason}`,
`purchase_started{product_id}`, `purchase_completed{product_id}`, `restore_completed`. Payloads never contain
ingredient lists, journal text or scan results. The only sink today is `os_log`; add a provider behind `Analytics`.

## Testing

- `SkintelCore/Tests` — Swift Testing; INCI parity with the TypeScript, correlation, entitlement rule, every decoder,
  error mapping. Runs on Linux (`swift test`) and in Xcode.
- `SkintelTests` — Swift Testing; routing, on-device stores, templates, date formatting, score thresholds.
- `SkintelUITests` — XCTest; launch → welcome → sign-up / sign-in / reset without network.

## Adding a feature

1. Contract first: add the DTO and method to `SkintelCore/API` with a decoding test.
2. If it holds state across screens, add a store in `Core/Persistence` and register it in `AppEnvironment`.
3. Build the view from `DesignSystem` components; add an `AppDestination` case if it is pushed.
4. Gate Pro features with `entitlement.isPro` + `openPaywall(.reason)`; map `APIError` to `SKErrorState`/`SKInlineError`.
5. `xcodegen generate`, run `/qa`.
