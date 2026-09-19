import Foundation

/// The on-device side-by-side read. Everything Compare shows before anyone taps
/// "Get the full ingredient read" is computed here, from data already on the phone:
/// the shelf's outcomes, `Correlate`'s repeat offenders, the curated ingredient table
/// and the saved skin profile. No network, no marginal cost, no spinner.
///
/// Two normalisers exist in this codebase and they are **not** interchangeable:
///
/// - Shelf and repeat-offender lookups key on `INCI.normalize` output — that is what the
///   `inci_normalized` column holds, and what `Correlate.Result.byNormalized` is keyed by.
/// - `IngredientKnowledge.lookup(_:)` / `.isFragrance(_:)` take the **raw** ingredient
///   text and apply their own `normalizeKey` internally.
///
/// Swapping one for the other does not crash — the screen simply finds nothing, silently.
/// `CompareTests.usesInciNormalizeNotKnowledgeKey` pins the difference.
///
/// No `Date()`, `.now`, `Calendar.isDateInToday` or `isDateInYesterday` appears in this
/// file. Nothing here branches on a clock, so nothing here needs one injected.
public enum CompareLocal {

    // MARK: - Shared history

    /// One pass over the shelf, built once per render by the view.
    ///
    /// `ProductStore.culprits` re-runs `Correlate.run` on every access and
    /// `Correlate.Result.byNormalized` rebuilds its dictionary on every access, so both
    /// are read exactly once, here.
    public struct History: Sendable {
        /// Repeat offenders keyed by `INCI.normalize` output.
        public let culpritsByNormalized: [String: Culprit]
        /// normalized -> number of `.good` products containing it.
        public let goodCounts: [String: Int]
        /// normalized -> number of `.bad` products containing it.
        public let badCounts: [String: Int]
        public let goodProductCount: Int
        public let badProductCount: Int

        public init(shelf: [ProductWithIngredients], culprits: Correlate.Result) {
            self.culpritsByNormalized = culprits.byNormalized

            var good: [String: Int] = [:]
            var bad: [String: Int] = [:]
            var goodProducts = 0
            var badProducts = 0

            for p in shelf {
                // A Set, so a product that lists the same ingredient twice still counts once.
                let keys = Set(p.ingredients.map(\.inciNormalized))
                switch p.product.outcome {
                case .good:
                    goodProducts += 1
                    for k in keys { good[k, default: 0] += 1 }
                case .bad:
                    badProducts += 1
                    for k in keys { bad[k, default: 0] += 1 }
                case .unsure:
                    continue
                }
            }

            self.goodCounts = good
            self.badCounts = bad
            self.goodProductCount = goodProducts
            self.badProductCount = badProducts
        }
    }

    // MARK: - Input

    /// One column. `parsed` is built by the caller so a shelf product can supply its
    /// stored `inci_normalized` column rather than re-normalising `inci_raw`.
    public struct Side: Sendable, Hashable {
        public var name: String
        public var parsed: [INCI.ParsedIngredient]

        public init(name: String, parsed: [INCI.ParsedIngredient]) {
            self.name = name
            self.parsed = parsed
        }
    }

    // MARK: - Output

    public enum RowKind: String, Sendable, Hashable {
        case reacted, echo, helper, fragrance, topOfList
    }

    public struct Row: Sendable, Hashable, Identifiable {
        public var kind: RowKind
        /// Raw ingredient text, exactly as it will be shown.
        public var name: String
        /// One plain-English line under the name.
        public var detail: String

        public var id: String { kind.rawValue + "|" + name }

        public init(kind: RowKind, name: String, detail: String) {
            self.kind = kind
            self.name = name
            self.detail = detail
        }
    }

    public struct SideReport: Sendable, Hashable {
        public var name: String
        /// 0...100.
        public var fit: Int
        public var reacted: [Row]
        public var echo: [Row]
        public var helpers: [Row]
        /// `nil` when the list is fragrance-free. At most one row, the first one found.
        public var fragrance: Row?
        public var familiarCount: Int
        public var ingredientCount: Int
        public var headline: String

        public init(name: String, fit: Int, reacted: [Row], echo: [Row], helpers: [Row],
                    fragrance: Row?, familiarCount: Int, ingredientCount: Int, headline: String) {
            self.name = name
            self.fit = fit
            self.reacted = reacted
            self.echo = echo
            self.helpers = helpers
            self.fragrance = fragrance
            self.familiarCount = familiarCount
            self.ingredientCount = ingredientCount
            self.headline = headline
        }
    }

    public struct Diff: Sendable, Hashable {
        public var sharedCount: Int
        public var totalCount: Int
        /// Jaccard overlap, 0...1.
        public var overlap: Double
        public var isNearIdentical: Bool
        public var onlyLeft: [Row]
        public var onlyRight: [Row]
        public var headline: String

        public init(sharedCount: Int, totalCount: Int, overlap: Double, isNearIdentical: Bool,
                    onlyLeft: [Row], onlyRight: [Row], headline: String) {
            self.sharedCount = sharedCount
            self.totalCount = totalCount
            self.overlap = overlap
            self.isNearIdentical = isNearIdentical
            self.onlyLeft = onlyLeft
            self.onlyRight = onlyRight
            self.headline = headline
        }
    }

    public struct Report: Sendable, Hashable {
        /// One or two entries, in input order.
        public var sides: [SideReport]
        /// `nil` for a single side or a genuine tie.
        public var winnerIndex: Int?
        public var isConfident: Bool
        public var headline: String
        public var reason: String
        /// `nil` unless two sides were supplied.
        public var diff: Diff?

        public init(sides: [SideReport], winnerIndex: Int?, isConfident: Bool,
                    headline: String, reason: String, diff: Diff?) {
            self.sides = sides
            self.winnerIndex = winnerIndex
            self.isConfident = isConfident
            self.headline = headline
            self.reason = reason
            self.diff = diff
        }
    }

    // MARK: - Engine

    /// Fixed scoring constants. Named so the arithmetic on screen is traceable to a row.
    private enum Weight {
        static let base = 72
        static let reactedHighRisk = 14
        static let reactedMediumRisk = 8
        static let reactedCap = 45
        static let echoPerRow = 2
        static let echoCap = 8
        static let fragranceSensitive = 12
        static let fragranceNeutral = 5
        static let helperTop = 4
        static let helperRest = 2
        static let helperCap = 16
        static let familiarCap = 8
        static let profilePerRule = 3
        static let profileCap = 6
        /// "High up the list" — the first ten ingredients carry most of the formula.
        static let topOfListCutoff = 10
        /// The tighter cutoff the diff fallback uses when nothing is recognised.
        static let diffFallbackCutoff = 8
    }

    /// At most this many rows per "only in" column.
    private static let diffRowLimit = 4
    /// At most this many substituted `.topOfList` rows per column.
    private static let diffFallbackLimit = 3
    /// Two fits closer than this are not a real difference; walk the tiebreak chain.
    private static let confidenceThreshold = 6

    /// The order "only in X" rows are shown in. Note this is **not** the classification
    /// order: fragrance outranks helpers on screen, because it is the thing she is
    /// choosing against.
    private static let diffKindOrder: [RowKind] = [.reacted, .echo, .fragrance, .helper]

    public static func run(sides: [Side], history: History, profile: SkinProfile) -> Report {
        // Fixed at two columns. Three-way makes every set question ambiguous.
        let used = Array(sides.prefix(2))
        let analyses = used.map { analyse($0, history: history, profile: profile) }
        let reports = analyses.map(\.report)

        guard let first = reports.first else {
            return Report(sides: [], winnerIndex: nil, isConfident: false,
                          headline: "", reason: "", diff: nil)
        }

        guard reports.count == 2 else {
            return Report(sides: reports, winnerIndex: nil, isConfident: false,
                          headline: first.headline,
                          reason: "Scored \(first.fit) out of 100 against your history.",
                          diff: nil)
        }

        let left = reports[0]
        let right = reports[1]
        let diff = makeDiff(left: analyses[0], right: analyses[1])

        var winnerIndex: Int?
        var isConfident = false

        if abs(left.fit - right.fit) >= confidenceThreshold {
            winnerIndex = left.fit > right.fit ? 0 : 1
            isConfident = true
        } else if left.reacted.count != right.reacted.count {
            // 1. Fewer ingredients she has already reacted to.
            winnerIndex = left.reacted.count < right.reacted.count ? 0 : 1
        } else if (left.fragrance == nil) != (right.fragrance == nil) {
            // 2. Fragrance-free beats fragranced.
            winnerIndex = left.fragrance == nil ? 0 : 1
        } else if left.helpers.count != right.helpers.count {
            // 3. More ingredients known to help.
            winnerIndex = left.helpers.count > right.helpers.count ? 0 : 1
        }
        // Nothing separates them: say so, rather than flipping a coin on name order.

        let headline: String
        let reason: String
        if let w = winnerIndex {
            let winner = reports[w]
            let loser = reports[1 - w]
            headline = isConfident
                ? "\(winner.name) is the better match for you."
                : "\(winner.name), by a hair."
            reason = winnerReason(winner: winner, loser: loser)
        } else {
            headline = "Too close to call."
            if let row = diff.onlyLeft.first ?? diff.onlyRight.first {
                reason = "The only real difference is \(row.name)."
            } else {
                reason = "Nothing in your history separates these two."
            }
        }

        return Report(sides: reports, winnerIndex: winnerIndex, isConfident: isConfident,
                      headline: headline, reason: reason, diff: diff)
    }

    // MARK: Classification + fit

    /// One ingredient, and the single kind it was bucketed into (first match wins).
    /// Kept alongside the finished rows so the diff can reuse the classification instead
    /// of redoing it.
    private struct Classified {
        var ingredient: INCI.ParsedIngredient
        var kind: RowKind?
        var row: Row?
    }

    private struct Analysis {
        var classified: [Classified]
        var report: SideReport
    }

    private static func analyse(_ side: Side, history: History, profile: SkinProfile) -> Analysis {
        var classified: [Classified] = []
        var reacted: [Row] = []
        var echo: [Row] = []
        var helpers: [Row] = []
        var fragrance: Row?
        var helperCategories: Set<IngredientKnowledge.Category> = []
        var familiarCount = 0
        var reactedPenalty = 0
        var helperBonus = 0

        for i in side.parsed {
            let isFamiliar = (history.goodCounts[i.normalized] ?? 0) > 0
            if isFamiliar { familiarCount += 1 }
            let high = i.position < Weight.topOfListCutoff

            // 1. Already a repeat offender across her own shelf.
            if let c = history.culpritsByNormalized[i.normalized] {
                let detail = "In \(c.badCount) products that broke you out"
                    + (high ? " · high up the list" : "")
                let row = Row(kind: .reacted, name: i.raw, detail: detail)
                reacted.append(row)
                classified.append(Classified(ingredient: i, kind: .reacted, row: row))
                let weight = c.risk == .high ? Weight.reactedHighRisk : Weight.reactedMediumRisk
                reactedPenalty += high ? weight : max(1, weight / 2)
                continue
            }

            // 2. Not a pattern yet — one bad product, and never in a good one.
            if (history.badCounts[i.normalized] ?? 0) >= 1 && !isFamiliar {
                let row = Row(kind: .echo, name: i.raw, detail: "Also in something that broke you out")
                echo.append(row)
                classified.append(Classified(ingredient: i, kind: .echo, row: row))
                continue
            }

            // 3. On the curated table, in a category that earns its place.
            // `lookup` takes the RAW string — it normalises with its own key internally.
            if let info = IngredientKnowledge.lookup(i.raw),
               IngredientKnowledge.positiveCategories.contains(info.category) {
                let row = Row(kind: .helper, name: i.raw, detail: info.benefit)
                helpers.append(row)
                helperCategories.insert(info.category)
                classified.append(Classified(ingredient: i, kind: .helper, row: row))
                helperBonus += high ? Weight.helperTop : Weight.helperRest
                continue
            }

            // 4. Fragrance, at most one row — the first one that gets this far.
            if fragrance == nil, IngredientKnowledge.isFragrance(i.raw) {
                let row = Row(kind: .fragrance, name: i.raw,
                              detail: "Fragrance — a common trigger for sensitive skin")
                fragrance = row
                classified.append(Classified(ingredient: i, kind: .fragrance, row: row))
                continue
            }

            classified.append(Classified(ingredient: i, kind: nil, row: nil))
        }

        let report: SideReport
        if side.parsed.isEmpty {
            report = SideReport(name: side.name, fit: 0, reacted: [], echo: [], helpers: [],
                                fragrance: nil, familiarCount: 0, ingredientCount: 0,
                                headline: "No ingredients to read.")
        } else {
            let fragrancePenalty: Int
            if fragrance == nil {
                fragrancePenalty = 0
            } else {
                fragrancePenalty = isFragranceSensitive(profile)
                    ? Weight.fragranceSensitive
                    : Weight.fragranceNeutral
            }

            let raw = Weight.base
                - min(Weight.reactedCap, reactedPenalty)
                - min(Weight.echoCap, Weight.echoPerRow * echo.count)
                - fragrancePenalty
                + min(Weight.helperCap, helperBonus)
                + min(Weight.familiarCap, familiarCount)
                + profileBonus(profile: profile, categories: helperCategories)

            report = SideReport(name: side.name,
                                fit: max(0, min(100, raw)),
                                reacted: reacted, echo: echo, helpers: helpers,
                                fragrance: fragrance,
                                familiarCount: familiarCount,
                                ingredientCount: side.parsed.count,
                                headline: sideHeadline(reacted.count))
        }

        return Analysis(classified: classified, report: report)
    }

    /// Sensitive skin and redness-prone skin both pay the higher fragrance price.
    private static func isFragranceSensitive(_ profile: SkinProfile) -> Bool {
        profile.skinType == .sensitive || profile.concerns.contains(.redness)
    }

    /// +3 per satisfied rule, capped at 6. Evaluated in a fixed order so the number is
    /// reproducible; "has category X" means some `.helper` row carried that category.
    private static func profileBonus(profile: SkinProfile,
                                     categories: Set<IngredientKnowledge.Category>) -> Int {
        let concerns = Set(profile.concerns)
        var bonus = 0
        if concerns.contains(.breakouts) || concerns.contains(.oiliness),
           categories.contains(.active) { bonus += Weight.profilePerRule }
        if concerns.contains(.redness),
           categories.contains(.soothing) { bonus += Weight.profilePerRule }
        if concerns.contains(.fineLines) || concerns.contains(.darkSpots),
           categories.contains(.peptide) || categories.contains(.antioxidant) { bonus += Weight.profilePerRule }
        if concerns.contains(.texture),
           categories.contains(.active) { bonus += Weight.profilePerRule }
        if profile.skinType == .dry,
           categories.contains(.hydrator) || categories.contains(.barrier) { bonus += Weight.profilePerRule }
        if profile.skinType == .sensitive,
           categories.contains(.soothing) { bonus += Weight.profilePerRule }
        return min(Weight.profileCap, bonus)
    }

    private static func sideHeadline(_ reactedCount: Int) -> String {
        switch reactedCount {
        case 0: "Nothing here you've reacted to."
        case 1: "1 ingredient you've reacted to before."
        default: "\(reactedCount) ingredients you've reacted to before."
        }
    }

    // MARK: Reason

    /// First true clause wins. Every clause names something that is visible on screen.
    private static func winnerReason(winner: SideReport, loser: SideReport) -> String {
        if winner.reacted.isEmpty && !loser.reacted.isEmpty {
            let verb = loser.reacted.count == 1 ? "is" : "are"
            return "It skips \(names(loser.reacted, max: 2)), which \(verb) in products that broke you out."
        }
        if winner.reacted.count < loser.reacted.count {
            return "It has \(winner.reacted.count) ingredients you've reacted to instead of \(loser.reacted.count)."
        }
        if winner.fragrance == nil && loser.fragrance != nil {
            return "It's fragrance-free; \(loser.name) isn't."
        }
        if winner.helpers.count > loser.helpers.count {
            return "It has \(winner.helpers.count) ingredients known to help, against \(loser.helpers.count)."
        }
        if winner.familiarCount > loser.familiarCount {
            return "\(winner.familiarCount) of its ingredients are already in products that worked for you."
        }
        return "It comes out ahead against your history."
    }

    /// "Linalool", "Linalool and Parfum", "Linalool, Parfum and Limonene".
    private static func names(_ rows: [Row], max limit: Int) -> String {
        let picked = rows.prefix(limit).map(\.name)
        guard picked.count > 1, let last = picked.last else { return picked.first ?? "" }
        return picked.dropLast().joined(separator: ", ") + " and " + last
    }

    // MARK: Diff

    private static func makeDiff(left: Analysis, right: Analysis) -> Diff {
        let leftKeys = Set(left.classified.map(\.ingredient.normalized))
        let rightKeys = Set(right.classified.map(\.ingredient.normalized))

        let sharedCount = leftKeys.intersection(rightKeys).count
        let totalCount = leftKeys.union(rightKeys).count
        let overlap = totalCount == 0 ? 0 : Double(sharedCount) / Double(totalCount)
        let isNearIdentical = overlap >= 0.8 && !leftKeys.isEmpty && !rightKeys.isEmpty

        var onlyLeft = uniqueRows(left, sharedWith: rightKeys)
        var onlyRight = uniqueRows(right, sharedWith: leftKeys)

        // A niche formula the curated table doesn't know would otherwise make this
        // section go silent. Fall back to what is simply near the top of each list.
        if onlyLeft.isEmpty && onlyRight.isEmpty {
            onlyLeft = topOfListRows(left, sharedWith: rightKeys)
            onlyRight = topOfListRows(right, sharedWith: leftKeys)
        }

        let headline = isNearIdentical
            ? "Nearly the same formula. Pick on price."
            : "They share \(sharedCount) of \(totalCount) ingredients."

        return Diff(sharedCount: sharedCount, totalCount: totalCount, overlap: overlap,
                    isNearIdentical: isNearIdentical,
                    onlyLeft: onlyLeft, onlyRight: onlyRight, headline: headline)
    }

    private static func uniqueRows(_ side: Analysis, sharedWith other: Set<String>) -> [Row] {
        side.classified
            .filter { c in
                guard !other.contains(c.ingredient.normalized) else { return false }
                guard let kind = c.kind else { return false }
                return diffKindOrder.contains(kind)
            }
            .sorted { a, b in
                let ra = rank(a.kind)
                let rb = rank(b.kind)
                if ra != rb { return ra < rb }
                return a.ingredient.position < b.ingredient.position
            }
            .prefix(diffRowLimit)
            .compactMap(\.row)
    }

    private static func rank(_ kind: RowKind?) -> Int {
        guard let kind, let i = diffKindOrder.firstIndex(of: kind) else { return diffKindOrder.count }
        return i
    }

    private static func topOfListRows(_ side: Analysis, sharedWith other: Set<String>) -> [Row] {
        side.classified
            .filter { !other.contains($0.ingredient.normalized) && $0.ingredient.position < Weight.diffFallbackCutoff }
            .sorted { $0.ingredient.position < $1.ingredient.position }
            .prefix(diffFallbackLimit)
            .map {
                Row(kind: .topOfList, name: $0.ingredient.raw,
                    detail: "One of the first ingredients — there's a lot of it in here.")
            }
    }
}
