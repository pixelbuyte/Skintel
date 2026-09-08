import Foundation

// Response shapes of /api/*.ts, decoded defensively where the field is LLM-produced.

// MARK: Lookup

public struct BarcodeLookup: Codable, Sendable, Hashable {
    public var brand: String?
    public var productName: String?
    public var ingredients: String
    public var source: String?

    public init(brand: String?, productName: String?, ingredients: String, source: String?) {
        self.brand = brand; self.productName = productName; self.ingredients = ingredients; self.source = source
    }
}

public struct ProductSearchResult: Codable, Sendable, Hashable, Identifiable {
    public var code: String?
    public var productName: String?
    public var brand: String?
    public var ingredients: String?
    public var imageUrl: String?
    public var id: String { code ?? "\(brand ?? "")|\(productName ?? "")" }
}

public struct ProductSearchResponse: Codable, Sendable {
    public var results: [ProductSearchResult]
}

public struct URLImport: Codable, Sendable, Hashable {
    public var brand: String?
    public var productName: String?
    public var ingredients: String
}

// MARK: Scan (AI verdict)

public enum ScanVerdict: String, Codable, Sendable {
    case clean, caution, avoid

    public init(from decoder: Decoder) throws {
        let s = (try? decoder.singleValueContainer().decode(String.self))?.lowercased() ?? "caution"
        self = ScanVerdict(rawValue: s) ?? (s.contains("avoid") || s.contains("bad") ? .avoid : s.contains("clean") || s.contains("good") ? .clean : .caution)
    }

    public var label: String {
        switch self {
        case .clean: "Good match"
        case .caution: "Caution"
        case .avoid: "Avoid"
        }
    }
}

public enum FlagLevel: String, Codable, Sendable {
    case high, medium, low

    public init(from decoder: Decoder) throws {
        let s = (try? decoder.singleValueContainer().decode(String.self))?.lowercased() ?? "low"
        self = FlagLevel(rawValue: s) ?? (s.contains("high") ? .high : s.contains("med") ? .medium : .low)
    }
}

public struct ScanFlag: Codable, Sendable, Hashable, Identifiable {
    public var ingredient: String
    public var level: FlagLevel
    public var reason: String
    public var source: String?
    public var id: String { ingredient + reason }

    public init(ingredient: String, level: FlagLevel, reason: String, source: String? = nil) {
        self.ingredient = ingredient; self.level = level; self.reason = reason; self.source = source
    }
}

public struct ScanResult: Codable, Sendable, Hashable {
    public var verdict: ScanVerdict
    public var score: Int
    public var summary: String
    public var flags: [ScanFlag]
    public var notes: String?

    enum CodingKeys: String, CodingKey { case verdict, score, summary, flags, notes }

    public init(verdict: ScanVerdict, score: Int, summary: String, flags: [ScanFlag], notes: String?) {
        self.verdict = verdict; self.score = score; self.summary = summary; self.flags = flags; self.notes = notes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        verdict = (try? c.decode(ScanVerdict.self, forKey: .verdict)) ?? .caution
        let n = (try? c.decode(FlexibleNumber.self, forKey: .score))?.value ?? 0
        score = max(0, min(100, Int(n.rounded())))
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        flags = (try? c.decode([ScanFlag].self, forKey: .flags)) ?? []
        notes = try? c.decodeIfPresent(String.self, forKey: .notes)
    }

    public var highCount: Int { flags.filter { $0.level == .high }.count }
    public var mediumCount: Int { flags.filter { $0.level == .medium }.count }
    public var lowCount: Int { flags.filter { $0.level == .low }.count }
}

public struct ScanAIRequest: Encodable, Sendable {
    public struct Match: Encodable, Sendable {
        public var name: String
        public var risk: String
        public var badCount: Int
        public init(_ c: Culprit) { name = c.name; risk = c.risk.rawValue; badCount = c.badCount }
    }
    public var inci: String
    public var matches: [Match]
    public init(inci: String, matches: [Match]) { self.inci = inci; self.matches = matches }
}

public struct ScanAIResponse: Codable, Sendable {
    public var result: ScanResult
    public var model: String?
}

public struct PhotoScanResult: Codable, Sendable, Hashable {
    public var brand: String?
    public var productName: String?
    public var ingredients: String
}

public struct PhotoScanResponse: Codable, Sendable {
    public var result: PhotoScanResult
}

// MARK: Journal

public struct JournalEntriesResponse: Codable, Sendable { public var entries: [JournalEntry] }
public struct JournalEntryResponse: Codable, Sendable { public var entry: JournalEntry }

public struct JournalSuspect: Codable, Sendable, Hashable, Identifiable {
    public var productOrIngredient: String
    public var confidence: FlexibleNumber?
    public var reasoning: String?
    public var evidenceDates: FlexibleStrings?
    public var id: String { productOrIngredient }

    /// 0–100
    public var confidencePercent: Int? {
        guard let v = confidence?.value else { return nil }
        return Int((v <= 1 ? v * 100 : v).rounded())
    }
}

public struct JournalAnalysis: Codable, Sendable, Hashable {
    public var summary: String?
    public var suspects: [JournalSuspect]
    public var patterns: FlexibleStrings?
    public var recommendations: FlexibleStrings?

    enum CodingKeys: String, CodingKey { case summary, suspects, patterns, recommendations }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try? c.decodeIfPresent(String.self, forKey: .summary)
        suspects = (try? c.decode([JournalSuspect].self, forKey: .suspects)) ?? []
        patterns = try? c.decodeIfPresent(FlexibleStrings.self, forKey: .patterns)
        recommendations = try? c.decodeIfPresent(FlexibleStrings.self, forKey: .recommendations)
    }
}

public struct JournalAnalysisResponse: Codable, Sendable { public var result: JournalAnalysis }

// MARK: Routine

public struct RoutineConflict: Codable, Sendable, Hashable, Identifiable {
    public var products: FlexibleStrings?
    public var issue: String
    public var severity: String?
    public var fix: String?
    public var id: String { issue }

    public var isHigh: Bool { (severity ?? "").lowercased().contains("high") }
}

public struct RoutineAnalysis: Codable, Sendable, Hashable {
    public var amVerdict: String?
    public var pmVerdict: String?
    public var conflicts: [RoutineConflict]
    public var redundancies: FlexibleStrings?
    public var suggestions: FlexibleStrings?

    enum CodingKeys: String, CodingKey { case amVerdict, pmVerdict, conflicts, redundancies, suggestions }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        amVerdict = try? c.decodeIfPresent(String.self, forKey: .amVerdict)
        pmVerdict = try? c.decodeIfPresent(String.self, forKey: .pmVerdict)
        conflicts = (try? c.decode([RoutineConflict].self, forKey: .conflicts)) ?? []
        redundancies = try? c.decodeIfPresent(FlexibleStrings.self, forKey: .redundancies)
        suggestions = try? c.decodeIfPresent(FlexibleStrings.self, forKey: .suggestions)
    }
}

public struct RoutineAnalysisResponse: Codable, Sendable { public var result: RoutineAnalysis }

// MARK: Compare

public struct CompareItem: Codable, Sendable, Hashable, Identifiable {
    public var name: String
    public var verdict: ScanVerdict
    public var score: FlexibleNumber?
    public var short: String?
    public var keyConcerns: FlexibleStrings?
    public var keyWins: FlexibleStrings?
    public var id: String { name }
    public var scoreInt: Int { Int((score?.value ?? 0).rounded()) }
}

public struct CompareWinner: Codable, Sendable, Hashable {
    public var index: Int
    public var reason: String?
}

public struct CompareResult: Codable, Sendable, Hashable {
    public var items: [CompareItem]
    public var winner: CompareWinner?
}

public struct CompareRequest: Encodable, Sendable {
    public struct Item: Encodable, Sendable {
        public var name: String
        public var inci: String
        public init(name: String, inci: String) { self.name = name; self.inci = inci }
    }
    public var products: [Item]
    public init(products: [Item]) { self.products = products }
}

// MARK: Recommend

public struct Recommendation: Codable, Sendable, Hashable, Identifiable {
    public var brand: String?
    public var productName: String
    public var category: String?
    public var priceRange: String?
    public var keyIngredients: FlexibleStrings?
    public var whyItFits: String?
    public var watchOuts: String?
    public var id: String { (brand ?? "") + productName }
}

public struct RecommendResult: Codable, Sendable, Hashable {
    public var recommendations: [Recommendation]
}

public struct RecommendResponse: Codable, Sendable { public var result: RecommendResult }

public struct RecommendRequest: Encodable, Sendable {
    public var goal: String
    public var budget: String
    public var maxPrice: Int?
    public var count: Int?
    public var notes: String?
    public init(goal: String, budget: String, maxPrice: Int? = nil, count: Int? = nil, notes: String? = nil) {
        self.goal = goal; self.budget = budget; self.maxPrice = maxPrice; self.count = count; self.notes = notes
    }
}

// MARK: Apple IAP (new backend routes)

public struct AppleVerifyRequest: Encodable, Sendable {
    public var signedTransaction: String
    public init(signedTransaction: String) { self.signedTransaction = signedTransaction }
}

public struct AppleVerifyResponse: Codable, Sendable {
    public var subscription: Subscription
}
