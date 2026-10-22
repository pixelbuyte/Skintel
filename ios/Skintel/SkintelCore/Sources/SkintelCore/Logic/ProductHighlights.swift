import Foundation

/// What a product is good for, and what to watch, read straight from its ingredient list with
/// the curated `IngredientKnowledge` table. No network and no AI, so it is instant and free:
/// the Add product screen shows this instead of a wall of raw INCI.
public enum ProductHighlights {
    public struct Item: Sendable, Hashable, Identifiable {
        public var id: String { title }
        /// Short label, e.g. "Hydration".
        public let title: String
        /// The ingredients behind it, e.g. "Glycerin, Hyaluronic Acid".
        public let detail: String
        /// An SF Symbol name.
        public let symbol: String

        public init(title: String, detail: String, symbol: String) {
            self.title = title; self.detail = detail; self.symbol = symbol
        }
    }

    public struct Result: Sendable, Hashable {
        public var goodFor: [Item]
        public var watch: [Item]

        public var isEmpty: Bool { goodFor.isEmpty && watch.isEmpty }

        /// One line for a subtitle: "Hydration, barrier support and even tone".
        public var sentence: String? {
            let names = goodFor.prefix(3).map { $0.title.lowercased() }
            guard !names.isEmpty else { return nil }
            let list = names.count == 1 ? names[0]
                : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
            return list.prefix(1).uppercased() + list.dropFirst()
        }
    }

    public static let maxGood = 4
    public static let maxWatch = 3
    private static let maxNames = 3

    // MARK: - Good for

    /// Title and symbol for a benefit group.
    private struct Benefit: Sendable { let title: String; let symbol: String }

    private static let categoryGroups: [IngredientKnowledge.Category: Benefit] = [
        .hydrator: Benefit(title: "Hydration", symbol: "drop"),
        .barrier: Benefit(title: "Barrier support", symbol: "shield"),
        .soothing: Benefit(title: "Calming", symbol: "leaf"),
        .antioxidant: Benefit(title: "Antioxidant care", symbol: "sparkles"),
        .peptide: Benefit(title: "Firming", symbol: "arrow.up.forward"),
        .spf: Benefit(title: "Sun protection", symbol: "sun.max"),
    ]

    /// Actives are told apart by what they do, not just "Active". Keyed by `normalizeKey`.
    private static let activeGroups: [String: Benefit] = {
        let tone = Benefit(title: "Even tone", symbol: "circle.lefthalf.filled")
        let renew = Benefit(title: "Renewal", symbol: "arrow.triangle.2.circlepath")
        let exfoliate = Benefit(title: "Exfoliation", symbol: "circle.dotted")
        let bright = Benefit(title: "Brightening", symbol: "sun.min")
        var m: [String: Benefit] = [:]
        for n in ["Niacinamide", "Azelaic Acid"] { m[IngredientKnowledge.normalizeKey(n)] = tone }
        for n in ["Retinol", "Retinal", "Retinyl Palmitate", "Bakuchiol"] { m[IngredientKnowledge.normalizeKey(n)] = renew }
        for n in ["Salicylic Acid", "Glycolic Acid", "Lactic Acid", "Mandelic Acid"] {
            m[IngredientKnowledge.normalizeKey(n)] = exfoliate
        }
        for n in ["Ascorbic Acid", "Sodium Ascorbyl Phosphate", "Tetrahexyldecyl Ascorbate",
                  "Tranexamic Acid", "Alpha Arbutin"] {
            m[IngredientKnowledge.normalizeKey(n)] = bright
        }
        return m
    }()

    // MARK: - Watch

    private struct WatchRule: Sendable {
        let title: String
        let symbol: String
        let matches: @Sendable (String) -> Bool
    }

    /// Conservative on purpose: only things a person tracking breakouts would want flagged.
    private static let watchRules: [WatchRule] = [
        WatchRule(title: "Fragrance", symbol: "exclamationmark.circle") { IngredientKnowledge.isFragrance($0) },
        WatchRule(title: "Parabens", symbol: "exclamationmark.circle") {
            IngredientKnowledge.normalizeKey($0).contains("paraben")
        },
        WatchRule(title: "Drying alcohol", symbol: "exclamationmark.circle") {
            let k = IngredientKnowledge.normalizeKey($0)
            return k == "alcohol denat" || k == "sd alcohol" || k.hasPrefix("sd alcohol ")
                || k == "denatured alcohol" || k == "alcohol"
        },
        WatchRule(title: "Pore-clogging oils", symbol: "exclamationmark.circle") {
            let k = IngredientKnowledge.normalizeKey($0)
            return ["coconut oil", "cocos nucifera oil", "isopropyl myristate", "isopropyl palmitate",
                    "myristyl myristate", "lanolin", "theobroma cacao seed butter", "cocoa butter",
                    "wheat germ oil", "triticum vulgare germ oil"].contains(k)
        },
        WatchRule(title: "Known sensitizers", symbol: "exclamationmark.circle") {
            let k = IngredientKnowledge.normalizeKey($0)
            return ["methylisothiazolinone", "methylchloroisothiazolinone", "dmdm hydantoin",
                    "quaternium 15", "imidazolidinyl urea", "diazolidinyl urea", "formaldehyde"].contains(k)
        },
    ]

    // MARK: - Build

    public static func make(_ parsed: [INCI.ParsedIngredient]) -> Result {
        // Benefit → ingredient display names, in first-seen order.
        var order: [String] = []
        var groups: [String: (group: Benefit, names: [String])] = [:]

        for ing in parsed {
            guard let info = IngredientKnowledge.lookup(ing.raw) else { continue }
            let group: Benefit?
            if info.category == .active {
                group = activeGroups[IngredientKnowledge.normalizeKey(info.name)]
                    ?? Benefit(title: "Active treatment", symbol: "flask")
            } else {
                group = categoryGroups[info.category]
            }
            guard let group else { continue }
            if groups[group.title] == nil { order.append(group.title); groups[group.title] = (group, []) }
            if let existing = groups[group.title]?.names, !existing.contains(info.name) {
                groups[group.title]?.names.append(info.name)
            }
        }

        // More supporting ingredients first; first-seen breaks ties (earlier = higher in the INCI).
        let ranked = order.enumerated().sorted { a, b in
            let ca = groups[a.element]?.names.count ?? 0
            let cb = groups[b.element]?.names.count ?? 0
            return ca != cb ? ca > cb : a.offset < b.offset
        }.map(\.element)

        let good = ranked.prefix(maxGood).compactMap { title -> Item? in
            guard let entry = groups[title] else { return nil }
            return Item(title: title, detail: entry.names.prefix(maxNames).joined(separator: ", "),
                        symbol: entry.group.symbol)
        }

        var watch: [Item] = []
        for rule in watchRules {
            var names: [String] = []
            for ing in parsed where rule.matches(ing.raw) {
                let shown = IngredientKnowledge.lookup(ing.raw)?.name ?? ing.raw
                if !names.contains(shown) { names.append(shown) }
            }
            if !names.isEmpty {
                watch.append(Item(title: rule.title, detail: names.prefix(maxNames).joined(separator: ", "),
                                  symbol: rule.symbol))
            }
            if watch.count == maxWatch { break }
        }

        return Result(goodFor: Array(good), watch: watch)
    }
}
