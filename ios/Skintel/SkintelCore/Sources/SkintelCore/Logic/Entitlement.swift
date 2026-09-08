import Foundation

/// Access rules derived from the `subscriptions` row.
///
/// The web hook (`useSubscription.ts`) checks `tier` only; the API (`api/*.ts`) checks
/// `tier` AND `status`. A cancelled Pro therefore looks paid in the web UI and then gets
/// 402 from every scan. This type implements the **server's** rule so the app never
/// promises something the backend will refuse.
public struct Entitlement: Sendable, Hashable {
    public static let freeProductLimit = 5
    public static let foundingSeatsTotal = 500
    public static let activeStatuses: Set<String> = ["active", "trialing"]

    public let subscription: Subscription?

    public init(_ subscription: Subscription?) {
        self.subscription = subscription
    }

    public var tier: Tier { subscription?.tier ?? .free }

    /// Server rule (`api/_lib` consumers): status ∈ {active, trialing} AND tier ∈ {pro, founding}.
    public var isPro: Bool {
        guard let s = subscription else { return false }
        let active = Self.activeStatuses.contains(s.status ?? "")
        return active && (s.tier == .pro || s.tier == .founding)
    }

    /// Web rule, kept for the one place the web shows it (tier label in Settings).
    public var isPaidTier: Bool { tier == .pro || tier == .founding }

    public var canUseScanner: Bool { isPro }

    /// nil = unlimited.
    public var productLimit: Int? { isPro ? nil : Self.freeProductLimit }

    public func canAddProduct(currentCount: Int) -> Bool {
        guard let limit = productLimit else { return true }
        return currentCount < limit
    }

    public var periodEnd: Date? { ISO8601.date(subscription?.currentPeriodEnd) }

    /// Human tier label matching `Settings.tsx`.
    public var tierLabel: String {
        switch tier {
        case .free: "Free"
        case .pro: "Pro"
        case .founding: "Founding member"
        }
    }
}
