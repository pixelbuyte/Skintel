---
name: Skintel Build Session May 20 2026
description: Full session log — Skintel built end-to-end, deployed to Vercel prod, Stripe live, OAuth flipped, pro grant + memory MCPs added
type: project
originSessionId: 9ac1e8e3-400f-46ec-97d8-ae0115e52adf
---
# Skintel Build Session — May 20 2026

## What shipped
- Vite + React 19 + TS + Tailwind v3 SPA scaffolded at `C:/Users/rrswa/skintel/`
- Repo pushed: `github.com/pixelbuyte/Skintel`
- Production: `https://www.skinstel.com`
- Domain: skinstel.com (custom; apex 308-redirects to www)
- Project IDs: Vercel `prj_C7Ypb9fucaN0zItkK6QqMmMFWMQV` / team `team_kvUSdDPuWTYwAJnJ93cE8wWY`; Supabase ref `fgttlowgvoonedqglyle`

## Routes
- `/` Landing (hero, how-it-works, Pro pricing teaser, FAQ, footer — founding section removed)
- `/login` Google OAuth one-click (magic link removed)
- `/auth/callback` OAuth handler (exchangeCodeForSession + onAuthStateChange wait, fixes redirect-back-to-login race)
- `/pricing` 3 cards: Free, Pro Monthly $9 (highlighted), Pro Yearly $79 (Save $29 badge)
- `/checkout/success` auto-redirect to /app after 2.5s
- `/app/*` protected (Layout + Sidebar): Dashboard, ProductsList, AddProduct, EditProduct, Culprits, Scanner, Settings

## API (Vercel Node, `(req: VercelRequest, res: VercelResponse)` signature)
- `/api/stripe-checkout` — creates subscription Checkout Session
- `/api/stripe-portal` — Billing Portal session
- `/api/stripe-webhook` — `bodyParser: false`, raw body via `readRawBody(req)`, dual-secret rotation, idempotency via `processed_webhook_events`
- `/api/founding-count` — RPC `founding_seats_remaining`
- `/api/export-data` — JSON export with content-disposition
- `/api/delete-account` — service-role cascade delete + auth.admin.deleteUser

## Key bugs fixed this session
1. **TS 6 baseUrl deprecation** → `"ignoreDeprecations": "6.0"` in tsconfig.app.json
2. **Stripe v22 `Invoice.subscription` removed from type** → cast `as Stripe.Invoice & { subscription?: string | Stripe.Subscription | null }`
3. **Google OAuth redirect_uri_mismatch** → user must add `https://fgttlowgvoonedqglyle.supabase.co/auth/v1/callback` to Google Cloud Console OR use Supabase shared OAuth app
4. **Post-login redirect bounced back to /login** → AuthCallback now subscribes to `onAuthStateChange`, waits for session before nav to /app
5. **/api/stripe-checkout 500 ERR_MODULE_NOT_FOUND** → added `.js` extension to all relative imports in api/*.ts (ESM strict)
6. **/api/stripe-checkout 500 TypeError req.headers.get is not a function** → Vercel Node passes IncomingMessage not Web Request. Rewrote ALL handlers to VercelRequest/VercelResponse signature. `_lib.ts` helpers updated: `getUserFromAuthHeader(req)` uses `req.headers.authorization`, `json(res, body, status)` uses `res.status().send()`, added `readRawBody(req)` for webhook.

## Stripe (LIVE keys in Vercel + .env.local)
- `STRIPE_SECRET_KEY=sk_live_51SwDDKRrTdDFA54j...` (live)
- `VITE_STRIPE_PRICE_PRO=price_1TXbWORrTdDFA54jrnZ8LzO2` (monthly $9)
- `VITE_STRIPE_PRICE_PRO_YEARLY=price_1TXbrZRrTdDFA54jxPjgyGzc` (yearly $79)
- `STRIPE_WEBHOOK_SECRET=whsec_CckUBltwRBcB3ETTSy7lmWfQopVhfUoe`
- Founding tier deferred per user decision

## Supabase
- Switched to existing project `fgttlowgvoonedqglyle` (user has "custom subscription stuff" pre-existing — Skintel schema compatible, migration ran successfully)
- Tables: `products`, `product_ingredients`, `subscriptions`, `processed_webhook_events`
- RLS: own-row only; subscriptions read-own (writes via service role webhook)
- RPC: `founding_seats_remaining()` security-definer
- Trigger: `enforce_free_product_limit` (max 5 products free tier)
- Service role key + anon key both in `.env.local` and Vercel env

## Verified working
- `npm run build` clean
- Endpoint tested: created test user via admin API → signInWithPassword → POST /api/stripe-checkout with bearer → **HTTP 200 + real Stripe Checkout URL** (cs_live_b1K6...) → cleaned up test user

## Owner pro grant
- Email: `rrswat00@gmail.com`
- user_id: `c085f9d0-3c22-414f-a3ed-0043c785a9b6`
- Direct upsert to `subscriptions`: tier=pro, status=active, current_period_end=2028-05-21
- No Stripe customer linked — pure DB grant for dev/testing
- Effect: scanner unlocked, no 5-product cap

## Memory MCPs wired this session
- `memory-kg` — `@modelcontextprotocol/server-memory` (knowledge graph)
- `mem0` — `mem0-mcp` (sqlite + Ollama embeddings)
- Both stdio in `C:/Users/rrswa/.claude.json` under project `C:/Users/rrswa/skintel`
- **Gotcha:** `claude mcp add` on Windows mangles `cmd /c` → `cmd C:/`. Patched args directly to `["/c", "npx", "-y", "<pkg>"]`. Both ✓ Connected after fix.
- Restart Claude Code to load `mcp__memory-kg__*` and `mcp__mem0__*` tools.

## Key files (full paths)
- `C:/Users/rrswa/skintel/api/_lib.ts` — helpers (getServiceClient, getUserFromAuthHeader, json, appUrl, readRawBody)
- `C:/Users/rrswa/skintel/api/stripe-checkout.ts`
- `C:/Users/rrswa/skintel/api/stripe-webhook.ts`
- `C:/Users/rrswa/skintel/api/stripe-portal.ts`
- `C:/Users/rrswa/skintel/api/export-data.ts`
- `C:/Users/rrswa/skintel/api/delete-account.ts`
- `C:/Users/rrswa/skintel/api/founding-count.ts`
- `C:/Users/rrswa/skintel/src/lib/stripe-prices.ts`
- `C:/Users/rrswa/skintel/src/hooks/useAuth.tsx` (signInWithGoogle)
- `C:/Users/rrswa/skintel/src/pages/{Landing,Pricing,Settings,CheckoutSuccess,Login,AuthCallback}.tsx`
- `C:/Users/rrswa/skintel/.env.local`
- `C:/Users/rrswa/skintel/vercel.json`
- `C:/Users/rrswa/skintel/supabase/schema.sql`
- Plan file: `C:/Users/rrswa/.claude/plans/claude-code-master-fancy-treasure.md`

## Pending / Next session
- Confirm Stripe webhook endpoint registered at `https://www.skinstel.com/api/stripe-webhook` in Stripe dashboard (events: checkout.session.completed, customer.subscription.*, invoice.payment_succeeded)
- Confirm Supabase Auth redirect URLs include `https://www.skinstel.com/auth/callback`
- Add Founding tier later when user requests
- Optional: cron-dump session transcripts to mem0 for full-recall

## Last git commit
- `7b76ae1` fix(api): rewrite handlers to Vercel Node (VercelRequest/Response) signature
- Branch: main, pushed to origin

## How to apply
When resuming: tier=pro owner is already set, do not re-grant. When adding routes use `(req: VercelRequest, res: VercelResponse)` + `.js` extension on relative imports. When testing checkout, use admin-created test user + service-role-signed token, not the owner account (avoids polluting real subscription row).
