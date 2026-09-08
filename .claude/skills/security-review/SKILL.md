---
name: security-review
description: Security and privacy audit of the Skintel iOS app and its backend routes — auth, Keychain, tokens, secrets, Supabase RLS assumptions, image handling, logging, StoreKit verification, account deletion, privacy manifest. Flags any secret in the bundle immediately.
---

# /security-review

Hard rules to verify first (fail loudly if violated):
- No secret in `ios/Skintel/**`: grep for `sk_live`, `sk_test`, `service_role`, `whsec_`, `ANTHROPIC`, `RESEND`.
  The Supabase **anon** key is public by design and allowed; nothing else is.
- Session lives only in `KeychainSessionStore`; grep for `UserDefaults` and confirm it holds prefs only.
- Production logging (`DebugLog`, `LogAnalytics`) never includes tokens, headers, bodies, INCI text or journal notes.

Then audit:
- **Auth** — GoTrue flows, refresh coalescing, sign-out clears Keychain, Apple nonce (raw to Supabase, SHA-256 to Apple).
- **Backend trust** — every `/api` call carries the bearer; Pro gate is server-side (402). RLS policies in `supabase/schema.sql`
  cover every table the app touches; `user_id` is sent on inserts because `with check` requires it.
- **StoreKit** — `api/_apple.ts` verifies JWS against Apple Root CA G3; `appAccountToken` must equal the bearer user id;
  the app never grants Pro locally. Notifications are idempotent via `processed_webhook_events`.
- **Images** — label photos are resized (`ImageResizer`) and sent for OCR only; nothing is written to the photo library;
  temp files are not retained.
- **Deletion** — `/api/delete-account` removes subscriptions, products, auth user; journal cascades via FK. Confirm.
- **Privacy manifest** — `PrivacyInfo.xcprivacy` declares only APIs actually used and data actually sent.
- **Transport** — HTTPS only; no ATS exceptions in `project.yml`.

Report: Critical · High · Medium · Low, each with file:line and the fix. Apply fixes for anything Critical/High
that is purely an implementation defect; describe the rest.
