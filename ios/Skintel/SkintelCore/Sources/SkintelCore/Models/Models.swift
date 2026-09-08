import Foundation

// Mirrors supabase/schema.sql and src/lib/types.ts. Timestamps stay as the
// wire strings PostgREST returns (fractional-second ISO 8601 / YYYY-MM-DD);
// use `ISO8601.date(_:)` when a Date is actually needed.

public enum Outcome: String, Codable, Sendable, CaseIterable {
    case good, bad, unsure
}

public enum Tier: String, Codable, Sendable {
    case free, pro, founding
}

public struct Product: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var userID: String
    public var brand: String?
    public var productName: String
    public var category: String?
    public var outcome: Outcome
    public var notes: String?
    public var createdAt: String
    public var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, brand, category, outcome, notes
        case userID = "user_id"
        case productName = "product_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(id: String, userID: String, brand: String?, productName: String, category: String?,
                outcome: Outcome, notes: String?, createdAt: String, updatedAt: String) {
        self.id = id; self.userID = userID; self.brand = brand; self.productName = productName
        self.category = category; self.outcome = outcome; self.notes = notes
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public struct ProductIngredient: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var productID: String
    public var userID: String
    public var position: Int
    public var inciRaw: String
    public var inciNormalized: String

    enum CodingKeys: String, CodingKey {
        case id, position
        case productID = "product_id"
        case userID = "user_id"
        case inciRaw = "inci_raw"
        case inciNormalized = "inci_normalized"
    }

    public init(id: String, productID: String, userID: String, position: Int, inciRaw: String, inciNormalized: String) {
        self.id = id; self.productID = productID; self.userID = userID
        self.position = position; self.inciRaw = inciRaw; self.inciNormalized = inciNormalized
    }
}

/// `select=*,product_ingredients(*)` row shape.
public struct ProductWithIngredients: Codable, Sendable, Identifiable, Hashable {
    public var product: Product
    public var ingredients: [ProductIngredient]

    public var id: String { product.id }

    enum CodingKeys: String, CodingKey {
        case ingredients = "product_ingredients"
    }

    public init(product: Product, ingredients: [ProductIngredient]) {
        self.product = product
        self.ingredients = ingredients.sorted { $0.position < $1.position }
    }

    public init(from decoder: Decoder) throws {
        product = try Product(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ingredients = (try c.decodeIfPresent([ProductIngredient].self, forKey: .ingredients) ?? [])
            .sorted { $0.position < $1.position }
    }

    public func encode(to encoder: Encoder) throws {
        try product.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ingredients, forKey: .ingredients)
    }
}

public struct Subscription: Codable, Sendable, Hashable {
    public var userID: String
    public var tier: Tier
    public var stripeCustomerID: String?
    public var stripeSubscriptionID: String?
    public var status: String?
    public var currentPeriodEnd: String?
    public var foundingSeatNumber: Int?
    /// Added by supabase/migrations/0004_apple_iap.sql; nil on rows written before it ran.
    public var source: String?
    public var appleOriginalTransactionID: String?
    public var appleProductID: String?
    public var createdAt: String
    public var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case tier, status, source
        case userID = "user_id"
        case stripeCustomerID = "stripe_customer_id"
        case stripeSubscriptionID = "stripe_subscription_id"
        case currentPeriodEnd = "current_period_end"
        case foundingSeatNumber = "founding_seat_number"
        case appleOriginalTransactionID = "apple_original_transaction_id"
        case appleProductID = "apple_product_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(userID: String, tier: Tier, stripeCustomerID: String? = nil, stripeSubscriptionID: String? = nil,
                status: String?, currentPeriodEnd: String? = nil, foundingSeatNumber: Int? = nil,
                source: String? = nil, appleOriginalTransactionID: String? = nil, appleProductID: String? = nil,
                createdAt: String, updatedAt: String) {
        self.userID = userID; self.tier = tier; self.stripeCustomerID = stripeCustomerID
        self.stripeSubscriptionID = stripeSubscriptionID; self.status = status
        self.currentPeriodEnd = currentPeriodEnd; self.foundingSeatNumber = foundingSeatNumber
        self.source = source; self.appleOriginalTransactionID = appleOriginalTransactionID
        self.appleProductID = appleProductID
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    /// Where the entitlement is managed: Apple (this app), Stripe (the web), or a manual grant.
    public var isManagedByApple: Bool { source == "apple" || appleOriginalTransactionID != nil }
    public var isManagedByStripe: Bool { !isManagedByApple && stripeCustomerID != nil }
}

public enum JournalCondition: String, Codable, Sendable, CaseIterable {
    case clear, mild, moderate, breakout
}

public struct JournalEntry: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var userID: String
    public var entryDate: String          // YYYY-MM-DD
    public var condition: JournalCondition
    public var notes: String?
    public var photoURL: String?
    public var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, condition, notes
        case userID = "user_id"
        case entryDate = "entry_date"
        case photoURL = "photo_url"
        case createdAt = "created_at"
    }

    public init(id: String, userID: String, entryDate: String, condition: JournalCondition,
                notes: String?, photoURL: String?, createdAt: String) {
        self.id = id; self.userID = userID; self.entryDate = entryDate; self.condition = condition
        self.notes = notes; self.photoURL = photoURL; self.createdAt = createdAt
    }
}

/// Output of the local co-occurrence engine (src/lib/correlate.ts).
public struct Culprit: Sendable, Hashable, Identifiable {
    public enum Risk: String, Sendable { case high, medium }

    public var name: String
    public var normalized: String
    public var badCount: Int
    public var goodCount: Int
    public var badProducts: [String]
    public var goodProducts: [String]
    public var risk: Risk

    public var id: String { normalized }

    public init(name: String, normalized: String, badCount: Int, goodCount: Int,
                badProducts: [String], goodProducts: [String], risk: Risk) {
        self.name = name; self.normalized = normalized; self.badCount = badCount; self.goodCount = goodCount
        self.badProducts = badProducts; self.goodProducts = goodProducts; self.risk = risk
    }
}

// MARK: - Skin profile (design §04, persisted in auth user_metadata)

public enum SkinType: String, Codable, Sendable, CaseIterable, Identifiable {
    case oily, dry, combination, sensitive, normal
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum SkinConcern: String, Codable, Sendable, CaseIterable, Identifiable {
    case breakouts, redness
    case darkSpots = "dark_spots"
    case texture
    case fineLines = "fine_lines"
    case oiliness

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .breakouts: "Breakouts"
        case .redness: "Redness"
        case .darkSpots: "Dark spots"
        case .texture: "Texture"
        case .fineLines: "Fine lines"
        case .oiliness: "Oiliness"
        }
    }
}

public struct SkinProfile: Codable, Sendable, Hashable {
    public var skinType: SkinType?
    public var concerns: [SkinConcern]

    public init(skinType: SkinType? = nil, concerns: [SkinConcern] = []) {
        self.skinType = skinType
        self.concerns = concerns
    }

    /// "Combination · breakout-prone · fragrance-sensitive"-style summary used in the found sheet.
    public var summary: String {
        var parts: [String] = []
        if let skinType { parts.append(skinType.label.lowercased()) }
        if concerns.contains(.breakouts) { parts.append("breakout-prone") }
        if concerns.contains(.redness) { parts.append("redness-prone") }
        if concerns.contains(.oiliness) { parts.append("oily") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Date helpers

public enum ISO8601 {
    // Formatters are immutable after construction and documented thread-safe for
    // parsing/formatting, which is all they are used for here.
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    nonisolated(unsafe) private static let dayOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Parses PostgREST timestamps (with or without fractional seconds) and `date` columns.
    public static func date(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        if let d = fractional.date(from: s) { return d }
        if let d = plain.date(from: s) { return d }
        // Postgres emits "+00:00"; ISO8601DateFormatter wants "Z" or "+0000" in some Foundation builds.
        let compact = s.replacingOccurrences(of: "+00:00", with: "Z")
        if let d = fractional.date(from: compact) { return d }
        if let d = plain.date(from: compact) { return d }
        return dayOnly.date(from: s)
    }

    /// YYYY-MM-DD in UTC — the shape `/api/journal` expects for `entryDate`.
    public static func dayString(_ date: Date) -> String {
        dayOnly.string(from: date)
    }
}
