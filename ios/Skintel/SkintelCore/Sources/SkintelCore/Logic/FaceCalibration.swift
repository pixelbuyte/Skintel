import Foundation

/// One stored face scan: the person's calendar day (`YYYY-MM-DD`, the shape
/// `JournalEntry.entryDate` has), which read it was, and what the server returned.
/// Decoding is defaulted field by field so a damaged entry cannot take a store file with it
/// (ios/Skintel/CLAUDE.md rule 3).
public struct FaceScanEntry: Codable, Sendable, Hashable {
    public var day: String
    public var stage: FaceScanStage
    public var result: FaceScanResult

    public init(day: String, stage: FaceScanStage, result: FaceScanResult) {
        self.day = day
        self.stage = stage
        self.result = result
    }

    enum CodingKeys: String, CodingKey { case day, stage, result }

    /// A missing or unknown `stage` reads as `.daily`, which can never unlock the full report by
    /// itself. A missing or unreadable `result` becomes `FaceScanResult.unreadable`, which
    /// `FaceCalibration` ignores. A missing `day` becomes "", which it also ignores.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = (try? c.decodeIfPresent(String.self, forKey: .day)) ?? ""
        stage = (try? c.decodeIfPresent(FaceScanStage.self, forKey: .stage)) ?? .daily
        result = (try? c.decodeIfPresent(FaceScanResult.self, forKey: .result)) ?? .unreadable
    }
}

/// The 7-day check's unlock rules, bands and trends (PRO-SPEC §5). Pure: build it from the stored
/// entries and ask. Unlocks count scans, not calendar days: a missed day makes the ring wait
/// ("2 of 3 scans") and nothing is ever extrapolated.
///
/// Which scans count:
///   1. Only one per calendar day: the latest. Entries are read in the order given (the order
///      they were stored), so for two entries on one day the later one in the array wins.
///   2. A day whose counted scan has `quality.ok == false` is ignored.
///   3. Entries with a malformed `day` are ignored.
/// Counted scans are ordered by day, so "first" and "latest" mean earliest and latest day.
///
/// The only clock-facing member is `scannedToday(now:timeZone:)`; it derives the day key from the
/// injected `now`. Nothing here reads the wall clock (ios/Skintel/CLAUDE.md rule 4).
public struct FaceCalibration: Sendable, Hashable {

    // MARK: Types

    /// The four unlocks. `scansNeeded` is the count of counted scans.
    public enum Milestone: String, Sendable, Hashable, CaseIterable, Identifiable {
        case faceMap
        case oilPattern
        case rednessBaseline
        case fullReport

        public var id: String { rawValue }

        public var scansNeeded: Int {
            switch self {
            case .faceMap: 1
            case .oilPattern: 3
            case .rednessBaseline: 5
            case .fullReport: 7
            }
        }

        /// `fullReport` also needs a `.final` stage scan among the counted ones.
        public var requiresFinalScan: Bool { self == .fullReport }

        public var label: String {
            switch self {
            case .faceMap: "Face map"
            case .oilPattern: "Oil pattern"
            case .rednessBaseline: "Redness baseline"
            case .fullReport: "Full report"
            }
        }
    }

    /// A score in words. The app shows these and trends, never the raw number (PRO-SPEC §6).
    ///
    /// `.none` is a real case here, so in an Optional context (`Band?`) a bare `.none` means
    /// `Optional.none`. Write `Band.none`, and prefer non-optional `Band` in signatures.
    public enum Band: String, Sendable, Hashable, CaseIterable {
        case none, some, noticeable

        public var label: String {
            switch self {
            case .none: "None"
            case .some: "Some"
            case .noticeable: "Noticeable"
            }
        }
    }

    /// Latest scan against the first. Lower is calmer for every metric.
    public enum Trend: String, Sendable, Hashable, CaseIterable {
        case calmer, same, more

        public var label: String {
            switch self {
            case .calmer: "Calmer"
            case .same: "About the same"
            case .more: "More"
            }
        }
    }

    /// Where shine sits, from three or more scans.
    public enum OilPattern: String, Sendable, Hashable, CaseIterable {
        /// Shine on the forehead and nose, cheeks calmer.
        case tZone
        /// Shine everywhere.
        case allOver
        /// Little shine anywhere.
        case low
        /// Anything in between.
        case even

        public var label: String {
            switch self {
            case .tZone: "T-zone shine"
            case .allOver: "Shine all over"
            case .low: "Low shine"
            case .even: "Even"
            }
        }
    }

    /// How much redness moves from scan to scan, from five or more scans.
    public enum RednessBaseline: String, Sendable, Hashable, CaseIterable {
        case steady, variable

        public var label: String {
            switch self {
            case .steady: "Steady"
            case .variable: "Variable"
            }
        }
    }

    // MARK: Thresholds

    /// Band edges: below `someFrom` is none, `someFrom` up to `noticeableFrom` is some.
    public static let someFrom = 25
    public static let noticeableFrom = 60
    /// A latest-minus-first change of at least this many points (either way) is a trend.
    public static let trendDelta = 10
    /// Oil pattern (mean shine, 0-100): `oilHigh` is "shiny"; a T-zone pattern needs cheeks below
    /// `oilTZoneCheekCeiling`; `oilLow` is "little shine". See `classifyOil(tZoneShine:cheekShine:)`.
    public static let oilHigh = 50.0
    public static let oilTZoneCheekCeiling = 35.0
    public static let oilLow = 25.0
    /// Redness: population standard deviation at or above this is `.variable`.
    public static let rednessVariableFrom = 12.0

    // MARK: Counted scans

    /// The scans that count, ordered by day ascending. `day` is the canonical `YYYY-MM-DD`.
    public let scans: [FaceScanEntry]

    public init(entries: [FaceScanEntry]) {
        var latestPerDay: [Int: FaceScanEntry] = [:]
        for entry in entries {
            guard let n = Streaks.dayNumber(entry.day) else { continue }
            var counted = entry
            counted.day = Streaks.key(forDayNumber: n)
            latestPerDay[n] = counted          // a later entry on the same day replaces the earlier one
        }
        scans = latestPerDay.keys.sorted()
            .compactMap { latestPerDay[$0] }
            .filter { $0.result.quality.ok }
    }

    /// Number of counted scans.
    public var scanCount: Int { scans.count }

    /// Day keys of the counted scans, ascending.
    public var days: [String] { scans.map(\.day) }

    /// Whether a counted scan is a `.final` sweep.
    public var hasFinalScan: Bool { scans.contains { $0.stage == .final } }

    /// Whether a counted scan exists for today, with today taken from `now` in `timeZone`.
    /// Today's scan failing quality does not count, so the prompt to scan stays up.
    public func scannedToday(now: Date, timeZone: TimeZone = .autoupdatingCurrent) -> Bool {
        let today = Streaks.dayKey(now, timeZone: timeZone)
        return scans.contains { $0.day == today }
    }

    // MARK: Unlocks

    /// `min(count / needed, 1)`. For `.fullReport` this reaches 1 at seven scans even without a
    /// final sweep; `isUnlocked(_:)` is the authority on whether it is open.
    public func progress(for milestone: Milestone) -> Double {
        min(Double(scanCount) / Double(milestone.scansNeeded), 1)
    }

    public func isUnlocked(_ milestone: Milestone) -> Bool {
        scanCount >= milestone.scansNeeded && (!milestone.requiresFinalScan || hasFinalScan)
    }

    /// Open milestones, in order.
    public var unlocked: [Milestone] { Milestone.allCases.filter(isUnlocked) }

    /// The first milestone still closed, or nil when all four are open.
    public var nextMilestone: Milestone? { Milestone.allCases.first { !isUnlocked($0) } }

    /// Scans still needed for `milestone`; 0 once the count is met (a missing final sweep is not a count).
    public func scansToGo(for milestone: Milestone) -> Int {
        max(milestone.scansNeeded - scanCount, 0)
    }

    // MARK: Bands and trends

    /// Below 25 is none, 25-59 some, 60 and up noticeable. Scores outside 0...100 band by the same edges.
    public static func band(_ score: Int) -> Band {
        if score < someFrom { return .none }
        if score < noticeableFrom { return .some }
        return .noticeable
    }

    /// The counted scans' scores for one zone and metric, oldest first. Scans without it are skipped.
    public func scores(zone: FaceZone, metric: FaceMetric) -> [Int] {
        scans.compactMap { $0.result.score(metric, in: zone) }
    }

    /// The most recent counted score for one zone and metric.
    public func latestScore(zone: FaceZone, metric: FaceMetric) -> Int? {
        scores(zone: zone, metric: metric).last
    }

    /// Latest scan against the first: a change of -10 or lower is calmer, +10 or higher is more,
    /// anything else the same. Nil with fewer than two scans carrying this zone and metric.
    public func trend(zone: FaceZone, metric: FaceMetric) -> Trend? {
        let values = scores(zone: zone, metric: metric)
        guard let first = values.first, let latest = values.last, values.count >= 2 else { return nil }
        let delta = latest - first
        if delta <= -Self.trendDelta { return .calmer }
        if delta >= Self.trendDelta { return .more }
        return .same
    }

    // MARK: Day 3: oil pattern

    /// Nil under three scans (or when too few scans carry the zones needed). Otherwise compares the
    /// mean shine of forehead + nose with the mean of the cheeks, each averaged per scan first so
    /// one sweaty morning does not decide it.
    public var oilPattern: OilPattern? {
        let needed = Milestone.oilPattern.scansNeeded
        guard scanCount >= needed else { return nil }
        let tZone = scans.compactMap { meanScore(in: $0, zones: [.forehead, .nose], metric: .shine) }
        let cheeks = scans.compactMap { meanScore(in: $0, zones: [.leftCheek, .rightCheek], metric: .shine) }
        guard tZone.count >= needed, cheeks.count >= needed else { return nil }
        return Self.classifyOil(tZoneShine: Self.mean(tZone), cheekShine: Self.mean(cheeks))
    }

    /// T-zone at or above 50 with cheeks below 35 is `.tZone`; both at or above 50 is `.allOver`;
    /// both below 25 is `.low`; anything else `.even`.
    public static func classifyOil(tZoneShine: Double, cheekShine: Double) -> OilPattern {
        if tZoneShine >= oilHigh && cheekShine < oilTZoneCheekCeiling { return .tZone }
        if tZoneShine >= oilHigh && cheekShine >= oilHigh { return .allOver }
        if tZoneShine < oilLow && cheekShine < oilLow { return .low }
        return .even
    }

    // MARK: Day 5: redness baseline

    /// Nil under five scans (or when too few scans carry the zones needed). Otherwise the
    /// population standard deviation, across scans, of each scan's mean redness over nose + both cheeks.
    public var rednessBaseline: RednessBaseline? {
        guard let spread = rednessSpread else { return nil }
        return Self.classifyRedness(spread: spread)
    }

    /// The standard deviation behind `rednessBaseline`, under the same five-scan rule.
    public var rednessSpread: Double? {
        let needed = Milestone.rednessBaseline.scansNeeded
        guard scanCount >= needed else { return nil }
        let perScan = scans.compactMap { meanScore(in: $0, zones: [.nose, .leftCheek, .rightCheek], metric: .redness) }
        guard perScan.count >= needed else { return nil }
        return Self.populationStandardDeviation(perScan)
    }

    /// A spread of 12 or more is `.variable`, below that `.steady`.
    public static func classifyRedness(spread: Double) -> RednessBaseline {
        spread >= rednessVariableFrom ? .variable : .steady
    }

    // MARK: Maths

    /// Mean of this scan's scores over the given zones; zones or metrics it lacks are skipped; nil if none.
    private func meanScore(in entry: FaceScanEntry, zones: [FaceZone], metric: FaceMetric) -> Double? {
        let values = zones.compactMap { entry.result.score(metric, in: $0) }
        return values.isEmpty ? nil : Self.mean(values.map(Double.init))
    }

    static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    static func populationStandardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let m = mean(values)
        let variance = values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count)
        return variance.squareRoot()
    }
}
