---
name: Purchase Ping (recipt-gpt-wrapper) — full project state
description: Full state of recipt-gpt-wrapper.vercel.app as of May 17 2026
type: project
originSessionId: 501fca4f-9066-4abc-86f8-2987451fc5c7
---
Receipt management app — tracks return windows, warranties. Free (10 purchases) + Pro $9/month or $79/year.

**Stack:** Next.js, Supabase, Vercel, Resend (email), Anthropic API
**Local path:** C:/Users/rrswa/recipt-gpt-wrapper/
**Live URL:** https://recipt-gpt-wrapper.vercel.app
**Vercel project ID:** prj_NewqIJJHjqpPqsp7yYIPkoRFAqeA

**Env vars — ALL SET:**
- STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, NEXT_PUBLIC_STRIPE_PRICE_ID_MONTHLY, NEXT_PUBLIC_STRIPE_PRICE_ID_YEARLY
- NEXT_PUBLIC_APP_URL, CRON_SECRET, SUPABASE_SERVICE_ROLE_KEY, NEXT_PUBLIC_SUPABASE_ANON_KEY, NEXT_PUBLIC_SUPABASE_URL
- ANTHROPIC_API_KEY, RESEND_API_KEY
- Webhook URL: https://recipt-gpt-wrapper.vercel.app/api/webhooks/stripe

**Owner free access: DONE.** rrswat00@gmail.com on Pro (user_id: c085f9d0-3c22-414f-a3ed-0043c785a9b6). Supabase: https://fgttlowgvoonedqglyle.supabase.co.

**HOMEPAGE REDESIGN: SHIPPED (May 17 2026)**
- app/components/LandingClient.tsx ('use client') — full editorial design
- CSS scoped to .lp wrapper, Google Fonts via link tags

**SMART RETAILER PARSING: SHIPPED (May 17 2026)**
- lib/merchant-parser.ts — 80+ merchant rules, normalizes names + auto-assigns system categories
- Integrated into app/app/purchases/actions.ts

**EMAIL RATE LIMIT FIX (May 17 2026):**
- Supabase free tier caps magic link emails ~3/hr
- Fix: configure Resend as custom SMTP in Supabase Auth dashboard (smtp.resend.com, port 465, user: resend, password: RESEND_API_KEY)
- Supabase project: https://supabase.com/dashboard/project/fgttlowgvoonedqglyle/settings/auth
- Status: instructions given, user needs to apply in dashboard

**DASHBOARD IMPROVEMENTS: ALL SHIPPED (May 17 2026)**
All 8 of 10 improvements implemented and deployed to production:

✅ #4 OCR progress bar — animated indeterminate bar in ReceiptInput during scan (tailwind keyframe scan-progress)
✅ #7 Category autocomplete — parseMerchant() runs client-side in PurchaseForm, shows "Auto-detected: X — apply?" badge when merchant matched and category empty
✅ #8 EmptyState feedback — converted to 'use client', useTransition spinner on "Load 5 sample items" button
✅ #9 Mobile merchant truncation — fixed flex layout in MerchantBreakdown (min-w-0 + flex-shrink-0)
✅ #11 Settings save feedback — ReminderPrefsForm extracted to SettingsClient.tsx, shows "Saved" confirmation after update
✅ #10 CSV export — GET /api/export/purchases route, "Export CSV" button added to purchases page
✅ #12 Stat cards clickable — StatCard got optional `href` prop, all 4 dashboard stat cards link to /app/purchases
✅ #2 Bulk delete — PurchaseTable converted to 'use client', checkboxes + bulk delete action (bulkDeletePurchases server action)

Still pending (need DB migration or complex logic):
- #5 Configurable horizons (need profiles table columns for return_horizon_days, warranty_horizon_days)
- #6 Recurring subscription detection

**BUG FOUND (May 17 2026):** Receipt upload fails with "Upload failed: Bucket not found"
- Supabase storage bucket "receipts" does not exist
- Fix: create manually at https://supabase.com/dashboard/project/fgttlowgvoonedqglyle/storage/buckets
- Name: receipts, Public: OFF, Size limit: 10MB, MIME: png/jpg/webp/gif/pdf
- Add RLS policies (SELECT/INSERT/DELETE authenticated): `(storage.foldername(name))[1] = auth.uid()::text`
- Status: PENDING — user notified, not yet created

**Key file locations:**
- components/PurchaseForm.tsx — OCR + category hint
- components/PurchaseTable.tsx — now 'use client' with bulk select/delete
- components/StatCard.tsx — has optional `href` prop
- components/EmptyState.tsx — 'use client' with useTransition
- app/app/settings/SettingsClient.tsx — ReminderPrefsForm with save feedback
- app/api/export/purchases/route.ts — CSV export endpoint
- app/app/purchases/actions.ts — bulkDeletePurchases added
- tailwind.config.ts — scan-progress keyframe added
