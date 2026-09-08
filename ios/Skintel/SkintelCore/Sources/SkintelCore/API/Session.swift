import Foundation

/// A Supabase (GoTrue) session. Persisted by the app in the Keychain, never UserDefaults.
public struct Session: Codable, Sendable, Hashable {
    public var accessToken: String
    public var refreshToken: String
    public var tokenType: String
    /// Absolute expiry computed at receipt from `expires_in`.
    public var expiresAt: Date
    public var user: AuthUser

    public init(accessToken: String, refreshToken: String, tokenType: String = "bearer", expiresAt: Date, user: AuthUser) {
        self.accessToken = accessToken; self.refreshToken = refreshToken; self.tokenType = tokenType
        self.expiresAt = expiresAt; self.user = user
    }

    /// Refresh a minute early so an in-flight request never carries a token that dies mid-call.
    public func isExpiring(within seconds: TimeInterval = 60, now: Date = Date()) -> Bool {
        expiresAt.timeIntervalSince(now) < seconds
    }
}

public struct AuthUser: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var email: String?
    public var userMetadata: [String: JSONValue]
    public var appMetadata: [String: JSONValue]
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case userMetadata = "user_metadata"
        case appMetadata = "app_metadata"
        case createdAt = "created_at"
    }

    public init(id: String, email: String?, userMetadata: [String: JSONValue] = [:],
                appMetadata: [String: JSONValue] = [:], createdAt: String? = nil) {
        self.id = id; self.email = email; self.userMetadata = userMetadata
        self.appMetadata = appMetadata; self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        userMetadata = (try? c.decodeIfPresent([String: JSONValue].self, forKey: .userMetadata)) ?? [:]
        appMetadata = (try? c.decodeIfPresent([String: JSONValue].self, forKey: .appMetadata)) ?? [:]
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    // MARK: user_metadata accessors (the app's profile store)

    public static let displayNameKey = "display_name"
    public static let skinTypeKey = "skin_type"
    public static let concernsKey = "concerns"
    public static let onboardingCompleteKey = "onboarding_complete"
    public static let fullNameKey = "full_name"   // set by Sign in with Apple on first sign-in

    public var displayName: String? {
        userMetadata[Self.displayNameKey]?.stringValue
            ?? userMetadata[Self.fullNameKey]?.stringValue
            ?? userMetadata["name"]?.stringValue
    }

    public var firstName: String? {
        guard let n = displayName?.split(separator: " ").first else { return nil }
        return String(n)
    }

    public var onboardingComplete: Bool {
        userMetadata[Self.onboardingCompleteKey]?.boolValue ?? false
    }

    public var skinProfile: SkinProfile {
        let t = userMetadata[Self.skinTypeKey]?.stringValue.flatMap(SkinType.init(rawValue:))
        let cs = userMetadata[Self.concernsKey]?.arrayValue?
            .compactMap { $0.stringValue.flatMap(SkinConcern.init(rawValue:)) } ?? []
        return SkinProfile(skinType: t, concerns: cs)
    }

    /// The `data` object for `PUT /auth/v1/user` that records an onboarding result.
    public static func metadataPatch(profile: SkinProfile, displayName: String?, onboardingComplete: Bool) -> [String: JSONValue] {
        var m: [String: JSONValue] = [
            Self.skinTypeKey: profile.skinType.map { .string($0.rawValue) } ?? .null,
            Self.concernsKey: .array(profile.concerns.map { .string($0.rawValue) }),
            Self.onboardingCompleteKey: .bool(onboardingComplete),
        ]
        if let displayName, !displayName.isEmpty { m[Self.displayNameKey] = .string(displayName) }
        return m
    }
}

/// Supplies a fresh bearer token to API clients. Implemented by the app's SessionManager.
public protocol TokenProvider: Sendable {
    func validAccessToken() async throws -> String
}
