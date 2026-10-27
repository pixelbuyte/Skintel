import SwiftUI
import SkintelCore

// MARK: - Opening the face scan

/// Opens the face scan through `MainTabView`'s cover, so every entry point (the + sheet, Today,
/// Insights, You, What's New) gets the same free-scan and Skintel+ handling. With scans stored,
/// the flow opens on the map.
struct OpenFaceScanAction {
    let handler: @MainActor () -> Void
    @MainActor func callAsFunction() { handler() }
}

private struct OpenFaceScanKey: EnvironmentKey {
    static let defaultValue = OpenFaceScanAction {}
}

extension EnvironmentValues {
    var openFaceScan: OpenFaceScanAction {
        get { self[OpenFaceScanKey.self] }
        set { self[OpenFaceScanKey.self] = newValue }
    }
}

// MARK: - What the entry points show

/// What Today, Insights and You show about the face scan, read from `FaceScanStore`. The next
/// step follows the flow's own (`FaceScanFlowView`), so a card never promises a scan the flow
/// won't offer. Built inside a view's body, so the view updates when a scan lands.
@MainActor
struct FaceScanSummary {
    /// At least one face scan is stored on this phone. Until then the NEW tags stay up.
    let hasScans: Bool
    /// The newest scan with a map: this week's latest counted scan, else the newest readable one.
    let newest: FaceScanEntry?
    /// Scans counted this week (one per day).
    let scanCount: Int
    let scannedToday: Bool
    let hasBaseline: Bool
    let hasFinalScan: Bool
    let hasReport: Bool
    /// Confirmed free account: the map shows with the 7-day check locked.
    let weekLocked: Bool
    private let entries: [FaceScanEntry]

    init(weekLocked: Bool, now: Date = Date()) {
        let store = FaceScanStore.shared
        let cycle = store.hasCycle
        let calibration = store.calibration
        entries = store.entries
        hasScans = !store.entries.isEmpty
        scanCount = cycle ? calibration.scanCount : 0
        scannedToday = cycle && calibration.scannedToday(now: now)
        hasBaseline = cycle && calibration.hasBaselineScan
        hasFinalScan = cycle && calibration.hasFinalScan
        hasReport = cycle && calibration.latestReport != nil
        let fallback = store.entries.last(where: { entry in
            entry.stage != .report && entry.result.quality.ok && !entry.result.zones.isEmpty
        })
        newest = (cycle ? calibration.scans.last : nil) ?? fallback
        self.weekLocked = weekLocked
    }

    /// Locked the way the flow locks it: only for a confirmed free membership, so a member whose
    /// row is still loading never sees the week locked.
    init(env: AppEnvironment, now: Date = Date()) {
        let sub = env.subscription
        self.init(weekLocked: sub.loaded && sub.lastError == nil && !sub.entitlement.isPro, now: now)
    }

    /// The day of the 7-day check the person is on: today's once it is scanned, else the next.
    var dayOfWeek: Int {
        let day = scannedToday || hasFinalScan ? scanCount : scanCount + 1
        return min(max(day, 1), 7)
    }

    /// "Day 3 of 7", or "Day 1 baseline" for the free map.
    var dayLine: String {
        if weekLocked { return scanCount <= 1 ? "Day 1 baseline" : "Day \(min(scanCount, 7)) of 7" }
        return "Day \(dayOfWeek) of 7"
    }

    /// What opening the face scan leads to today.
    var nextStep: String {
        if weekLocked { return "See your map" }
        if hasReport { return "Your report is ready" }
        if hasFinalScan { return "Write your skin report" }
        if !hasBaseline { return "Start your Day 1 scan" }
        if scannedToday { return "Done for today" }
        return scanCount >= FaceCalibration.Milestone.fullReport.scansNeeded - 1 ? "Final sweep" : "Take today's photo"
    }

    /// Readable scans and reports on this phone, newest first.
    func recent(limit: Int) -> [FaceScanEntry] {
        Array(entries.filter { $0.result.quality.ok }.reversed().prefix(limit))
    }

    static func stageLabel(_ stage: FaceScanStage) -> String {
        switch stage {
        case .baseline: "First sweep"
        case .daily: "Daily photo"
        case .final: "Final sweep"
        case .report: "Skin report"
        }
    }

    /// "Oct 27" for a `YYYY-MM-DD` day key (the key itself if it doesn't parse).
    static func dayLabel(_ key: String) -> String {
        guard let date = ISO8601.date(key) else { return key }
        return DateFormatting.short(date)
    }

    struct ZoneWords: Identifiable {
        let zone: FaceZone
        let words: String
        let isClear: Bool
        var id: FaceZone { zone }
    }

    /// Each zone's top finding in the screen's words: "Clear", or "Flat marks · Some".
    static func zoneWords(_ result: FaceScanResult) -> [ZoneWords] {
        FaceZone.allCases.compactMap { (zone: FaceZone) -> ZoneWords? in
            guard let read = result.zone(zone) else { return nil }
            if read.isClear { return ZoneWords(zone: zone, words: "Clear", isClear: true) }
            guard let top = read.topFinding else { return ZoneWords(zone: zone, words: "Not read", isClear: false) }
            return ZoneWords(zone: zone, words: "\(top.metric.label) · \(FaceCalibration.band(top.score).label)",
                             isClear: false)
        }
    }
}

// MARK: - Thumbnail

/// The newest map, small, for cards (a plain face before the first scan). Taps go to the card
/// around it; the drag-to-turn belongs to the full map.
struct FaceScanThumb: View {
    var result: FaceScanResult? = nil
    var size: CGFloat = 64

    var body: some View {
        FaceMeshView(mode: .thumb, levels: FaceZoneLevels(result: result), zoom: 0.4)
            .frame(width: size, height: size)
            .background(SKColor.blush, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
