# App Store Connect scripts

These scripts configure **Skintel+** subscription offer-code offers for the app with bundle ID `com.skintel.app`. They do not modify app, API, or Codemagic code.

## Create an API key

In App Store Connect, go to **Users and Access → Integrations**, create an **App Store Connect API** key with the **App Manager** role, and download its `.p8` private key. Store the file outside this repository.

Set these environment variables in the shell where you run the scripts:

```powershell
$env:ASC_ISSUER_ID = 'your-issuer-id'
$env:ASC_KEY_ID = 'your-key-id'
$env:ASC_PRIVATE_KEY_PATH = 'C:\secure\AuthKey_ABC123.p8'
```

The scripts read the values only from those environment variables. They never print, log, or write the private key.

## Create the wheel offers

Run a read-only dry run first. It verifies the bundle ID, the three configured product IDs, the monthly product, its availability, and existing offer names. A dry run makes no write requests.

```powershell
node --experimental-strip-types scripts/asc/wheel-offers.ts --dry-run
```

Then create only the missing offers:

```powershell
node --experimental-strip-types scripts/asc/wheel-offers.ts
```

The script is idempotent by offer reference name and creates these offers only on `com.skintel.app.pro.monthly`:

- `Wheel - 3 days free`: `FREE_TRIAL`, three days.
- `Wheel - 7 days free`: `FREE_TRIAL`, one week.
- `Wheel - 50% off first month`: `PAY_AS_YOU_GO`, one monthly period. It reads each sold storefront’s current price and selects the nearest App Store subscription price point to half of that storefront’s price.

All three are limited to new subscribers (`NEW`) and use `REPLACE_INTRO_OFFERS`, which means a redeemer does **not** combine the code with an introductory offer. Each uses all territories where the monthly subscription is currently sold.

## Generate one-time-use codes near launch

Do not generate production codes until the app is Ready for Sale. Apple requires an expiration date and limits one-time-use batches to 500–25,000 codes with a maximum six-month validity window.

```powershell
node --experimental-strip-types scripts/asc/generate-wheel-offer-codes.ts --offer "Wheel - 3 days free" --count 500 --expires 2027-03-01 --dry-run
node --experimental-strip-types scripts/asc/generate-wheel-offer-codes.ts --offer "Wheel - 3 days free" --count 500 --expires 2027-03-01
```

Run the generation command separately for each wheel offer. Apple creates the code values; this script intentionally does not print them. Download the resulting CSV from App Store Connect before distribution.

## API references

The request shapes were checked against Apple’s current App Store Connect OpenAPI specification, including `subscriptionOfferCodes`, `subscriptionOfferCodeOneTimeUseCodes`, and `subscriptionPricePoints`:

- [Create a subscription offer](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-subscriptionoffercodes)
- [Create one-time-use offer codes](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-subscriptionoffercodeonetimeusecodes)
- [Subscription price points](https://developer.apple.com/documentation/appstoreconnectapi/subscriptionpricepoint)
