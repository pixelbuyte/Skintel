import Foundation

/// Every failure the app can show. HTTP statuses are mapped once, here, so views never
/// look at status codes: 402 is the paywall, `FREE_PLAN_LIMIT` is the paywall, 401 is
/// sign-in, everything else is a message + retry.
public enum APIError: Error, Sendable, Equatable {
    case unauthenticated
    case proRequired
    case freePlanLimit
    case notFound(String?)
    case unprocessable(String?)
    case conflict(String?)
    case badRequest(String?)
    case rateLimited
    case server(status: Int, message: String?)
    case network(String)
    case offline
    case decoding(String)
    case cancelled

    public var requiresPaywall: Bool {
        self == .proRequired || self == .freePlanLimit
    }

    public var userMessage: String {
        switch self {
        case .unauthenticated: "Please sign in again."
        case .proRequired: "This needs Skintel Pro."
        case .freePlanLimit: "Free plans hold 5 products. Upgrade to add more."
        case .notFound(let m): m ?? "Not found."
        case .unprocessable(let m): m ?? "That couldn't be read."
        case .conflict(let m): m ?? "That's no longer available."
        case .badRequest(let m): m ?? "Something in the request wasn't right."
        case .rateLimited: "Too many requests. Give it a moment."
        case .server(_, let m): m ?? "Skintel's server had a problem. Try again."
        case .network(let m): m
        case .offline: "You're offline."
        case .decoding: "Unexpected reply from the server."
        case .cancelled: "Cancelled."
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .network, .offline, .rateLimited, .server: true
        default: false
        }
    }
}
