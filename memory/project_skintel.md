---
name: Skintel Project
description: Skincare ingredient correlation SaaS — production deployed, Pro billing live, owner has lifetime pro grant
type: project
originSessionId: 9ac1e8e3-400f-46ec-97d8-ae0115e52adf
---
**What:** Skintel — Vite+React+TS+Tailwind SPA, Supabase (auth/Postgres/RLS), Stripe billing, deployed Vercel.

**Repo:** github.com/pixelbuyte/Skintel
**Local:** C:/Users/rrswa/skintel/
**Prod:** https://skintel-six.vercel.app
**Supabase project ref:** fgttlowgvoonedqglyle
**Vercel team/project:** team_kvUSdDPuWTYwAJnJ93cE8wWY / prj_C7Ypb9fucaN0zItkK6QqMmMFWMQV

**Auth:** Google OAuth only (magic link removed). Supabase shared OAuth app or custom Google client requires `https://fgttlowgvoonedqglyle.supabase.co/auth/v1/callback` in Google redirect URIs.

**Billing:** Stripe LIVE keys in Vercel env. Pro Monthly $9 (`VITE_STRIPE_PRICE_PRO`), Pro Yearly $79 (`VITE_STRIPE_PRICE_PRO_YEARLY`). Founding tier deferred. Webhook secret in `STRIPE_WEBHOOK_SECRET`.

**API style:** Vercel Node runtime, handlers use `(req: VercelRequest, res: VercelResponse)` signature. Relative imports use `.js` extension (ESM strict). Webhook needs `export const config = { api: { bodyParser: false } }` + `readRawBody(req)` helper from `_lib.ts`.

**Owner pro grant:** rrswat00@gmail.com (user_id `c085f9d0-3c22-414f-a3ed-0043c785a9b6`) — tier=pro, status=active, current_period_end=2028-05-21. No Stripe customer, direct DB upsert.

**Why:** Owner gets indefinite pro access without Stripe charge for dev/testing.

**How to apply:** When working on Skintel, treat rrswat00@gmail.com as pro user. When adding pricing changes, update Pricing.tsx + stripe-prices.ts + webhook tierFromPriceId(). When adding api routes, use VercelRequest/Response signature + `.js` extension on imports.
