import Foundation

/// Everything the Journal screen knows how to say about her own log, computed on this
/// phone from data that is already there. No network, no AI, no randomness: the same
/// inputs always produce the same output, which is what makes it testable and what stops
/// a correlation card reading as a slot machine.
///
/// Every entry point takes `today` as a `yyyy-MM-dd` UTC day key and derives **every**
/// branch from it. `Date()`, `.now`, `Calendar.current`, `Calendar.isDateInToday` and
/// `isDateInYesterday` are banned inside this file — that exact bug has already shipped
/// in this repo once.
///
/// Day keys are produced only by `ISO8601.dayString(_:)` and parsed only by
/// `ISO8601.date(_:)`, both of which are already UTC, so the keys here match byte for
/// byte what `JournalView` writes through `/api/journal`.
public enum JournalInsight {

    // MARK: - Types

    /// What she ticked as actually used on one day. Written by the app's local usage
    /// store; never sent to the server (the journal API has no usage field).
    public struct DayUsage: Sendable, Hashable {
        public var day: String
        public var productIDs: [String]

        public init(day: String, productIDs: [String]) {
            self.day = day
            self.productIDs = productIDs
        }
    }

    /// One square in the five-week calendar.
    public struct Cell: Sendable, Hashable, Identifiable {
        public var day: String
        public var condition: JournalCondition?
        public var isToday: Bool
        public var isFuture: Bool

        public var id: String { day }

        public init(day: String, condition: JournalCondition?, isToday: Bool, isFuture: Bool) {
            self.day = day
            self.condition = condition
            self.isToday = isToday
            self.isFuture = isFuture
        }
    }

    /// Exactly 35 cells, oldest first, Monday-aligned. Counts cover non-future cells only.
    public struct Grid: Sendable, Hashable {
        public var cells: [Cell]
        public var loggedDays: Int
        public var goodDays: Int
        public var roughDays: Int
        public var missedDays: Int

        public init(cells: [Cell], loggedDays: Int, goodDays: Int, roughDays: Int, missedDays: Int) {
            self.cells = cells
            self.loggedDays = loggedDays
            self.goodDays = goodDays
            self.roughDays = roughDays
            self.missedDays = missedDays
        }
    }

    /// The header line's raw material.
    public struct Progress: Sendable, Hashable {
        public var loggedDays: Int
        public var loggedStreak: Int
        public var currentGoodRun: Int
        public var bestGoodRun: Int

        public init(loggedDays: Int, loggedStreak: Int, currentGoodRun: Int, bestGoodRun: Int) {
            self.loggedDays = loggedDays
            self.loggedStreak = loggedStreak
            self.currentGoodRun = currentGoodRun
            self.bestGoodRun = bestGoodRun
        }
    }

    /// The last fortnight against the fortnight before it.
    public struct Trend: Sendable, Hashable {
        public var recentLogged: Int
        public var recentGood: Int
        public var priorLogged: Int
        public var priorGood: Int
        /// Five logged days on each side is the floor below which a fortnight comparison
        /// is noise wearing a sentence.
        public var isReadable: Bool

        public init(recentLogged: Int, recentGood: Int, priorLogged: Int, priorGood: Int, isReadable: Bool) {
            self.recentLogged = recentLogged
            self.recentGood = recentGood
            self.priorLogged = priorLogged
            self.priorGood = priorGood
            self.isReadable = isReadable
        }
    }

    /// One card under "What Skintel noticed". The copy is built here, not in the view, so
    /// the exact counts she can check against the calendar are covered by tests.
    public struct Finding: Sendable, Hashable, Identifiable {
        public enum Kind: String, Sendable, Hashable {
            case product, newProduct, trend, everyDay, gathering
        }

        public enum Mood: String, Sendable, Hashable {
            case good, caution, neutral
        }

        public var kind: Kind
        public var mood: Mood
        public var headline: String
        public var detail: String
        public var productID: String?
        /// Raw INCI name of one ingredient this product shares with something already
        /// marked bad on her shelf. Only ever set on a caution `.product` finding.
        public var sharedIngredientRaw: String?
        /// 0...1, set only for `.gathering`.
        public var progress: Double?

        public var id: String { "\(kind.rawValue)|\(productID ?? headline)" }

        public init(kind: Kind,
                    mood: Mood,
                    headline: String,
                    detail: String,
                    productID: String? = nil,
                    sharedIngredientRaw: String? = nil,
                    progress: Double? = nil) {
            self.kind = kind
            self.mood = mood
            self.headline = headline
            self.detail = detail
            self.productID = productID
            self.sharedIngredientRaw = sharedIngredientRaw
            self.progress = progress
        }
    }

    // MARK: - Tuning

    /// A product contrast needs this many days on each side before it may speak.
    public static let contrastMinimumSide = 4
    /// …and this many days that have both a condition and a usage record.
    public static let contrastMinimumAnalysisDays = 10
    /// The good-rate gap a product contrast must clear.
    public static let contrastMinimumDelta = 0.25
    /// The good-rate gap a newly added product must clear.
    public static let newProductMinimumDelta = 0.30
    /// The good-rate gap a fortnight-over-fortnight trend must clear.
    public static let trendMinimumDelta = 0.15

    // MARK: - Calendar

    /// A computed property, not a `static let`: `Calendar` is not `Sendable`, and a fresh
    /// value per call costs nothing next to a network hop.
    private static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }

    /// Same spelling as `ISO8601.dayOnly`: immutable after construction, used only for
    /// formatting, pinned to UTC so a CI machine in any time zone reads the same label.
    nonisolated(unsafe) private static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private static let usagePrefix = "Used: "

    // MARK: - Conditions

    public static func isGood(_ c: JournalCondition) -> Bool { c == .clear || c == .mild }

    public static func isRough(_ c: JournalCondition) -> Bool { c == .moderate || c == .breakout }

    // MARK: - Day arithmetic

    /// Whole-day offset in UTC. Returns the key unchanged when it does not parse, so a
    /// corrupt row can never crash the screen or spin a walk-back loop forever.
    public static func day(_ key: String, offset: Int) -> String {
        guard let d = ISO8601.date(key) else { return key }
        guard let moved = utc.date(byAdding: .day, value: offset, to: d) else { return key }
        return ISO8601.dayString(moved)
    }

    /// "Tue 16 Sep". UTC + `en_US_POSIX`, so it agrees with the stored key rather than
    /// with the phone's time zone. Returns the raw key if it does not parse.
    public static func dayLabel(_ key: String) -> String {
        guard let d = ISO8601.date(key) else { return key }
        return dayLabelFormatter.string(from: d)
    }

    /// Whole days from `from` to `to`, UTC. 0 when either key is unreadable.
    public static func daysBetween(_ from: String, _ to: String) -> Int {
        guard let a = ISO8601.date(from), let b = ISO8601.date(to) else { return 0 }
        return utc.dateComponents([.day], from: a, to: b).day ?? 0
    }

    // MARK: - The legacy "Used: …" notes line

    /// A usage line is a *whole* line whose trimmed form starts with `"Used: "`. Someone
    /// who writes "Used: my old cleanser" mid-sentence keeps their sentence; someone who
    /// writes it as an entire line loses it, which is the acceptable residual.
    private static func isUsageLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(usagePrefix)
    }

    /// Her own words, with the machine-written usage line removed.
    public static func strippingUsageLine(_ notes: String?) -> String {
        (notes ?? "")
            .components(separatedBy: "\n")
            .filter { !isUsageLine($0) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The product names recorded in the first usage line, for display only.
    ///
    /// This is deliberately **never** fed to the correlation engine: a historical line
    /// lists the entire saved routine rather than what was applied, so it is
    /// over-inclusive on every day and has zero variance for a static routine — exactly
    /// the condition under which a correlation invents a guilty product.
    public static func usageNames(_ notes: String?) -> [String] {
        let lines = (notes ?? "").components(separatedBy: "\n")
        guard let line = lines.first(where: { isUsageLine($0) }) else { return [] }
        let payload = line.trimmingCharacters(in: .whitespacesAndNewlines).dropFirst(usagePrefix.count)
        return payload
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isOverflowMarker($0) }
    }

    /// `"+2 more"` is the tail this file writes, not a product name.
    private static func isOverflowMarker(_ s: String) -> Bool {
        guard s.hasPrefix("+"), s.hasSuffix(" more") else { return false }
        let middle = s.dropFirst().dropLast(5)
        return !middle.isEmpty && middle.allSatisfy(\.isNumber)
    }

    /// Rebuilds the usage line. `nil` for an empty list so the caller can skip the join.
    ///
    /// **The cap is load-bearing:** `api/_journal-analyze.ts` slices each entry's notes to
    /// 200 characters, so an uncapped list truncates the Pro prompt instead of her words.
    public static func usageNote(productNames: [String], limit: Int = 6) -> String? {
        let names = productNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        let cap = max(1, limit)
        var line = usagePrefix + names.prefix(cap).joined(separator: ", ")
        if names.count > cap { line += ", +\(names.count - cap) more" }
        return line
    }

    // MARK: - Calendar grid

    /// Five Monday-aligned weeks ending with the Sunday that closes today's week.
    public static func grid(entries: [JournalEntry], today: String) -> Grid {
        let byDay = conditionsByDay(entries)

        guard let todayDate = ISO8601.date(today) else {
            // Defensive: never crash on a corrupt key. Everything reads as future, so
            // nothing is tappable and no count is invented.
            let cells = (0..<35).map { _ in Cell(day: today, condition: nil, isToday: false, isFuture: true) }
            return Grid(cells: cells, loggedDays: 0, goodDays: 0, roughDays: 0, missedDays: 0)
        }

        // `.weekday` is 1 = Sunday; `m` re-bases it to 0 = Monday.
        let weekday = utc.component(.weekday, from: todayDate)
        let m = (weekday + 5) % 7
        let lastDay = day(today, offset: 6 - m)
        let firstDay = day(lastDay, offset: -34)

        var cells: [Cell] = []
        cells.reserveCapacity(35)
        var logged = 0, good = 0, rough = 0, missed = 0

        for i in 0..<35 {
            let key = day(firstDay, offset: i)
            let condition = byDay[key]
            // Plain string comparison is correct for zero-padded ISO keys.
            let isFuture = key > today
            cells.append(Cell(day: key, condition: condition, isToday: key == today, isFuture: isFuture))

            guard !isFuture else { continue }
            if let condition {
                logged += 1
                if isGood(condition) { good += 1 }
                if isRough(condition) { rough += 1 }
            } else {
                missed += 1
            }
        }

        return Grid(cells: cells, loggedDays: logged, goodDays: good, roughDays: rough, missedDays: missed)
    }

    // MARK: - Progress

    public static func progress(entries: [JournalEntry], today: String) -> Progress {
        let byDay = conditionsByDay(entries)
        let best = longestGoodRun(byDay)

        guard ISO8601.date(today) != nil else {
            return Progress(loggedDays: byDay.count, loggedStreak: 0, currentGoodRun: 0, bestGoodRun: best)
        }

        // Mirrors `JournalStore.streak`'s rule — today, or yesterday when today is still
        // unlogged — but derived from the injected key instead of the wall clock.
        var streak = 0
        var cursor = today
        if byDay[cursor] == nil { cursor = day(today, offset: -1) }
        while byDay[cursor] != nil {
            streak += 1
            cursor = day(cursor, offset: -1)
        }

        var goodRun = 0
        var goodCursor = today
        while let c = byDay[goodCursor], isGood(c) {
            goodRun += 1
            goodCursor = day(goodCursor, offset: -1)
        }

        return Progress(loggedDays: byDay.count, loggedStreak: streak, currentGoodRun: goodRun, bestGoodRun: best)
    }

    /// Longest run of consecutive *calendar* days that are all good. A missing day breaks
    /// the run exactly as a rough day does — otherwise a week she forgot to log reads as
    /// a week her skin was clear.
    private static func longestGoodRun(_ byDay: [String: JournalCondition]) -> Int {
        var best = 0
        var run = 0
        var previous: String?

        for key in byDay.keys.sorted() {
            guard let c = byDay[key] else { continue }
            if !isGood(c) {
                run = 0
                previous = key
                continue
            }
            if let previous, day(previous, offset: 1) == key { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = key
        }
        return best
    }

    // MARK: - Trend

    public static func trend(entries: [JournalEntry], today: String, window: Int = 14) -> Trend {
        let byDay = conditionsByDay(entries)
        let w = max(1, window)
        let recentStart = day(today, offset: -(w - 1))
        let priorEnd = day(today, offset: -w)
        let priorStart = day(today, offset: -(2 * w - 1))

        var recentLogged = 0, recentGood = 0, priorLogged = 0, priorGood = 0
        for (key, condition) in byDay {
            if key >= recentStart, key <= today {
                recentLogged += 1
                if isGood(condition) { recentGood += 1 }
            } else if key >= priorStart, key <= priorEnd {
                priorLogged += 1
                if isGood(condition) { priorGood += 1 }
            }
        }

        return Trend(recentLogged: recentLogged,
                     recentGood: recentGood,
                     priorLogged: priorLogged,
                     priorGood: priorGood,
                     isReadable: recentLogged >= 5 && priorLogged >= 5)
    }

    // MARK: - Payback

    /// The sentence a single tap buys her. First match wins.
    public static func payback(entries: [JournalEntry], today: String) -> String {
        let p = progress(entries: entries, today: today)
        let t = trend(entries: entries, today: today)
        let recentRate = rate(t.recentGood, of: t.recentLogged)
        let priorRate = rate(t.priorGood, of: t.priorLogged)

        if p.currentGoodRun >= 3, p.currentGoodRun >= p.bestGoodRun {
            return "\(p.currentGoodRun) good days in a row — your best run yet."
        }
        if p.currentGoodRun >= 2 {
            return "\(p.currentGoodRun) good days in a row."
        }
        if t.isReadable, recentRate - priorRate >= trendMinimumDelta {
            return "Calmer than the fortnight before — \(t.recentGood) good days, up from \(t.priorGood)."
        }
        if t.isReadable, priorRate - recentRate >= trendMinimumDelta {
            return "A rougher stretch than the fortnight before. Skintel's watching what changed."
        }
        if p.loggedStreak >= 2 {
            return "\(p.loggedStreak) days in a row. Skintel's getting your picture."
        }
        if p.loggedDays < 10 {
            return "\(10 - p.loggedDays) more logged days and Skintel can start matching this to your shelf."
        }
        return "Logged for today."
    }

    // MARK: - Findings

    /// The cards under "What Skintel noticed", at most three, in a fixed order.
    ///
    /// - Parameters:
    ///   - entries: every journal entry in memory.
    ///   - usage: the local record of what she ticked, per day. **Never** the legacy
    ///     `Used: …` notes line — see `usageNames(_:)`.
    ///   - products: her shelf, for names and for the shared-ingredient cross-reference.
    ///   - shelfFlagged: normalised INCI names already flagged across her bad products —
    ///     the app passes `Set(env.products.culprits.byNormalized.keys)`, which is keyed
    ///     by `INCI.normalize`. Never `IngredientKnowledge.normalizeKey`: different
    ///     keyspace, silent mismatch.
    ///   - today: the `yyyy-MM-dd` UTC key. Every window below derives from it.
    public static func findings(entries: [JournalEntry],
                                usage: [DayUsage],
                                products: [ProductWithIngredients],
                                shelfFlagged: Set<String>,
                                today: String) -> [Finding] {
        let byDay = conditionsByDay(entries)

        var usedByDay: [String: Set<String>] = [:]
        for u in usage where !u.productIDs.isEmpty {
            usedByDay[u.day, default: []].formUnion(u.productIDs)
        }

        // A day only counts when it carries *both* a condition and a usage record.
        let analysisDays = byDay.keys.filter { usedByDay[$0] != nil && $0 <= today }.sorted()

        var nameByID: [String: String] = [:]
        for p in products { nameByID[p.product.id] = p.product.productName }

        func goodCount(_ days: [String]) -> Int {
            days.reduce(0) { total, key in
                if let c = byDay[key], isGood(c) { return total + 1 }
                return total
            }
        }
        func roughCount(_ days: [String]) -> Int {
            days.reduce(0) { total, key in
                if let c = byDay[key], isRough(c) { return total + 1 }
                return total
            }
        }
        func goodRate(_ days: [String]) -> Double { rate(goodCount(days), of: days.count) }

        // MARK: A — product contrast

        var cautionProduct: Finding?
        var goodProduct: Finding?
        var everyDayCandidates: [(id: String, name: String, withCount: Int)] = []

        if analysisDays.count >= contrastMinimumAnalysisDays {
            var ids = Set<String>()
            for d in analysisDays { ids.formUnion(usedByDay[d] ?? []) }

            var candidates: [(id: String, name: String, withDays: [String], withoutDays: [String], delta: Double)] = []
            for id in ids {
                // A product that has since been deleted from the shelf has no name, so it
                // is skipped rather than rendered as an empty card.
                guard let name = nameByID[id] else { continue }
                let withDays = analysisDays.filter { usedByDay[$0]?.contains(id) == true }
                let withoutDays = analysisDays.filter { usedByDay[$0]?.contains(id) != true }

                if withDays.count >= contrastMinimumAnalysisDays, withoutDays.count < contrastMinimumSide {
                    everyDayCandidates.append((id: id, name: name, withCount: withDays.count))
                }

                guard withDays.count >= contrastMinimumSide, withoutDays.count >= contrastMinimumSide else { continue }
                let delta = goodRate(withDays) - goodRate(withoutDays)
                guard abs(delta) >= contrastMinimumDelta else { continue }
                candidates.append((id: id, name: name, withDays: withDays, withoutDays: withoutDays, delta: delta))
            }

            // Deterministic even though `ids` is an unordered Set.
            candidates.sort { a, b in
                if abs(a.delta) != abs(b.delta) { return abs(a.delta) > abs(b.delta) }
                let aSide = min(a.withDays.count, a.withoutDays.count)
                let bSide = min(b.withDays.count, b.withoutDays.count)
                if aSide != bSide { return aSide > bSide }
                return a.id < b.id
            }

            for c in candidates {
                if c.delta <= -contrastMinimumDelta, cautionProduct == nil {
                    var detail = "\(c.name) — rough on \(roughCount(c.withDays)) of the \(c.withDays.count) days you ticked it."
                        + " On days without it, \(roughCount(c.withoutDays)) of \(c.withoutDays.count)."
                    let shared = sharedFlaggedIngredient(productID: c.id, products: products, shelfFlagged: shelfFlagged)
                    if let shared {
                        detail += " It shares \(shared) with something else on your shelf that didn't work out."
                    }
                    cautionProduct = Finding(kind: .product,
                                             mood: .caution,
                                             headline: "Rough days tend to show up with this one",
                                             detail: detail,
                                             productID: c.id,
                                             sharedIngredientRaw: shared)
                } else if c.delta >= contrastMinimumDelta, goodProduct == nil {
                    let detail = "\(c.name) — good on \(goodCount(c.withDays)) of the \(c.withDays.count) days you ticked it."
                        + " On days without it, \(goodCount(c.withoutDays)) of \(c.withoutDays.count)."
                    goodProduct = Finding(kind: .product,
                                          mood: .good,
                                          headline: "Your good days keep this one in them",
                                          detail: detail,
                                          productID: c.id)
                }
                if cautionProduct != nil, goodProduct != nil { break }
            }
        }

        // MARK: B — new-product watch (needs no usage data at all: this is cold start)

        var newProduct: Finding?
        do {
            let cutoff = day(today, offset: -30)
            var best: (delta: Double, id: String, finding: Finding)?

            for p in products {
                guard let created = ISO8601.date(p.product.createdAt) else { continue }
                let addedDay = ISO8601.dayString(created)
                guard addedDay > cutoff, addedDay <= today else { continue }

                let beforeStart = day(addedDay, offset: -21)
                let beforeEnd = day(addedDay, offset: -1)
                let after = byDay.keys.filter { $0 >= addedDay && $0 <= today }
                let before = byDay.keys.filter { $0 >= beforeStart && $0 <= beforeEnd }
                guard after.count >= 3, before.count >= 3 else { continue }

                let delta = goodRate(after) - goodRate(before)
                guard abs(delta) >= newProductMinimumDelta else { continue }

                let name = p.product.productName
                let d = daysBetween(addedDay, today)
                let counts = "You added it \(d) days ago. \(goodCount(after)) of the \(after.count) logged days since were good"
                    + " — before that, \(goodCount(before)) of \(before.count)."
                let finding = delta < 0
                    ? Finding(kind: .newProduct,
                              mood: .caution,
                              headline: "Your skin's been rougher since \(name)",
                              detail: counts + " Worth keeping an eye on.",
                              productID: p.product.id)
                    : Finding(kind: .newProduct,
                              mood: .good,
                              headline: "\(name) has been a good fit so far",
                              detail: counts,
                              productID: p.product.id)

                if let current = best {
                    let better = abs(delta) > abs(current.delta)
                        || (abs(delta) == abs(current.delta) && p.product.id < current.id)
                    if better { best = (delta: delta, id: p.product.id, finding: finding) }
                } else {
                    best = (delta: delta, id: p.product.id, finding: finding)
                }
            }
            newProduct = best?.finding
        }

        // MARK: C — trend

        var trendFinding: Finding?
        let t = trend(entries: entries, today: today)
        if t.isReadable {
            let recentRate = rate(t.recentGood, of: t.recentLogged)
            let priorRate = rate(t.priorGood, of: t.priorLogged)
            if abs(recentRate - priorRate) >= trendMinimumDelta {
                let counts = "\(t.recentGood) of your last \(t.recentLogged) logged days were good."
                    + " The fortnight before: \(t.priorGood) of \(t.priorLogged)."
                trendFinding = recentRate > priorRate
                    ? Finding(kind: .trend,
                              mood: .good,
                              headline: "Your skin's been calmer lately",
                              detail: counts)
                    : Finding(kind: .trend,
                              mood: .caution,
                              headline: "A rougher stretch than usual",
                              detail: counts + " Skintel's watching what changed.")
            }
        }

        // MARK: D — every-day invitation (only when A found nothing to separate)

        var everyDay: Finding?
        if cautionProduct == nil, goodProduct == nil {
            let sorted = everyDayCandidates.sorted { a, b in
                if a.withCount != b.withCount { return a.withCount > b.withCount }
                return a.id < b.id
            }
            if let top = sorted.first {
                everyDay = Finding(kind: .everyDay,
                                   mood: .neutral,
                                   headline: "Skintel can't separate this one yet",
                                   detail: "You've ticked \(top.name) on \(top.withCount) of your last \(analysisDays.count) logged days."
                                       + " A couple of days without it and Skintel can compare.",
                                   productID: top.id)
            }
        }

        // MARK: Assembly

        var result: [Finding] = []
        if let cautionProduct { result.append(cautionProduct) }
        if let goodProduct { result.append(goodProduct) }
        if let newProduct { result.append(newProduct) }
        if let trendFinding { result.append(trendFinding) }
        if let everyDay { result.append(everyDay) }

        let trimmed = Array(result.prefix(3))
        guard trimmed.isEmpty else { return trimmed }

        // E — gathering. Never shown alongside another finding.
        let n = analysisDays.count
        return [Finding(kind: .gathering,
                        mood: .neutral,
                        headline: "Skintel's still listening",
                        detail: "Log how your skin feels and tick what you used."
                            + " After 10 days with both, Skintel can start naming which of your products your skin agrees with"
                            + " — worked out right here on your phone. \(n) of 10 so far.",
                        progress: min(1.0, Double(n) / 10.0))]
    }

    // MARK: - Helpers

    /// One condition per day. The API upserts on `(user_id, entry_date)`, so a duplicate
    /// key can only come from a stale in-memory list; last wins, deterministically.
    private static func conditionsByDay(_ entries: [JournalEntry]) -> [String: JournalCondition] {
        var byDay: [String: JournalCondition] = [:]
        for e in entries { byDay[e.entryDate] = e.condition }
        return byDay
    }

    private static func rate(_ part: Int, of total: Int) -> Double {
        total == 0 ? 0 : Double(part) / Double(total)
    }

    /// The first ingredient (lowest `position`) this product shares with something
    /// already flagged across her bad products — skipping fillers and preservatives,
    /// which are in nearly everything and would name water as a suspect.
    private static func sharedFlaggedIngredient(productID: String,
                                                products: [ProductWithIngredients],
                                                shelfFlagged: Set<String>) -> String? {
        guard !shelfFlagged.isEmpty,
              let p = products.first(where: { $0.product.id == productID }) else { return nil }

        let ordered = p.ingredients.sorted { $0.position < $1.position }
        for ing in ordered {
            guard shelfFlagged.contains(ing.inciNormalized) else { continue }
            if let category = IngredientKnowledge.lookup(ing.inciRaw)?.category,
               category == .filler || category == .preservative {
                continue
            }
            return ing.inciRaw
        }
        return nil
    }
}
