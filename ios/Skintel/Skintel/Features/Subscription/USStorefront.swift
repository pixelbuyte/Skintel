import StoreKit

/// Whether the App Store account making purchases is on the US storefront. This is the
/// *only* signal used to decide whether to show the secondary web-subscription offer on
/// the paywall — never GPS, IP address, device region, or device language, since Apple's
/// external-purchase-link allowance is tied to the App Store storefront itself, not to
/// where the device happens to be.
enum USStorefront {
    static func isActive() async -> Bool {
        await Storefront.current?.countryCode == "USA"
    }
}

/// The web-only Pro Monthly price shown on the US-storefront paywall. Apple's price is
/// always read live from StoreKit (`Product.displayPrice`) and never duplicated here — this
/// constant exists only because there is no client-side way to read the live Stripe price
/// (it lives in the Stripe dashboard, referenced by `STRIPE_PRICES.pro_monthly` in
/// `src/pages/Pricing.tsx` / `api/stripe-checkout.ts`, not in this app). Keep this in sync
/// with that Stripe price by hand.
enum WebOffer {
    static let monthlyPrice: Decimal = 8.99
    static let currencyCode = "USD"
}
