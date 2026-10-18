# Email setup

All Skintel email goes out through **Resend** from `hello@skinstel.com`.

## Status (checked 2026-10-18)

| Item | State |
|---|---|
| Resend DKIM (`resend._domainkey`) | ✅ published |
| Resend return path (`send.skinstel.com` MX + SPF) | ✅ published |
| DMARC (`_dmarc`) | ✅ `p=quarantine` |
| `RESEND_API_KEY` in Vercel | ✅ set |
| Inbox for `hello@skinstel.com` (root MX) | ❌ none — replies bounce |

## 1. Receive replies at hello@skinstel.com

DNS is at GoDaddy (`domaincontrol.com`). Pick one:
- **Free:** GoDaddy → Domain → Forwarding → Email forwarding, `hello@` → your Gmail.
- **Real mailbox:** Google Workspace or Zoho Mail. Add their MX records, and add their
  SPF `include:` to the root TXT record.

## 2. Auth emails (confirm sign-up, reset password)

**Use Resend as SMTP:** Supabase → Authentication → Emails → SMTP Settings → enable custom SMTP:

| Field | Value |
|---|---|
| Sender email | `hello@skinstel.com` |
| Sender name | `Skintel` |
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | a Resend API key (Sending access, domain skinstel.com) |

This also lifts Supabase's built-in limit of a few emails per hour.

**Paste the templates:** Authentication → Emails → Templates, one per template:

| Supabase template | File | Subject |
|---|---|---|
| Confirm signup | `supabase/templates/confirm-signup.html` | Confirm your Skintel email |
| Reset password | `supabase/templates/reset-password.html` | Reset your Skintel password |
| Magic link | `supabase/templates/magic-link.html` | Your Skintel sign-in link |
| Change email address | `supabase/templates/change-email.html` | Confirm your new Skintel email |
| Reauthentication | `supabase/templates/reauthentication.html` | Your Skintel verification code |
| Invite user | `supabase/templates/invite.html` | You're invited to Skintel |

## 3. Welcome email (sent once, after the email is confirmed)

1. Generate a long random secret (e.g. `openssl rand -hex 32`).
2. Vercel → skintel → Settings → Environment Variables → add `EMAIL_WEBHOOK_SECRET` (Production),
   then redeploy.
3. Supabase SQL editor: `select vault.create_secret('<same secret>', 'email_webhook_secret');`
4. Run `supabase/migrations/0005_welcome_email.sql` in the SQL editor.

Flow: an `auth.users` trigger → pg_net POST → `/api/account?action=welcome` → Resend.

- The API reads the address from `auth.users`.
- `processed_webhook_events` dedupes, so each user gets at most one welcome.
- A failed send never blocks sign-up.

**Sign in with Apple users who hide their email** get an `@privaterelay.appleid.com` address.
Apple only forwards mail from registered senders. Register them in Apple Developer →
Certificates, IDs & Profiles → Services → *Sign in with Apple for Email Communication*:
add the domain `skinstel.com` and the email `hello@skinstel.com`. Apple checks SPF/DKIM,
which are already in place.

## 4. Marketing / lifecycle emails (next)

Not built yet. They need:
- **Consent:** an opt-in setting in the app.
- **Unsubscribe:** a one-click link and the `List-Unsubscribe` header, required by CAN-SPAM
  and by Gmail/Yahoo's bulk-sender rules.
- **Sending:** Resend Audiences and Broadcasts.

Candidates:
- 3-day "how's your skin?" nudge for users with no check-ins.
- Weekly Triggers digest for Skintel+ members.
