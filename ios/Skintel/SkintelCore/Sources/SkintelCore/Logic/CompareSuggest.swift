import Foundation

/// Choosing *which two* products to put side by side is the part a non-technical user
/// can't do for herself, so the app does it: a handful of named pairs drawn from her own
/// shelf and recent scans, each with one plain sentence saying why, plus a short list of
/// what her shelf is missing.
///
/// Pure set arithmetic over a few dozen strings — instant, offline, and recomputed on
/// every render rather than cached (the stores drop their whole file on a decode error;
/// a cached suggestion list is not worth risking a scan history for).
///
/// `Candidate.date` is used **only** as a sort key. No `Date()`, `.now`,
/// `Calendar.isDateInToday` or `isDateInYesterday` appears in this file, and neither
/// entry point takes a clock, because neither branches on one.
public enum CompareSuggest {

    // MARK: - Input

    /// One thing that could go in a slot: a saved shelf product, or a scan she never saved.
    public struct Candidate: Sendable, Hashable, Identifiable {
        /// Product id, or `"scan:<StoredScan.id>"`.
        public var id: String
        /// `nil` for an unsaved scan.
        public var productID: String?
        public var name: String
        /// Free text written by the web app. May be `nil` or off-vocabulary.
        public var category: String?
        /// `nil` for an unsaved scan.
        public var outcome: Outcome?
        /// `INCI.normalize` output — the `inci_normalized` column, or `INCI.parse` output.
        public var normalized: [String]
        /// The raw list, so tapping a suggestion can fill the slot without a lookup.
        public var inci: String
        public var score: Int?
        /// Ordering only. Never a branch.
        public var date: Date?

        public init(id: String, productID: String?, name: String, category: String?,
                    outcome: Outcome?, normalized: [String], inci: String,
                    score: Int?, date: Date?) {
            self.id = id
            self.productID = productID
            self.name = name
            self.category = category
            self.outcome = outcome
            self.normalized = normalized
            self.inci = inci
            self.score = score
            self.date = date
        }
    }

    // MARK: - Pairs

    public enum Reason: String, Sendable, Hashable {
        case sameJobDifferentResult, nearDuplicate, beforeYouBuy, stillUnsure, bothBrokeOut
    }

    public struct Pair: Sendable, Hashable, Identifiable {
        public var left: Candidate
        public var right: Candidate
        public var reason: Reason
        public var line: String

        public var id: String { left.id + "|" + right.id }

        public init(left: Candidate, right: Candidate, reason: Reason, line: String) {
            self.left = left
            self.right = right
            self.reason = reason
            self.line = line
        }
    }

    /// Jaccard overlap at or above this reads as "you may only need one of these".
    private static let nearDuplicateThreshold = 0.6

    /// Up to `limit` pairs, each using a product at most once, in a fixed rule priority.
    ///
    /// Deterministic by construction: every rule's candidates are sorted by a total order
    /// (newest first, then combined score, then id), so the list never jitters between
    /// renders and never depends on the order the caller happened to build the array in.
    public static func pairs(_ candidates: [Candidate], limit: Int = 3) -> [Pair] {
        guard limit > 0 else { return [] }
        // Web-created rows often carry no ingredient list; they can't be compared.
        let usable = candidates.filter { !$0.normalized.isEmpty }
        guard usable.count >= 2 else { return [] }

        var out: [Pair] = []
        var usedCandidates = Set<String>()
        var seenPairs = Set<String>()

        let groups = [
            sameJobDifferentResult(usable),
            nearDuplicate(usable),
            beforeYouBuy(usable),
            stillUnsure(usable),
            bothBrokeOut(usable),
        ]

        for group in groups {
            for pair in group {
                guard out.count < limit else { return out }
                guard !usedCandidates.contains(pair.left.id),
                      !usedCandidates.contains(pair.right.id),
                      !seenPairs.contains(pair.id) else { continue }
                seenPairs.insert(pair.id)
                usedCandidates.insert(pair.left.id)
                usedCandidates.insert(pair.right.id)
                out.append(pair)
            }
        }
        return out
    }

    // MARK: Rules

    /// R1 — same job, opposite results. The `.good` one is always on the left.
    private static func sameJobDifferentResult(_ candidates: [Candidate]) -> [Pair] {
        var out: [Pair] = []
        for (a, b) in combinations(candidates) {
            guard let category = sharedCategory(a, b) else { continue }
            let good: Candidate
            let bad: Candidate
            if a.outcome == .good, b.outcome == .bad {
                good = a; bad = b
            } else if b.outcome == .good, a.outcome == .bad {
                good = b; bad = a
            } else {
                continue
            }
            out.append(Pair(left: good, right: bad, reason: .sameJobDifferentResult,
                            line: "Both are \(category). \(good.name) worked, \(bad.name) broke you out."))
        }
        return ordered(out)
    }

    /// R2 — near-duplicate formulas.
    private static func nearDuplicate(_ candidates: [Candidate]) -> [Pair] {
        var out: [Pair] = []
        for (a, b) in combinations(candidates) {
            let left = Set(a.normalized)
            let right = Set(b.normalized)
            guard !left.isEmpty, !right.isEmpty else { continue }
            let union = left.union(right).count
            guard union > 0 else { continue }
            let overlap = Double(left.intersection(right).count) / Double(union)
            guard overlap >= nearDuplicateThreshold else { continue }
            let percent = Int((overlap * 100).rounded())
            let (first, second) = orient(a, b)
            out.append(Pair(left: first, right: second, reason: .nearDuplicate,
                            line: "These two are \(percent)% the same formula. You may only need one."))
        }
        return ordered(out)
    }

    /// R3 — a scan she never saved, put next to something that works. Scan on the left.
    private static func beforeYouBuy(_ candidates: [Candidate]) -> [Pair] {
        let scans = candidates.filter { $0.productID == nil }
        let worked = candidates.filter { $0.outcome == .good }
        guard !scans.isEmpty, !worked.isEmpty else { return [] }

        var out: [Pair] = []
        for scan in scans {
            let sameJob = worked.filter { sharedCategory(scan, $0) != nil }
            let pool = sameJob.isEmpty ? worked : sameJob
            guard let partner = pool.sorted(by: strongerFirst).first, partner.id != scan.id else { continue }
            let line: String
            if let category = sharedCategory(scan, partner) {
                line = "You scanned \(scan.name) and didn't save it. Put it next to the \(category) that works for you."
            } else {
                line = "You scanned \(scan.name) and didn't save it. Put it next to \(partner.name), which works for you."
            }
            out.append(Pair(left: scan, right: partner, reason: .beforeYouBuy, line: line))
        }
        return ordered(out)
    }

    /// R4 — two she still hasn't made her mind up about.
    private static func stillUnsure(_ candidates: [Candidate]) -> [Pair] {
        var out: [Pair] = []
        for (a, b) in combinations(candidates) {
            guard sharedCategory(a, b) != nil, a.outcome == .unsure, b.outcome == .unsure else { continue }
            let (first, second) = orient(a, b)
            out.append(Pair(left: first, right: second, reason: .stillUnsure,
                            line: "You're unsure about both of these. One of them is probably fine."))
        }
        return ordered(out)
    }

    /// R5 — two that both went wrong. What do they share?
    private static func bothBrokeOut(_ candidates: [Candidate]) -> [Pair] {
        var out: [Pair] = []
        for (a, b) in combinations(candidates) {
            guard sharedCategory(a, b) != nil, a.outcome == .bad, b.outcome == .bad else { continue }
            let (first, second) = orient(a, b)
            out.append(Pair(left: first, right: second, reason: .bothBrokeOut,
                            line: "Both of these broke you out. See what they share."))
        }
        return ordered(out)
    }

    // MARK: Pair plumbing

    private static func combinations(_ candidates: [Candidate]) -> [(Candidate, Candidate)] {
        guard candidates.count >= 2 else { return [] }
        var out: [(Candidate, Candidate)] = []
        for i in 0..<(candidates.count - 1) {
            for j in (i + 1)..<candidates.count {
                out.append((candidates[i], candidates[j]))
            }
        }
        return out
    }

    /// Case-insensitive, whitespace-trimmed. A missing category never matches another
    /// missing category — "unknown" is not a job two products have in common.
    private static func sharedCategory(_ a: Candidate, _ b: Candidate) -> String? {
        guard let x = categoryKey(a), let y = categoryKey(b), x == y else { return nil }
        return x
    }

    private static func categoryKey(_ c: Candidate) -> String? {
        guard let raw = c.category?.trimmingCharacters(in: .whitespaces).lowercased(),
              !raw.isEmpty else { return nil }
        return raw
    }

    /// Fixed orientation for symmetric rules, so `Pair.id` is stable across renders.
    private static func orient(_ a: Candidate, _ b: Candidate) -> (Candidate, Candidate) {
        a.id <= b.id ? (a, b) : (b, a)
    }

    private static func strongerFirst(_ a: Candidate, _ b: Candidate) -> Bool {
        let sa = a.score ?? 0
        let sb = b.score ?? 0
        if sa != sb { return sa > sb }
        return a.id < b.id
    }

    /// Newest first (undated last), then the better-scoring pair, then id. A total order,
    /// so the result does not depend on `sorted`'s stability or on input order.
    private static func ordered(_ pairs: [Pair]) -> [Pair] {
        pairs.sorted { a, b in
            let da = newest(a)
            let db = newest(b)
            if da != db {
                guard let da else { return false }
                guard let db else { return true }
                return da > db
            }
            let sa = (a.left.score ?? 0) + (a.right.score ?? 0)
            let sb = (b.left.score ?? 0) + (b.right.score ?? 0)
            if sa != sb { return sa > sb }
            return a.id < b.id
        }
    }

    private static func newest(_ pair: Pair) -> Date? {
        [pair.left.date, pair.right.date].compactMap { $0 }.max()
    }

    // MARK: - Gaps

    public struct Gap: Sendable, Hashable, Identifiable {
        public enum Kind: String, Sendable {
            case noIngredients, nothingWorks, missingCategory, onlyOneThatWorks
        }

        public var kind: Kind
        public var category: String?
        public var productID: String?
        public var line: String
        public var actionTitle: String

        public var id: String { kind.rawValue + "|" + (category ?? productID ?? "") }

        public init(kind: Kind, category: String?, productID: String?,
                    line: String, actionTitle: String) {
            self.kind = kind
            self.category = category
            self.productID = productID
            self.line = line
            self.actionTitle = actionTitle
        }
    }

    /// What her shelf is missing, in priority order.
    ///
    /// `coreCategories` comes from the app target, which owns `ProductCategory`:
    /// `[ProductCategory.cleanser.rawValue, .moisturizer.rawValue, .sunscreen.rawValue]`.
    /// They are matched case-insensitively and are the only category names ever printed,
    /// so an off-vocabulary `"night cream"` row can never produce a wrong sentence.
    ///
    /// Note `.noIngredients` needs a candidate whose `normalized` is empty — exactly what
    /// `pairs` filters out in its first step. Build the candidate array **once,
    /// unfiltered**, and pass the same array to both functions.
    public static func gaps(_ candidates: [Candidate],
                            coreCategories: [String],
                            limit: Int = 2) -> [Gap] {
        guard limit > 0, !candidates.isEmpty else { return [] }

        let saved = candidates.filter { $0.productID != nil }
        var out: [Gap] = []

        // 1. Something on the shelf that can't join a comparison at all.
        if candidates.count >= 2,
           let missing = saved.filter({ $0.normalized.isEmpty }).sorted(by: newestFirst).first {
            out.append(Gap(kind: .noIngredients, category: nil, productID: missing.productID,
                           line: "\(missing.name) has no ingredient list yet. Add one and it can join comparisons.",
                           actionTitle: "Add it"))
        }

        // 2. A whole job where nothing has worked yet.
        for category in coreCategories {
            let inCategory = onShelf(in: category, from: saved)
            guard inCategory.count >= 2, inCategory.allSatisfy({ $0.outcome == .bad }) else { continue }
            out.append(Gap(kind: .nothingWorks, category: category, productID: nil,
                           line: "Nothing in \(category) has worked yet — \(inCategory.count) of \(inCategory.count) broke you out.",
                           actionTitle: "Find a replacement"))
        }

        // 3. A job with nothing on the shelf at all.
        for category in coreCategories where onShelf(in: category, from: saved).isEmpty {
            out.append(Gap(kind: .missingCategory, category: category, productID: nil,
                           line: "No \(category.lowercased()) on your shelf yet.",
                           actionTitle: "Find one"))
        }

        // 4. One lone thing that works, with no backup.
        for category in coreCategories {
            let inCategory = onShelf(in: category, from: saved)
            let working = inCategory.filter { $0.outcome == .good }
            guard inCategory.count >= 2, working.count == 1, let only = working.first else { continue }
            out.append(Gap(kind: .onlyOneThatWorks, category: category, productID: only.productID,
                           line: "\(only.name) is your only \(category.lowercased()) that works. Worth a backup?",
                           actionTitle: "Find a backup"))
        }

        return Array(out.prefix(limit))
    }

    private static func onShelf(in category: String, from candidates: [Candidate]) -> [Candidate] {
        let key = category.trimmingCharacters(in: .whitespaces).lowercased()
        return candidates.filter { categoryKey($0) == key }
    }

    private static func newestFirst(_ a: Candidate, _ b: Candidate) -> Bool {
        if a.date != b.date {
            guard let da = a.date else { return false }
            guard let db = b.date else { return true }
            return da > db
        }
        return a.id < b.id
    }
}
