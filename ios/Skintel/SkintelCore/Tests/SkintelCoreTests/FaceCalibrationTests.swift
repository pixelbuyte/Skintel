import Foundation
import Testing
@testable import SkintelCore

// Face Scan Pro unlocks, bands, trends, oil pattern, redness baseline and barrier (PRO-SPEC §5).

private typealias Zones = [FaceZone: [FaceMetric: Int]]

private func entry(_ day: String, _ stage: FaceScanStage = .daily, ok: Bool = true, cycle: String = "",
                   _ zones: Zones = [:]) -> FaceScanEntry {
    let results = zones.map { FaceZoneResult(zone: $0.key, scores: $0.value) }
    return FaceScanEntry(day: day, stage: stage, result: FaceScanResult(quality: FaceQuality(ok: ok), zones: results),
                         cycleId: cycle)
}

/// A `.report` entry whose summary identifies it.
private func reportEntry(_ day: String, summary: String, ok: Bool = true, cycle: String = "") -> FaceScanEntry {
    let result = FaceScanResult(quality: FaceQuality(ok: ok), summary: summary,
                                report: FaceReport(oilPattern: .combination, redness: .steady, barrier: .steady, marks: .fading))
    return FaceScanEntry(day: day, stage: .report, result: result, cycleId: cycle)
}

/// Shine on forehead + nose and on both cheeks.
private func shine(t: Int, cheeks: Int) -> Zones {
    [.forehead: [.shine: t], .nose: [.shine: t], .leftCheek: [.shine: cheeks], .rightCheek: [.shine: cheeks]]
}

/// The same redness on nose and both cheeks.
private func redness(_ value: Int) -> Zones {
    [.nose: [.redness: value], .leftCheek: [.redness: value], .rightCheek: [.redness: value]]
}

/// `n` consecutive scans from 2026-10-01: day 1 is the baseline sweep, the rest are daily photos.
private func run(_ n: Int, cycle: String = "", _ zones: (Int) -> Zones = { _ in [:] }) -> [FaceScanEntry] {
    (0..<n).map { entry(String(format: "2026-10-%02d", $0 + 1), $0 == 0 ? .baseline : .daily, cycle: cycle, zones($0)) }
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
    let gappy = FaceCalibration(entries: [entry("2026-10-01", .baseline), entry("2026-10-11")])
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

@Test func faceMapNeedsABaselineSweepNotJustAScan() {
    // Seven daily photos open Days 3 and 5 but not the map: it is built from the Day 1 sweep.
    let dailiesOnly = FaceCalibration(entries: (1...7).map { entry(String(format: "2026-10-%02d", $0)) })
    #expect(dailiesOnly.scanCount == 7)
    #expect(!dailiesOnly.hasBaselineScan)
    #expect(!dailiesOnly.isUnlocked(.faceMap))
    #expect(dailiesOnly.progress(for: .faceMap) == 1)               // the ring is full, the map is not open
    #expect(dailiesOnly.unlocked == [.oilPattern, .rednessBaseline])
    #expect(dailiesOnly.nextMilestone == .faceMap)

    #expect(FaceCalibration(entries: [entry("2026-10-01")]).unlocked.isEmpty)
    #expect(FaceCalibration(entries: [entry("2026-10-01", .baseline)]).isUnlocked(.faceMap))
    // A baseline that failed quality is not a baseline.
    #expect(!FaceCalibration(entries: [entry("2026-10-01", .baseline, ok: false), entry("2026-10-02")]).isUnlocked(.faceMap))
    // A final sweep is not a baseline.
    #expect(!FaceCalibration(entries: [entry("2026-10-01", .final)]).isUnlocked(.faceMap))
    #expect(FaceCalibration.Milestone.allCases.filter(\.requiresBaselineScan) == [.faceMap])
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

// MARK: - Which scans count

@Test func oneScanPerDayAndADailyNeverDisplacesASweep() {
    // Two daily photos on one day: the later one counts.
    let dailies = FaceCalibration(entries: [entry("2026-10-02", .daily, [.nose: [.shine: 10]]),
                                            entry("2026-10-02", .daily, [.nose: [.shine: 90]])])
    #expect(dailies.scanCount == 1)
    #expect(dailies.latestScore(zone: .nose, metric: .shine) == 90)

    // A daily photo after the baseline sweep the same day does not replace it, stage or scores.
    let a = entry("2026-10-01", .baseline, [.nose: [.shine: 10]])
    let b = entry("2026-10-01", .daily, [.nose: [.shine: 90]])
    let c = entry("2026-10-02", .daily, [.nose: [.shine: 50]])
    let cal = FaceCalibration(entries: [a, b, c])
    #expect(cal.scanCount == 2)
    #expect(cal.days == ["2026-10-01", "2026-10-02"])
    #expect(cal.scores(zone: .nose, metric: .shine) == [10, 50])
    #expect(cal.hasBaselineScan)
    #expect(cal.isUnlocked(.faceMap))

    // Order does not matter for that: a daily first, the sweep after, the sweep still counts.
    let reversed = FaceCalibration(entries: [b, a])
    #expect(reversed.scans.map(\.stage) == [.baseline])
    #expect(reversed.latestScore(zone: .nose, metric: .shine) == 10)

    // Same for the final sweep: a daily photo after it the same day cannot unlock-erase it.
    var week = run(7)
    week[6] = entry("2026-10-07", .final)
    week.append(entry("2026-10-07", .daily))
    let withLateDaily = FaceCalibration(entries: week)
    #expect(withLateDaily.scanCount == 7)
    #expect(withLateDaily.hasFinalScan)
    #expect(withLateDaily.isUnlocked(.fullReport))

    // Two sweeps on one day: the later one counts.
    let sweeps = FaceCalibration(entries: [entry("2026-10-01", .baseline), entry("2026-10-01", .final)])
    #expect(sweeps.scans.map(\.stage) == [.final])

    // Three entries for one day are still one scan, and a timestamp's day part is the day.
    #expect(FaceCalibration(entries: [entry("2026-10-01"), entry("2026-10-01T08:00:00Z"), entry("2026-10-01")]).scanCount == 1)
}

@Test func qualityIsCheckedBeforeThePerDayPick() {
    // A good scan followed by a failed retake the same day still counts: the failure is dropped
    // first, so it cannot erase the good read.
    let goodThenBad = FaceCalibration(entries: [entry("2026-10-04", .daily, [.chin: [.redness: 33]]), entry("2026-10-04", ok: false)])
    #expect(goodThenBad.scanCount == 1)
    #expect(goodThenBad.latestScore(zone: .chin, metric: .redness) == 33)
    #expect(FaceCalibration(entries: [entry("2026-10-04", ok: false), entry("2026-10-04")]).scanCount == 1)
    #expect(FaceCalibration(entries: [entry("2026-10-04", ok: false), entry("2026-10-04", ok: false)]).scanCount == 0)

    // A failed sweep does not hide a good daily photo from the same day, and is not a sweep.
    let failedSweep = FaceCalibration(entries: [entry("2026-10-01", .baseline, ok: false), entry("2026-10-01")])
    #expect(failedSweep.scanCount == 1)
    #expect(failedSweep.scans.map(\.stage) == [.daily])
    #expect(!failedSweep.hasBaselineScan)

    let cal = FaceCalibration(entries: [entry("2026-10-01"), entry("2026-10-02", ok: false), entry("2026-10-03")])
    #expect(cal.days == ["2026-10-01", "2026-10-03"])

    // A failed final sweep does not unlock the report.
    var week = run(7)
    week[6] = entry("2026-10-07", .final, ok: false)
    #expect(!FaceCalibration(entries: week).isUnlocked(.fullReport))
    // A stored entry that could not be read at all never counts.
    #expect(FaceCalibration(entries: [FaceScanEntry(day: "2026-10-01", stage: .baseline, result: .unreadable)]).scanCount == 0)
}

@Test func reportEntriesAreNotScansAndFeedLatestReport() {
    var week = run(7)
    week[6].stage = .final
    let report = reportEntry("2026-10-07", summary: "Week done.")

    // A final sweep followed by its report the same day: the sweep still counts, the report does not.
    let cal = FaceCalibration(entries: week + [report])
    #expect(cal.scanCount == 7)
    #expect(cal.hasFinalScan)
    #expect(cal.isUnlocked(.fullReport))
    #expect(cal.scans.map(\.stage).filter { $0 == .report }.isEmpty)
    #expect(cal.latestReport?.summary == "Week done.")
    #expect(cal.latestReport?.report?.barrier == .steady)

    // A report on its own is not a scan: nothing counts, nothing unlocks, today is not "scanned".
    let alone = FaceCalibration(entries: [reportEntry("2026-10-07", summary: "x")])
    #expect(alone.scanCount == 0 && alone.unlocked.isEmpty)
    #expect(alone.latestReport != nil)
    #expect(!alone.scannedToday(now: Date(timeIntervalSince1970: 1_791_000_000)))

    // No report entry, no latest report.
    #expect(FaceCalibration(entries: week).latestReport == nil)
}

@Test func latestReportIsTheNewestUsableOne() {
    // Newest by day, whatever the array order.
    let byDay = FaceCalibration(entries: [reportEntry("2026-10-09", summary: "late"), reportEntry("2026-10-07", summary: "early")])
    #expect(byDay.latestReport?.summary == "late")
    // Same day: the later entry wins.
    let sameDay = FaceCalibration(entries: [reportEntry("2026-10-07", summary: "first"), reportEntry("2026-10-07", summary: "second")])
    #expect(sameDay.latestReport?.summary == "second")
    // A report that failed quality is skipped for an older good one.
    let failed = FaceCalibration(entries: [reportEntry("2026-10-07", summary: "good"), reportEntry("2026-10-08", summary: "bad", ok: false)])
    #expect(failed.latestReport?.summary == "good")
    // A malformed day is ignored.
    #expect(FaceCalibration(entries: [reportEntry("garbage", summary: "x")]).latestReport == nil)
}

@Test func onlyTheGivenCyclesEntriesCount() {
    let cycleA = run(3, cycle: "a") { _ in shine(t: 80, cheeks: 10) }
    let cycleB = run(2, cycle: "b") { _ in shine(t: 10, cheeks: 10) } + [reportEntry("2026-10-08", summary: "B report", cycle: "b")]
    let legacy = [entry("2026-10-20", .baseline)]                        // stored before cycles: cycleId ""
    let all = cycleA + cycleB + legacy

    let a = FaceCalibration(entries: all, cycleId: "a")
    #expect(a.cycleId == "a")
    #expect(a.scanCount == 3)
    #expect(a.oilPattern == .combination)
    #expect(a.latestReport == nil)

    let b = FaceCalibration(entries: all, cycleId: "b")
    #expect(b.scanCount == 2)
    #expect(b.oilPattern == nil)
    #expect(b.latestReport?.summary == "B report")

    // The default cycle is the one entries get when stored without an id.
    let none = FaceCalibration(entries: all)
    #expect(none.cycleId == "" && none.days == ["2026-10-20"])
    #expect(FaceCalibration(entries: all, cycleId: "c").scanCount == 0)

    // The same day in two cycles is two scans, one per cycle: cycles never dedupe against each other.
    #expect(FaceCalibration(entries: [entry("2026-10-01", cycle: "a"), entry("2026-10-01", cycle: "b")], cycleId: "a").scanCount == 1)
}

@Test func malformedDaysAreIgnoredAndOrderIsByDay() {
    let cal = FaceCalibration(entries: [
        entry("2026-10-03"), entry("garbage"), entry("2026-02-30"), entry(""), entry("2026-10-01"), entry("2026-9-2"),
    ])
    #expect(cal.days == ["2026-10-01", "2026-10-03"])
    #expect(FaceCalibration(entries: [entry("2026-10-01T23:59:00-07:00")]).days == ["2026-10-01"])
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
    #expect(FaceCalibration.band(0) == .clear)
    #expect(FaceCalibration.band(24) == .clear)
    #expect(FaceCalibration.band(25) == .mild)
    #expect(FaceCalibration.band(59) == .mild)
    #expect(FaceCalibration.band(60) == .noticeable)
    #expect(FaceCalibration.band(100) == .noticeable)
    // Out-of-range input still lands in a band.
    #expect(FaceCalibration.band(-5) == .clear)
    #expect(FaceCalibration.band(140) == .noticeable)
    #expect(FaceCalibration.Band.allCases.map(\.rawValue) == ["clear", "mild", "noticeable"])
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
    #expect(FaceCalibration(entries: run(3) { _ in shine(t: 80, cheeks: 10) }).oilPattern == .combination)
    // Three days, one of them unreadable: only two scans, so still nothing.
    var entries = run(3) { _ in shine(t: 80, cheeks: 10) }
    entries[1].result.quality.ok = false
    #expect(FaceCalibration(entries: entries).oilPattern == nil)
}

@Test func oilPatternSharesTheReportVocabulary() {
    func pattern(t: Int, cheeks: Int) -> FaceReport.OilPattern? {
        FaceCalibration(entries: run(3) { _ in shine(t: t, cheeks: cheeks) }).oilPattern
    }
    // tZone → combination, allOver → oily, low → dry, even → normal ("Balanced").
    #expect(pattern(t: 50, cheeks: 34) == .combination)   // T-zone exactly 50, cheeks just under 35
    #expect(pattern(t: 49, cheeks: 10) == .normal)        // T-zone just under 50
    #expect(pattern(t: 70, cheeks: 35) == .normal)        // cheeks exactly 35 is not "under 35" …
    #expect(pattern(t: 70, cheeks: 49) == .normal)        // … and not "over 50" either
    #expect(pattern(t: 50, cheeks: 50) == .oily)
    #expect(pattern(t: 90, cheeks: 75) == .oily)
    #expect(pattern(t: 24, cheeks: 24) == .dry)
    #expect(pattern(t: 25, cheeks: 24) == .normal)
    #expect(pattern(t: 24, cheeks: 25) == .normal)
    #expect(pattern(t: 40, cheeks: 30) == .normal)
    #expect(pattern(t: 20, cheeks: 60) == .normal)        // cheekier than the T-zone is just balanced
    #expect(pattern(t: 40, cheeks: 30)?.label == "Balanced")
}

@Test func oilPatternAveragesAcrossScansAndZones() {
    // One sweaty morning (T-zone 100) among calm ones does not flip it: mean T-zone is 44.
    let ts = [30, 30, 100, 30, 30]
    let cal = FaceCalibration(entries: run(5) { shine(t: ts[$0], cheeks: 10) })
    #expect(cal.oilPattern == .normal)

    // Forehead and nose are averaged: (90 + 10) / 2 = 50 → T-zone; cheeks (20 + 40) / 2 = 30.
    let zones: Zones = [.forehead: [.shine: 90], .nose: [.shine: 10], .leftCheek: [.shine: 20], .rightCheek: [.shine: 40]]
    #expect(FaceCalibration(entries: run(3) { _ in zones }).oilPattern == .combination)

    // Scans that never carried the cheeks cannot say where shine sits.
    #expect(FaceCalibration(entries: run(3) { _ in [.forehead: [.shine: 80], .nose: [.shine: 80]] }).oilPattern == nil)
    // Partial zones still work: one T-zone zone and one cheek zone per scan is enough.
    #expect(FaceCalibration(entries: run(3) { _ in [.forehead: [.shine: 80], .leftCheek: [.shine: 10]] }).oilPattern == .combination)

    #expect(FaceCalibration.classifyOil(tZoneShine: 50, cheekShine: 34.9) == .combination)
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

// MARK: - Excused days and the barrier

@Test func excusedDaysDropARednessSpikeFromTheBaseline() {
    // Five calm days and a spike on the sixth, say after a logged hot shower.
    let values = [40, 42, 38, 41, 39, 95]
    let entries = run(values.count) { redness(values[$0]) }

    let unexcused = FaceCalibration(entries: entries)
    #expect(unexcused.rednessBaseline == .variable)
    #expect(unexcused.barrierSteady == false)

    let excused = FaceCalibration(entries: entries, excusedDays: ["2026-10-06"])
    #expect(excused.rednessBaseline == .steady)
    #expect(nearly(excused.rednessSpread ?? -1, 1.4142135623730951))
    #expect(excused.barrierSteady == true)
    // The excused scan still counts toward every unlock.
    #expect(excused.scanCount == 6)
    #expect(excused.isUnlocked(.rednessBaseline))
    #expect(excused.excusedDays == ["2026-10-06"])
}

@Test func excusedDaysNeedFiveCalmScansToReadRedness() {
    let entries = run(5) { redness([40, 42, 38, 41, 95][$0]) }
    // Five scans open the Day 5 unlock, but with one excused only four are usable.
    let cal = FaceCalibration(entries: entries, excusedDays: ["2026-10-05"])
    #expect(cal.isUnlocked(.rednessBaseline))
    #expect(cal.rednessSpread == nil)
    #expect(cal.rednessBaseline == nil)
    #expect(cal.barrierSteady == nil)
    // A sixth calm scan brings it back.
    let six = FaceCalibration(entries: entries + [entry("2026-10-06", .daily, redness(40))], excusedDays: ["2026-10-05"])
    #expect(six.rednessBaseline == .steady)
    #expect(six.barrierSteady == true)
}

@Test func excusedDaysAcceptTimestampsAndIgnoreGarbage() {
    let cal = FaceCalibration(entries: [], excusedDays: ["2026-10-06T07:00:00Z", "garbage", "2026-02-30", ""])
    #expect(cal.excusedDays == ["2026-10-06"])
    // They never affect oil pattern or trends.
    let entries = run(3) { _ in shine(t: 80, cheeks: 10) }
    #expect(FaceCalibration(entries: entries, excusedDays: ["2026-10-02"]).oilPattern == .combination)
}

@Test func barrierSteadyReadsCheekRednessOnly() {
    func barrier(_ values: [Int], excused: Set<String> = []) -> Bool? {
        let entries = run(values.count) { [.leftCheek: [.redness: values[$0]], .rightCheek: [.redness: values[$0]]] }
        return FaceCalibration(entries: entries, excusedDays: excused).barrierSteady
    }
    #expect(barrier([40, 41, 39, 40]) == nil)                 // four scans: not yet
    #expect(barrier([40, 41, 39, 40, 42]) == true)
    #expect(barrier([20, 40, 60, 20, 60]) == false)           // std-dev ≈ 17.9
    #expect(barrier([64, 34, 34, 34, 34]) == false)           // exactly 12 is not under 12
    #expect(barrier([63, 34, 34, 34, 34]) == true)            // 11.6
    #expect(barrier([40, 41, 39, 40, 42, 98], excused: ["2026-10-06"]) == true)

    // A restless nose with steady cheeks: the whole-face baseline is variable, the barrier is steady.
    let entries = run(6) { i in
        [.nose: [.redness: i.isMultiple(of: 2) ? 0 : 100], .leftCheek: [.redness: 40], .rightCheek: [.redness: 40]]
    }
    let cal = FaceCalibration(entries: entries)
    #expect(cal.rednessBaseline == .variable)
    #expect(cal.barrierSteady == true)
}
