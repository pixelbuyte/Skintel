# App Store Connect: welcome-wheel offer codes

`wheel-offers.ts` creates three subscription **offer codes** on `com.skintel.app.pro.monthly`
for the future welcome wheel, through the App Store Connect API. It touches no app, API or
Codemagic code.

| Offer (reference name) | Mode | Length | Price |
|---|---|---|---|
| Wheel - 3 days free | free trial | 3 days | free |
| Wheel - 7 days free | free trial | 1 week | free |
| Wheel - 50% off first month | pay as you go | 1 x 1 month | closest App Store price point to 50% of the current monthly price, per storefront |

All three: **new subscribers only**, **cannot combine with an introductory offer**
(`offerEligibility: REPLACE_INTRO_OFFERS`), every territory the subscription is sold in.

Promotional offers are not used (existing/lapsed subscribers only). The app is not live yet,
so the offers exist but cannot be redeemed until it is Ready for Sale.

## 1. Create an API key

App Store Connect > **Users and Access** > **Integrations** > **App Store Connect API** >
**Team Keys** > **Generate API Key**. Name it anything, role **App Manager**.

You get an **Issuer ID** (top of the page), a **Key ID**, and a one-time `.p8` download.
Apple lets you download the `.p8` only once. Keep it outside the repo.

```bash
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_ID=ABC123DEFG
export ASC_PRIVATE_KEY_PATH=$HOME/keys/AuthKey_ABC123DEFG.p8
```

Credentials are read only from these variables. The script never prints or logs the key.
Revoke the key in App Store Connect when you are done.

## 2. Create the offers

Needs Node 22.18+ (runs TypeScript directly, no `npm install` step).

```bash
# Dry run first: read-only, prints what it would create
node scripts/asc/wheel-offers.ts create --dry-run
node scripts/asc/wheel-offers.ts create --dry-run --verbose   # every territory's 50% price

# For real
node scripts/asc/wheel-offers.ts create
```

It checks the subscription exists (exact product id) and lists existing offer codes. Offers
are matched by reference name, so running it twice creates no duplicates. An existing offer
is never modified; if its settings differ from the spec, the script warns.

Check the 50% table in the dry run before the real run: it uses the closest available price
point per storefront, and skips any territory with no current price.

## 3. One-time-use codes (run near launch)

One-time-use codes **expire**, so do this shortly before you need them.

```bash
node scripts/asc/wheel-offers.ts codes --dry-run
node scripts/asc/wheel-offers.ts codes --count 500 --expires 2027-03-01
```

- `--count` codes per offer (default 500), `--expires YYYY-MM-DD` (default: 180 days out).
  Apple enforces its own limits on count and expiry and returns an error if exceeded.
- `--sandbox` generates sandbox codes for testing instead of production ones.
- Writes one CSV per offer to `scripts/asc/out/` (gitignored, mode 0600). Codes are never
  printed. Treat the files as secrets.
- If an offer already has an active batch, it is skipped. Add `--allow-another-batch` to
  generate more.

## Not verified against the live API

These points come from Apple's OpenAPI spec (v4.5) but have not been run with a real key:

- **Free-trial prices.** For the two free offers the script sends one price entry per
  territory with a territory and no price point (the price point is optional in the schema).
  If Apple rejects this, the error is printed and nothing is created for that offer; create
  the two free offers in the App Store Connect website instead.
- **Territory list.** Taken from the subscription's availability; the subscription must have
  availability set.
