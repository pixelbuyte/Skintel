import Foundation
import Testing
@testable import SkintelCore

// Face Scan Pro unlocks, bands, trends, oil pattern and redness baseline (PRO-SPEC §5).

private typealias Zones = [FaceZone: [FaceMetric: Int]]

private func entry(_ day: String, _ stage: FaceScanStage = .daily, ok: Bool = true, _ zones: Zones = [:]) -> FaceScanEntry {
    let results = zones.map { FaceZoneResult(zone: $0.key, scores: $0.value) }
    return FaceScanEntry(day: day, stage: stage, result: FaceScanResult(quality: FaceQuality(ok: ok), zones: results))
}

/// Shine on forehead + nose and on both cheeks.
private func shine(t: Int, cheeks: Int) -> Zones {
    [.forehead: [.shine: t], .nose: [.shine: t], .leftCheek: [.shine: cheeks], .rightCheek: [.shine: cheeks]]
}

/// The same redness on nose and both cheeks.
private func redness(_ value: Int) -> Zones {
    [.nose: [.redness: value], .leftCheek: [.redness: value], .rightCheek: [.redness: value]]
}

/// `n` consecutive daily scans from 2026-10-01, each built by `zones(i)`.
private func run(_ n: Int, stage: FaceScanStage = .daily, _ zones: (Int) -> Zones = { _ in [:] }) -> [FaceScanEntry] {
    (0..<n).map { entry(String(format: "2026-10-%02d", $0 + 1), stage, zones($0)) }
}

private func nearly(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

// MARK: - Unlocks

@Test func unlocksFollowScanCountNotCalendarDays() {
    let none = FaceCalibration(entries: [])
    #expect(none.scanCount == 0)
    #expect(none.unlocked.isEmpty)
    #expect(none.nextMilestone == .faceMap)
    #expect(none.progress(for: .faceMap) == 0)

    // Two scans ten days apart still count as two: a gap never extrapolates a day.
    let gappy = FaceCalibration(entries: [entry("2026-10-01"), entry("2026-10-11")])
    #expect(gappy.scanCount == 2)
    #expect(gappy.isUnlocked(.faceMap))
    #expect(!gappy.isUnlocked(.oilPattern))
    #expect(gappy.scansToGo(for: .oilPattern) == 1)

    #expect(FaceCalibration(entries: run(1)).unlocked == [.faceMap])
    #expect(FaceCalibration(entries: run(3)).unlocked == [.faceMap, .oilPattern])
    #expect(FaceCalibration(entries: run(4)).unlocked == [.faceMap, .oilPattern])
    #expect(FaceCalibration(entries: run(5)).unlocked == [.faceMap, .oilPattern, .rednessBaseline])
    #expect(FaceCalibration(entries: run(5)).nextMilestone == .fullReport)
}

@Test func fullReportNeedsAFinalSweepAsWellAsSevenScans() {
    var week = run(7)
    let withoutFinal = FaceCalibration(entries: week)
    #expect(withoutFinal.scanCount == 7)
    #expect(withoutFinal.progress(for: .fullReport) == 1)        // the ring fills …
    #expect(!withoutFinal.isUnlocked(.fullReport))               // … but the report stays closed
    #expect(withoutFinal.nextMilestone == .fullReport)
    #expect(withoutFinal.scansToGo(for: .fullReport) == 0)

    week[6].stage = .final
    let withFinal = FaceCalibration(entries: week)
    #expect(withFinal.hasFinalScan)
    #expect(withFinal.isUnlocked(.fullReport))
    #expect(withFinal.unlocked == FaceCalibration.Milestone.allCases)
    #expect(withFinal.nextMilestone == nil)

    // A final sweep on day 6 of 7 does not open it early.
    var short = run(6)
    short[5].stage = .final
    #expect(!FaceCalibration(entries: short).isUnlocked(.fullReport))
}

@Test func progressIsCountOverNeededCappedAtOne() {
    let two = FaceCalibration(entries: run(2))
    #expect(nearly(two.progress(for: .oilPattern), 2.0 / 3.0))
    #expect(nearly(two.progress(for: .rednessBaseline), 0.4))
    #expect(nearly(two.progress(for: .fullReport), 2.0 / 7.0))
    #expect(two.progress(for: .faceMap) == 1)
    #expect(FaceCalibration(entries: run(9)).progress(for: .fullReport) == 1)
    #expect(FaceCalibration.Milestone.allCases.map(\.scansNeeded) == [1, 3, 5, 7])
}

@Test func onlyTheLatestScanOfADayCounts() {
    let a = entry("2026-10-01", .baseline, [.nose: [.shine: 10]])
    let b = entry("2026-10-01", .daily, [.nose: [.shine: 90]])
    let c = entry("2026-10-02", .daily, [.nose: [.shine: 50]])
    let cal = FaceCalibration(entries: [a, b, c])
    #expect(cal.scanCount == 2)
    #expect(cal.days == ["2026-10-01", "2026-10-02"])
    // The later entry on the 1st replaced the earlier one, stage included.
    #expect(cal.latestScore(zone: .nose, metric: .shine) == 50)
    #expect(cal.scores(zone: .nose, metric: .shine) == [90, 50])
    #expect(!cal.hasFinalScan)
    // Three entries for one day are still one scan, and a timestamp's day part is the day.
    #expect(FaceCalibration(entries: [entry("2026-10-01"), entry("2026-10-01T08:00:00Z"), entry("2026-10-01")]).scanCount == 1)
}

@Test func daysWithPoorQualityAreIgnored() {
    let cal = FaceCalibration(entries: [
        entry("2026-10-01"),
        entry("2026-10-02", ok: false),
        entry("2026-10-03"),
    ])
    #expect(cal.scanCount == 2)
    #expect(cal.days == ["2026-10-01", "2026-10-03"])

    // The day's counted scan is its latest; if that one failed, the day is ignored.
    #expect(FaceCalibration(entries: [entry("2026-10-04"), entry("2026-10-04", ok: false)]).scanCount == 0)
    // A failed read followed by a good retake counts.
    #expect(FaceCalibration(entries: [entry("2026-10-04", ok: false), entry("2026-10-04")]).scanCount == 1)
    // A failed final sweep does not unlock the report.
    var week = run(7)
    week[6] = entry("2026-10-07", .final, ok: false)
    #expect(!FaceCalibration(entries: week).isUnlocked(.fullReport))
    // A stored entry that could not be read at all never counts.
    #expect(FaceCalibration(entries: [FaceScanEntry(day: "2026-10-01", stage: .daily, result: .unreadable)]).scanCount == 0)
}

@Test func malformedDaysAreIgnoredAndOrderIsByDay() {
    let cal = FaceCalibration(entries: [
        entry("2026-10-03"), entry("garbage"), entry("2026-02-30"), entry(""), entry("2026-10-01"), entry("2026-9-2"),
    ])
    #expect(cal.days == ["2026-10-01", "2026-10-03"])
}

@Test func scannedTodayUsesTheInjectedClockAndTimeZone() throws {
    // 2026-09-25 03:30 UTC is still the 24th in Los Angeles.
    let now = Date(timeIntervalSince1970: 1_790_307_000)
    let utc = try #require(TimeZone(identifier: "UTC"))
    let la = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let cal = FaceCalibration(entries: [entry("2026-09-24")])
    #expect(cal.scannedToday(now: now, timeZone: la))
    #expect(!cal.scannedToday(now: now, timeZone: utc))
    // Today's scan failing quality leaves the prompt up.
    #expect(!FaceCalibration(entries: [entry("2026-09-24", ok: false)]).scannedToday(now: now, timeZone: la))
    #expect(!FaceCalibration(entries: []).scannedToday(now: now, timeZone: la))
}

// MARK: - Bands

@Test func bandsSplitAt25And60() {
    #expect(FaceCalibration.band(0) == FaceCalibration.Band.none)
    #expect(FaceCalibration.band(24) == FaceCalibration.Band.none)
    #expect(FaceCalibration.band(25) == FaceCalibration.Band.some)
    #expect(FaceCalibration.band(59) == FaceCalibration.Band.some)
    #expect(FaceCalibration.band(60) == FaceCalibration.Band.noticeable)
    #expect(FaceCalibration.band(100) == FaceCalibration.Band.noticeable)
    // Out-of-range input still lands in a band.
    #expect(FaceCalibration.band(-5) == FaceCalibration.Band.none)
    #expect(FaceCalibration.band(140) == FaceCalibration.Band.noticeable)
    #expect(FaceCalibration.Band.allCases.map(\.label) == ["None", "Some", "Noticeable"])
}

// MARK: - Trends

private func chin(_ values: [Int], metric: FaceMetric = .redness) -> [FaceScanEntry] {
    values.enumerated().map { entry(String(format: "2026-10-%02d", $0.offset + 1), .daily, [.chin: [metric: $0.element]]) }
}

@Test func trendComparesLatestWithFirstAtTenPoints() {
    func trend(_ values: [Int]) -> FaceCalibration.Trend? {
        FaceCalibration(entries: chin(values)).trend(zone: .chin, metric: .redness)
    }
    #expect(trend([50, 40]) == .calmer)                 // exactly -10
    #expect(trend([50, 41]) == .same)                   // -9
    #expect(trend([50, 60]) == .more)                   // exactly +10
    #expect(trend([50, 59]) == .same)                   // +9
    #expect(trend([50, 50]) == .same)
    #expect(trend([80, 99, 20, 70]) == .calmer)         // only first and latest matter: 80 → 70
    #expect(trend([30, 99, 0, 45]) == .more)            // 30 → 45
    #expect(trend([]) == nil)
    #expect(trend([50]) == nil)
    #expect(FaceCalibration.Trend.allCases.map(\.label) == ["Calmer", "About the same", "More"])
}

@Test func trendSkipsScansWithoutThatZoneAndPoorQualityDays() {
    let entries = [
        entry("2026-10-01", .baseline, [.chin: [.redness: 70]]),
        entry("2026-10-02", .daily, [.nose: [.redness: 10]]),                     // no chin: skipped
        entry("2026-10-03", .daily, [.chin: [.redness: 0]]),
        entry("2026-10-04", .daily, ok: false, [.chin: [.redness: 99]]),            // poor quality: ignored
        entry("2026-10-05", .daily, [.chin: [.redness: 40]]),
    ]
    let cal = FaceCalibration(entries: entries)
    #expect(cal.scores(zone: .chin, metric: .redness) == [70, 0, 40])
    #expect(cal.trend(zone: .chin, metric: .redness) == .calmer)    // 70 → 40
    #expect(cal.trend(zone: .nose, metric: .redness) == nil)        // one score only
    #expect(cal.trend(zone: .chin, metric: .shine) == nil)

    // Order comes from the day, not from where the entry sits in the array.
    let shuffled = FaceCalibration(entries: Array(chin([20, 90]).reversed()))
    #expect(shuffled.trend(zone: .chin, metric: .redness) == .more)
    #expect(shuffled.latestScore(zone: .chin, metric: .redness) == 90)
}

// MARK: - Oil pattern (Day 3)

@Test func oilPatternNeedsThreeScans() {
    #expect(FaceCalibration(entries: run(2) { _ in shine(t: 80, cheeks: 10) }).oilPattern == nil)
    #expect(FaceCalibration(entries: run(3) { _ in shine(t: 80, cheeks: 10) }).oilPattern == .tZone)
    // Three days, one of them unreadable: only two scans, so still nothing.
    var entries = run(3) { _ in shine(t: 80, cheeks: 10) }
    entries[1].result.quality.ok = false
    #expect(FaceCalibration(entries: entries).oilPattern == nil)
}

@Test func oilPatternClassifiesTZoneAllOverLowAndEven() {
    func pattern(t: Int, cheeks: Int) -> FaceCalibration.OilPattern? {
        FaceCalibration(entries: run(3) { _ in shine(t: t, cheeks: cheeks) }).oilPattern
    }
    #expect(pattern(t: 50, cheeks: 34) == .tZone)        // T-zone exactly 50, cheeks just under 35
    #expect(pattern(t: 49, cheeks: 10) == .even)         // T-zone just under 50
    #expect(pattern(t: 70, cheeks: 35) == .even)         // cheeks exactly 35 is not "under 35" …
    #expect(pattern(t: 70, cheeks: 49) == .even)         // … and not "over 50" either
    #expect(pattern(t: 50, cheeks: 50) == .allOver)
    #expect(pattern(t: 90, cheeks: 75) == .allOver)
    #expect(pattern(t: 24, cheeks: 24) == .low)
    #expect(pattern(t: 25, cheeks: 24) == .even)
    #expect(pattern(t: 24, cheeks: 25) == .even)
    #expect(pattern(t: 40, cheeks: 30) == .even)
    #expect(pattern(t: 20, cheeks: 60) == .even)         // cheekier than the T-zone is just "even"
}

@Test func oilPatternAveragesAcrossScansAndZones() {
    // One sweaty morning (T-zone 100) among calm ones does not flip it: mean T-zone is 44.
    let ts = [30, 30, 100, 30, 30]
    let cal = FaceCalibration(entries: run(5) { shine(t: ts[$0], cheeks: 10) })
    #expect(cal.oilPattern == .even)

    // Forehead and nose are averaged: (90 + 10) / 2 = 50 → T-zone; cheeks (20 + 40) / 2 = 30.
    let zones: Zones = [.forehead: [.shine: 90], .nose: [.shine: 10], .leftCheek: [.shine: 20], .rightCheek: [.shine: 40]]
    #expect(FaceCalibration(entries: run(3) { _ in zones }).oilPattern == .tZone)

    // Scans that never carried the cheeks cannot say where shine sits.
    #expect(FaceCalibration(entries: run(3) { _ in [.forehead: [.shine: 80], .nose: [.shine: 80]] }).oilPattern == nil)
    // Partial zones still work: one T-zone zone and one cheek zone per scan is enough.
    #expect(FaceCalibration(entries: run(3) { _ in [.forehead: [.shine: 80], .leftCheek: [.shine: 10]] }).oilPattern == .tZone)

    #expect(FaceCalibration.classifyOil(tZoneShine: 50, cheekShine: 34.9) == .tZone)
    #expect(FaceCalibration.OilPattern.allCases.map(\.rawValue) == ["tZone", "allOver", "low", "even"])
}

// MARK: - Redness baseline (Day 5)

@Test func rednessBaselineNeedsFiveScans() {
    #expect(FaceCalibration(entries: run(4) { _ in redness(40) }).rednessBaseline == nil)
    #expect(FaceCalibration(entries: run(4) { _ in redness(40) }).rednessSpread == nil)
    #expect(FaceCalibration(entries: run(5) { _ in redness(40) }).rednessBaseline == .steady)
    // Four good scans plus one unreadable day is four scans.
    var entries = run(5) { _ in redness(40) }
    entries[2].result.quality.ok = false
    #expect(FaceCalibration(entries: entries).rednessBaseline == nil)
}

@Test func rednessBaselineSplitsOnPopulationStandardDeviationOfTwelve() {
    func baseline(_ values: [Int]) -> FaceCalibration.RednessBaseline? {
        FaceCalibration(entries: run(values.count) { redness(values[$0]) }).rednessBaseline
    }
    #expect(baseline([40, 42, 38, 41, 39]) == .steady)
    #expect(baseline([20, 40, 60, 20, 60]) == .variable)          // std-dev ≈ 17.9
    // Mean 40, deviations 24, -6, -6, -6, -6: variance 720 / 5 = 144, std-dev exactly 12 → variable.
    #expect(baseline([64, 34, 34, 34, 34]) == .variable)
    // One point lower on the outlier: [63, 34, 34, 34, 34] has std-dev 11.6 → steady.
    #expect(baseline([63, 34, 34, 34, 34]) == .steady)

    let exact = FaceCalibration(entries: run(5) { redness([64, 34, 34, 34, 34][$0]) })
    #expect(nearly(exact.rednessSpread ?? -1, 12))
    // Population, not sample: divides by n. (The sample std-dev of these eight numbers is about 2.14.)
    #expect(FaceCalibration.populationStandardDeviation([2, 4, 4, 4, 5, 5, 7, 9]) == 2)
    #expect(FaceCalibration.classifyRedness(spread: 11.99) == .steady)
    #expect(FaceCalibration.classifyRedness(spread: 12) == .variable)
}

@Test func rednessBaselineAveragesNoseAndCheeksPerScan() {
    // Per-scan means: (10 + 20 + 30) / 3 = 20 on every scan → no spread, whatever the zones disagree on.
    let zones: Zones = [.nose: [.redness: 10], .leftCheek: [.redness: 20], .rightCheek: [.redness: 30],
                        .forehead: [.redness: 100], .chin: [.redness: 100]]       // forehead and chin are not part of it
    let steady = FaceCalibration(entries: run(5) { _ in zones })
    #expect(steady.rednessBaseline == .steady)
    #expect(nearly(steady.rednessSpread ?? -1, 0))
    // Scans with no nose or cheeks at all cannot support a baseline.
    #expect(FaceCalibration(entries: run(5) { _ in [.chin: [.redness: 50]] }).rednessBaseline == nil)
}

// MARK: - Entries

@Test func entriesKeepTheirCanonicalDayKey() {
    let cal = FaceCalibration(entries: [entry("2026-10-01T23:59:00-07:00")])
    #expect(cal.days == ["2026-10-01"])
    #expect(cal.scans.first?.stage == .daily)
}
