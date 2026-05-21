---
name: Subs Tracker - Full Project Context
description: Complete setup of subs-tracker-two.vercel.app including Stripe integration
type: project
originSessionId: 501fca4f-9066-4abc-86f8-2987451fc5c7
---
Subscription Control Center — tracks recurring subs, prevents overspending. Free tier (5 subs) + Pro $8.99/month.

**Stack:** Next.js 16, Supabase (DB + auth + RLS), Vercel, Stripe

**Local path:** C:/Users/rrswa/subs,tracker/
**Live URL:** https://subs-tracker-two.vercel.app
**Vercel project ID:** prj_QA2URHrNZtzQ2FiZmwD1t06Bs9oR
**Team:** pixelbuytes-projects (team_kvUSdDPuWTYwAJnJ93cE8wWY)

**Stripe integration — FULLY WORKING (May 16 2026)**
All 5 env vars on Vercel production:
- STRIPE_SECRET_KEY ✅ (rotated May 16)
- NEXT_PUBLIC_STRIPE_PRICE_PRO ✅ price_1TR2bqRrTdDFA54jq8KvaQxa
- STRIPE_WEBHOOK_SECRET ✅ (new endpoint created May 16)
- NEXT_PUBLIC_APP_URL ✅ https://subs-tracker-two.vercel.app
- SUPABASE_SERVICE_ROLE_KEY ✅ (added May 16 — rotate this key)

Webhook endpoint: https://subs-tracker-two.vercel.app/api/stripe/webhook
Events: checkout.session.completed, customer.subscription.updated, customer.subscription.deleted

**Key API routes:**
- /api/stripe/checkout — creates Stripe checkout session
- /api/stripe/webhook — handles Stripe events
- /api/stripe/portal — customer billing portal
- /api/debug/stripe-env — debug env vars

**How to apply:** When working on this project, use `npx vercel` (not global vercel) from C:/Users/rrswa/subs,tracker/. Project is linked to Vercel. Env vars managed via `npx vercel env add/rm`.

**Email reminders (Resend) — IN PROGRESS:**
- RESEND_API_KEY ✅ added (re_Y6TdBFp9_...)
- EMAIL_FROM ❌ missing — awaiting user's from address. Options: own domain (reminders@domain.com, needs Resend verification) or onboarding@resend.dev (test only)
- CRON_SECRET ✅ already set
- Reminder system built-in: fires at 7, 3, 1, 0 days before renewal. Pro users only.

**Owner free access: DONE.** rrswat00@gmail.com on Pro (user_id: 12da4ce0-4135-47e7-a374-3cf741a4e6c5, sub_1TXkSoRrTdDFA54jIdWBBLlH, 2yr trial). Supabase: https://everckcufihrsqssjdqz.supabase.co

**Stripe checkout slowness:** Cold start issue on Vercel free tier — 2-4s first load, normal after. Fix: add loading spinner to upgrade button. No errors in logs.

**Stripe integration workflow for future sites (same Stripe account):**
User only needs to provide: price ID + which Vercel site. Claude handles everything else automatically (finds code, creates webhook, adds env vars, deploys, fixes errors via logs). Secret key reusable across same Stripe account.
