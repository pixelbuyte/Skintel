---
name: Stripe Payment Setup May 15 2026
description: User exploring Stripe payment integration for their website
type: project
originSessionId: 501fca4f-9066-4abc-86f8-2987451fc5c7
---
User asked how to set up Stripe payment links for a website. Explained 3 options: Payment Links (no-code), Checkout (redirect), Elements (embedded).

Site: subs-tracker-two.vercel.app — Next.js app at C:/Users/rrswa/subs,tracker/, hosted on Vercel (prj_QA2URHrNZtzQ2FiZmwD1t06Bs9oR), team: pixelbuytes-projects.

Stripe already coded into the app — just missing 3 env vars:
- STRIPE_SECRET_KEY (sk_live_xxx from Stripe Dashboard → API Keys)
- NEXT_PUBLIC_STRIPE_PRICE_PRO (price_xxx from Stripe product)
- STRIPE_WEBHOOK_SECRET (whsec_xxx — webhook URL: https://subs-tracker-two.vercel.app/api/webhooks/stripe, events: checkout.session.completed, customer.subscription.updated, customer.subscription.deleted)

DONE: All 3 env vars added via CLI + redeployed to production (dpl_4oPaJhxouzSvpiwRfWzCuM1aGxJB). Site live at subs-tracker-two.vercel.app.

OUTSTANDING: Stripe webhook destination URL wrong — set to site root, needs to be https://subs-tracker-two.vercel.app/api/stripe/webhook. User must fix in Stripe Dashboard → Developers → Webhooks.

SECURITY: STRIPE_SECRET_KEY rotated and redeployed (dpl_GjgiV2bdd7yxXMjQiNcQ35ZjsRyx). STRIPE_WEBHOOK_SECRET still needs rotation.

FULLY WORKING. Stripe checkout redirects correctly. All 5 env vars confirmed on Vercel production:
- STRIPE_SECRET_KEY ✅ (rotated)
- NEXT_PUBLIC_STRIPE_PRICE_PRO ✅ (price_1TR2bqRrTdDFA54jq8KvaQxa)
- STRIPE_WEBHOOK_SECRET ✅ (rotated, whsec_2Ryc8K1weOyXwRj3pxAK8GReJ2b4dYWY — rotate this too)
- NEXT_PUBLIC_APP_URL ✅
- SUPABASE_SERVICE_ROLE_KEY ✅

Webhook URL: https://subs-tracker-two.vercel.app/api/stripe/webhook
Events: checkout.session.completed, customer.subscription.updated, customer.subscription.deleted

**Why:** User wants customers to pay on their website.

**How to apply:** If user continues Stripe work, ask for their stack and implement the appropriate option. Default recommendation was Payment Links for simplicity. Next immediate step is getting the price_xxx ID from the product.
