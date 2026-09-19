import Foundation
import Testing
@testable import SkintelCore

// These run on Linux in `ios-ci` via `swift test`, which makes them the only part of the
// Journal work verifiable without a Mac. Every clock is frozen: `jiToday` is a Saturday,
// `jiAltToday` a Friday in a different year, and the suite asserts the same relative
// outcomes against both. Any `Date()`, `.now` or `Calendar.isDateInToday` that creeps
// into `JournalInsight` makes these fail.

private let jiToday = "2026-09-19"      // Saturday
private let jiAltToday = "2019-04-05"   // Friday

// MARK: - Fixtures

/// One (offset, condition) pair per day. `offset` counts *backwards* from the frozen
/// today, so `0` is today. Spans are built through these two helpers rather than through
/// array literals so every concatenation below has a fully known element type.
private func jiSpan(_ range: Range<Int>, _ condition: JournalCondition) -> [(Int, JournalCondition)] {
    range.map { ($0, condition) }
}

private func jiPoints(_ offsets: [Int], _ condition: JournalCondition) -> [(Int, JournalCondition)] {
    offsets.map { ($0, condition) }
}

private func jiEntries(_ spec: [(Int, JournalCondition)], today: String = jiToday) -> [JournalEntry] {
    spec.map { offset, condition in
        let d = JournalInsight.day(today, offset: -offset)
        return JournalEntry(id: "e\(offset)", userID: "u", entryDate: d, condition: condition,
                            notes: nil, photoURL: nil, createdAt: d + "T12:00:00Z")
    }
}

private func jiUsage(_ spec: [(Int, [String])], today: String = jiToday) -> [JournalInsight.DayUsage] {
    spec.map { offset, ids in
        JournalInsight.DayUsage(day: JournalInsight.day(today, offset: -offset), productIDs: ids)
    }
}

private func jiProduct(_ id: String,
                       name: String,
                       createdAt: String = "2020-01-01T00:00:00Z",
                       ingredients: [(String, String)] = []) -> ProductWithIngredients {
    let p = Product(id: id, userID: "u", brand: nil, productName: name, category: nil,
                    outcome: .unsure, notes: nil, createdAt: createdAt, updatedAt: createdAt)
    let ings = ingredients.enumerated().map { i, pair in
        ProductIngredient(id: "\(id)-\(i)", productID: id, userID: "u",
                          position: i, inciRaw: pair.0, inciNormalized: pair.1)
    }
    return ProductWithIngredients(product: p, ingredients: ings)
}

private typealias JIFixture = (entries: [JournalEntry],
                               usage: [JournalInsight.DayUsage],
                               products: [ProductWithIngredients])

/// `analysisDayCount` consecutive days, each carrying both a condition and a usage
/// record. `p2` is ticked every day, so it is the zero-variance control that section D
/// is supposed to notice and section A is supposed to refuse to judge.
private func jiContrast(p1Offsets: [Int],
                        good: [Int],
                        today: String = jiToday,
                        p1Ingredients: [(String, String)] = [],
                        analysisDayCount: Int = 10) -> JIFixture {
    let days = Array(0..<analysisDayCount)
    let goodSet = Set(good)
    let p1Set = Set(p1Offsets)
    let spec: [(Int, JournalCondition)] = days.map { ($0, goodSet.contains($0) ? .clear : .breakout) }
    let usageSpec: [(Int, [String])] = days.map { ($0, p1Set.contains($0) ? ["p1", "p2"] : ["p2"]) }
    let products = [jiProduct("p1", name: "Cleanser A", ingredients: p1Ingredients),
                    jiProduct("p2", name: "Toner B")]
    return (jiEntries(spec, today: today), jiUsage(usageSpec, today: today), products)
}

private func jiFindings(_ fx: JIFixture,
                        shelfFlagged: Set<String> = [],
                        today: String = jiToday) -> [JournalInsight.Finding] {
    JournalInsight.findings(entries: fx.entries, usage: fx.usage, products: fx.products,
                            shelfFlagged: shelfFlagged, today: today)
}

private func jiHas(_ f: [JournalInsight.Finding], _ kind: JournalInsight.Finding.Kind) -> Bool {
    f.contains(where: { $0.kind == kind })
}

private func jiFirst(_ f: [JournalInsight.Finding], _ kind: JournalInsight.Finding.Kind) -> JournalInsight.Finding? {
    f.first(where: { $0.kind == kind })
}

// MARK: - Day arithmetic

@Test func journalDayOffsetsWalkWholeDays() {
    #expect(JournalInsight.day(jiToday, offset: 0) == "2026-09-19")
    #expect(JournalInsight.day(jiToday, offset: -1) == "2026-09-18")
    #expect(JournalInsight.day(jiToday, offset: 1) == "2026-09-20")
    #expect(JournalInsight.day(jiToday, offset: -7) == "2026-09-12")
}

@Test func journalDayCrossesMonthLeapAndYearBoundaries() {
    #expect(JournalInsight.day("2026-03-01", offset: -1) == "2026-02-28")
    #expect(JournalInsight.day("2028-03-01", offset: -1) == "2028-02-29")
    #expect(JournalInsight.day("2027-01-01", offset: -1) == "2026-12-31")
    #expect(JournalInsight.day("2026-12-31", offset: 1) == "2027-01-01")
}

@Test func journalDayPassesThroughAKeyItCannotParse() {
    #expect(JournalInsight.day("nonsense", offset: -1) == "nonsense")
    #expect(JournalInsight.dayLabel("nonsense") == "nonsense")
}

/// The regression test for the whole UTC story: the formatter pins UTC, so this reads
/// the same on a CI machine in any time zone.
@Test func journalDayLabelIsTimeZoneIndependent() {
    #expect(JournalInsight.dayLabel("2026-01-01") == "Thu 1 Jan")
    #expect(JournalInsight.dayLabel("2026-09-19") == "Sat 19 Sep")
    #expect(JournalInsight.dayLabel(jiAltToday) == "Fri 5 Apr")
}

@Test func journalDaysBetweenCountsWholeDays() {
    #expect(JournalInsight.daysBetween("2026-09-09", "2026-09-19") == 10)
    #expect(JournalInsight.daysBetween("2026-09-19", "2026-09-19") == 0)
    #expect(JournalInsight.daysBetween("nonsense", "2026-09-19") == 0)
}

// MARK: - Notes parsing

@Test func journalStrippingRemovesOnlyWholeUsageLines() {
    #expect(JournalInsight.strippingUsageLine("Felt calm\nUsed: A, B") == "Felt calm")
    #expect(JournalInsight.strippingUsageLine("Used: A, B") == "")
    #expect(JournalInsight.strippingUsageLine(nil) == "")
    #expect(JournalInsight.strippingUsageLine("") == "")
    // Not a whole-line prefix, so her sentence survives untouched.
    #expect(JournalInsight.strippingUsageLine("I used: my old cleanser") == "I used: my old cleanser")
    // Two lines of hers with the machine line in the middle.
    #expect(JournalInsight.strippingUsageLine("Calm\nUsed: A\nStung a bit") == "Calm\nStung a bit")
}

@Test func journalUsageNamesDropTheOverflowMarker() {
    #expect(JournalInsight.usageNames("Felt calm\nUsed: A, B, +2 more") == ["A", "B"])
    #expect(JournalInsight.usageNames("Used: Cleanser A, Toner B") == ["Cleanser A", "Toner B"])
    #expect(JournalInsight.usageNames(nil) == [])
    #expect(JournalInsight.usageNames("Felt calm") == [])
    #expect(JournalInsight.usageNames("Used: ") == [])
}

@Test func journalUsageNoteCapsAtSixNames() {
    #expect(JournalInsight.usageNote(productNames: []) == nil)
    #expect(JournalInsight.usageNote(productNames: ["   ", ""]) == nil)
    #expect(JournalInsight.usageNote(productNames: ["A", "B"]) == "Used: A, B")

    let eight = ["A", "B", "C", "D", "E", "F", "G", "H"]
    let line = JournalInsight.usageNote(productNames: eight, limit: 6)
    #expect(line == "Used: A, B, C, D, E, F, +2 more")
    // The cap is load-bearing: `api/_journal-analyze.ts` slices notes to 200 chars.
    #expect(JournalInsight.usageNames(line) == ["A", "B", "C", "D", "E", "F"])
}

@Test func journalUsageNoteRoundTripsThroughStripAndParse() {
    let note = JournalInsight.usageNote(productNames: ["Cleanser A", "Toner B"])
    let text = "Skin felt calm\n" + (note ?? "")
    #expect(JournalInsight.strippingUsageLine(text) == "Skin felt calm")
    #expect(JournalInsight.usageNames(text) == ["Cleanser A", "Toner B"])
}

// MARK: - Grid

private func jiAssertGridShape(today: String, first: String, last: String, futureCells: Int) {
    let g = JournalInsight.grid(entries: [], today: today)
    #expect(g.cells.count == 35)
    #expect(g.cells.first?.day == first)
    #expect(g.cells.last?.day == last)
    #expect(g.cells.map(\.day) == g.cells.map(\.day).sorted())
    #expect(Set(g.cells.map(\.day)).count == 35)
    #expect(g.cells.filter(\.isToday).count == 1)
    #expect(g.cells.first(where: { $0.isToday })?.day == today)
    #expect(g.cells.filter(\.isFuture).count == futureCells)
    #expect(g.missedDays == 35 - futureCells)
    #expect(g.loggedDays == 0)
}

@Test func journalGridIsMondayAlignedOnASaturday() {
    // 2026-09-19 is a Saturday, so the block ends on Sunday 2026-09-20 and starts on
    // Monday 2026-08-17. Exactly one cell is in the future.
    jiAssertGridShape(today: jiToday, first: "2026-08-17", last: "2026-09-20", futureCells: 1)
}

@Test func journalGridIsMondayAlignedOnAFridayInAnotherYear() {
    jiAssertGridShape(today: jiAltToday, first: "2019-03-04", last: "2019-04-07", futureCells: 2)
}

@Test func journalGridCountsIgnoreFutureAndOutOfRangeDays() {
    var entries = jiEntries([(0, .clear), (1, .mild), (2, .moderate), (3, .breakout)])
    // Tomorrow: inside the block but in the future.
    entries.append(JournalEntry(id: "future", userID: "u", entryDate: "2026-09-20", condition: .clear,
                                notes: nil, photoURL: nil, createdAt: "2026-09-20T00:00:00Z"))
    // One day before the first cell: outside the block entirely.
    entries.append(JournalEntry(id: "old", userID: "u", entryDate: "2026-08-16", condition: .clear,
                                notes: nil, photoURL: nil, createdAt: "2026-08-16T00:00:00Z"))

    let g = JournalInsight.grid(entries: entries, today: jiToday)
    #expect(g.loggedDays == 4)
    #expect(g.goodDays == 2)      // clear + mild
    #expect(g.roughDays == 2)     // moderate + breakout
    #expect(g.loggedDays == g.goodDays + g.roughDays)
    // 35 cells, one of them tomorrow, so 34 are countable.
    #expect(g.missedDays == 34 - g.loggedDays)
    #expect(g.cells.contains(where: { $0.day == "2026-08-16" }) == false)
}

@Test func journalGridSurvivesAnUnparseableToday() {
    let g = JournalInsight.grid(entries: jiEntries([(0, .clear)]), today: "not-a-day")
    #expect(g.cells.count == 35)
    #expect(g.loggedDays == 0)
    #expect(g.goodDays == 0)
    #expect(g.roughDays == 0)
    #expect(g.missedDays == 0)
}

// MARK: - Progress

@Test func journalStreakCountsTodayOrYesterdayAndStopsAtAGap() {
    let endingToday = JournalInsight.progress(entries: jiEntries([(0, .clear), (1, .mild), (2, .breakout)]),
                                              today: jiToday)
    #expect(endingToday.loggedStreak == 3)
    #expect(endingToday.loggedDays == 3)

    // Today is still unlogged, but yesterday's streak is not thrown away.
    let endingYesterday = JournalInsight.progress(entries: jiEntries([(1, .clear), (2, .clear)]), today: jiToday)
    #expect(endingYesterday.loggedStreak == 2)

    // A two-day gap is a broken streak.
    let gap = JournalInsight.progress(entries: jiEntries([(2, .clear), (3, .clear)]), today: jiToday)
    #expect(gap.loggedStreak == 0)

    #expect(JournalInsight.progress(entries: [], today: jiToday).loggedStreak == 0)
}

@Test func journalCurrentGoodRunNeedsTodayToBeGood() {
    #expect(JournalInsight.progress(entries: jiEntries([(0, .clear), (1, .clear)]), today: jiToday).currentGoodRun == 2)
    #expect(JournalInsight.progress(entries: jiEntries([(0, .breakout), (1, .clear)]), today: jiToday).currentGoodRun == 0)
    #expect(JournalInsight.progress(entries: jiEntries([(1, .clear), (2, .clear)]), today: jiToday).currentGoodRun == 0)
    #expect(JournalInsight.progress(entries: jiEntries([(0, .moderate)]), today: jiToday).currentGoodRun == 0)
}

@Test func journalBestGoodRunIsBrokenByAMissingDayNotJustARoughOne() {
    // 09-15, 09-16, 09-18, 09-19 all clear: 09-17 is missing, so the best run is 2.
    let p = JournalInsight.progress(entries: jiEntries(jiPoints([0, 1, 3, 4], .clear)), today: jiToday)
    #expect(p.bestGoodRun == 2)
    #expect(p.loggedDays == 4)

    // A rough day in the middle breaks it the same way.
    let rough = jiSpan(0..<2, .clear) + jiPoints([2], .breakout) + jiSpan(3..<6, .clear)
    #expect(JournalInsight.progress(entries: jiEntries(rough), today: jiToday).bestGoodRun == 3)

    #expect(JournalInsight.progress(entries: jiEntries(jiSpan(0..<5, .mild)), today: jiToday).bestGoodRun == 5)
}

// MARK: - Trend

@Test func journalTrendWindowBoundariesAreExact() {
    // -13 is the last day of "recent", -14 the first of "prior", -28 falls off the end.
    let recentEdge = JournalInsight.trend(entries: jiEntries(jiPoints([13], .clear)), today: jiToday)
    #expect(recentEdge.recentLogged == 1)
    #expect(recentEdge.priorLogged == 0)

    let priorEdge = JournalInsight.trend(entries: jiEntries(jiPoints([14], .clear)), today: jiToday)
    #expect(priorEdge.recentLogged == 0)
    #expect(priorEdge.priorLogged == 1)

    let offTheEnd = JournalInsight.trend(entries: jiEntries(jiPoints([28], .clear)), today: jiToday)
    #expect(offTheEnd.recentLogged == 0)
    #expect(offTheEnd.priorLogged == 0)
}

@Test func journalTrendNeedsFiveLoggedDaysOnEachSide() {
    let fiveAndFour = jiSpan(0..<5, .clear) + jiSpan(14..<18, .clear)
    #expect(JournalInsight.trend(entries: jiEntries(fiveAndFour), today: jiToday).isReadable == false)

    let fiveAndFive = jiSpan(0..<5, .clear) + jiSpan(14..<19, .clear)
    let t = JournalInsight.trend(entries: jiEntries(fiveAndFive), today: jiToday)
    #expect(t.isReadable)
    #expect(t.recentLogged == 5)
    #expect(t.priorLogged == 5)
    #expect(t.recentGood == 5)
    #expect(t.priorGood == 5)
}

// MARK: - Payback (one rung per test, each asserting the exact string)

@Test func journalPaybackBestRunNeedsThreeDaysAndTheRecord() {
    let record = jiEntries(jiSpan(0..<3, .clear))
    #expect(JournalInsight.payback(entries: record, today: jiToday) == "3 good days in a row — your best run yet.")

    // The same three-day run, but an older five-day run still holds the record, so rule
    // one must stand down and rule two must answer instead.
    let notARecord = jiSpan(0..<3, .clear) + jiPoints([3], .breakout) + jiSpan(4..<9, .clear)
    #expect(JournalInsight.payback(entries: jiEntries(notARecord), today: jiToday) == "3 good days in a row.")
}

@Test func journalPaybackTwoDayRun() {
    let entries = jiEntries([(0, .clear), (1, .mild), (2, .breakout)])
    #expect(JournalInsight.payback(entries: entries, today: jiToday) == "2 good days in a row.")
}

/// Eighths keep every rate exactly representable in binary, so the ±0.15 threshold is
/// tested against real arithmetic rather than against floating-point drift.
@Test func journalPaybackCalmerFortnight() {
    // Recent: 7 good of 8 = 0.875. Prior: 5 good of 8 = 0.625. A gap of exactly 0.25.
    let spec = jiPoints([0], .breakout) + jiSpan(1..<8, .clear)
        + jiSpan(14..<19, .clear) + jiSpan(19..<22, .breakout)
    #expect(JournalInsight.payback(entries: jiEntries(spec), today: jiToday)
            == "Calmer than the fortnight before — 7 good days, up from 5.")
}

@Test func journalPaybackRougherFortnight() {
    // Recent: 5 good of 8 = 0.625. Prior: 7 good of 8 = 0.875.
    let spec = jiPoints([0], .breakout) + jiSpan(1..<6, .clear) + jiSpan(6..<8, .breakout)
        + jiSpan(14..<21, .clear) + jiPoints([21], .breakout)
    #expect(JournalInsight.payback(entries: jiEntries(spec), today: jiToday)
            == "A rougher stretch than the fortnight before. Skintel's watching what changed.")
}

@Test func journalPaybackFallsToTheStreakBelowTheTrendThreshold() {
    // Recent 0.875, prior 0.75: a 0.125 gap, under the 0.15 floor, so both trend rungs
    // stay silent and the streak answers instead.
    let spec = jiPoints([0], .breakout) + jiSpan(1..<8, .clear)
        + jiSpan(14..<20, .clear) + jiSpan(20..<22, .breakout)
    #expect(JournalInsight.payback(entries: jiEntries(spec), today: jiToday)
            == "8 days in a row. Skintel's getting your picture.")
}

@Test func journalPaybackShortStreak() {
    let entries = jiEntries([(0, .breakout), (1, .moderate)])
    #expect(JournalInsight.payback(entries: entries, today: jiToday)
            == "2 days in a row. Skintel's getting your picture.")
}

@Test func journalPaybackCountsDownToTen() {
    // Seven scattered rough days: no good run, no streak, no readable fortnight.
    let scattered = jiPoints([0, 2, 4, 6, 8, 10, 12], .breakout)
    #expect(scattered.count == 7)
    #expect(JournalInsight.payback(entries: jiEntries(scattered), today: jiToday)
            == "3 more logged days and Skintel can start matching this to your shelf.")

    #expect(JournalInsight.payback(entries: [], today: jiToday)
            == "10 more logged days and Skintel can start matching this to your shelf.")
}

@Test func journalPaybackFallsAllTheWayThrough() {
    // Ten scattered rough days: past the countdown, and nothing else qualifies.
    let scattered = jiPoints([0, 2, 4, 6, 8, 10, 12, 14, 16, 18], .breakout)
    #expect(scattered.count == 10)
    #expect(JournalInsight.payback(entries: jiEntries(scattered), today: jiToday) == "Logged for today.")
}

// MARK: - Findings: gathering

@Test func journalFindingsOnAnEmptyLogAreOneGatheringCard() {
    let f = JournalInsight.findings(entries: [], usage: [], products: [], shelfFlagged: [], today: jiToday)
    #expect(f.count == 1)
    #expect(f[0].kind == .gathering)
    #expect(f[0].mood == .neutral)
    #expect(f[0].progress == 0.0)
    #expect(f[0].headline == "Skintel's still listening")
    #expect(f[0].detail.hasSuffix("0 of 10 so far."))
}

@Test func journalGatheringProgressCountsOnlyDaysWithBothHalves() {
    // Twelve logged days, but only four of them also carry a usage record.
    let entries = jiEntries(jiSpan(0..<12, .clear))
    let usage = jiUsage((0..<4).map { ($0, ["p1"]) })
    let f = JournalInsight.findings(entries: entries, usage: usage,
                                    products: [jiProduct("p1", name: "Cleanser A")],
                                    shelfFlagged: [], today: jiToday)
    #expect(f.count == 1)
    #expect(f[0].kind == .gathering)
    #expect(f[0].progress == 0.4)
    #expect(f[0].detail.hasSuffix("4 of 10 so far."))
}

@Test func journalUsageRecordsWithNoProductsAreIgnored() {
    // An empty tick list is not an analysis day.
    let entries = jiEntries(jiSpan(0..<12, .clear))
    let usage = jiUsage((0..<12).map { ($0, [] as [String]) })
    let f = JournalInsight.findings(entries: entries, usage: usage,
                                    products: [jiProduct("p1", name: "Cleanser A")],
                                    shelfFlagged: [], today: jiToday)
    #expect(f.count == 1)
    #expect(f[0].kind == .gathering)
    #expect(f[0].progress == 0.0)
}

// MARK: - Findings: product contrast

@Test func journalProductContrastFiresAtTheGateAndNotBelowIt() {
    // Ten analysis days. p1 is ticked on four of them, all good; the other six are
    // 3 good of 6. Delta 0.5, four days on the thin side: exactly the gate.
    let fires = jiFindings(jiContrast(p1Offsets: [0, 1, 2, 3], good: [0, 1, 2, 3, 4, 5, 6]))
    #expect(jiHas(fires, .product))
    #expect(jiFirst(fires, .product)?.mood == .good)
    #expect(jiFirst(fires, .product)?.productID == "p1")

    // Three ticked days is one short of the gate, so nothing is said about p1.
    let tooFewWith = jiFindings(jiContrast(p1Offsets: [0, 1, 2], good: [0, 1, 2, 3, 4, 5, 6]))
    #expect(jiHas(tooFewWith, .product) == false)

    // Seven ticked days leaves only three without — the other side of the same gate.
    let tooFewWithout = jiFindings(jiContrast(p1Offsets: [0, 1, 2, 3, 4, 5, 6], good: [0, 1, 2, 3]))
    #expect(jiHas(tooFewWithout, .product) == false)
}

@Test func journalProductContrastNeedsTenAnalysisDays() {
    // Nine days with an overwhelming split still says nothing: the floor is ten.
    let nine = jiFindings(jiContrast(p1Offsets: [0, 1, 2, 3], good: [0, 1, 2, 3], analysisDayCount: 9))
    #expect(jiHas(nine, .product) == false)
    #expect(nine.count == 1)
    #expect(nine[0].kind == .gathering)
    #expect(nine[0].detail.hasSuffix("9 of 10 so far."))
}

@Test func journalProductContrastStaysSilentJustUnderTheDeltaThreshold() {
    // Fifty analysis days. p1 covers the newest 25 (24 good = 0.96); the oldest 25 carry
    // p2 alone (18 good = 0.72). A gap of 0.24 — under the 0.25 floor, so neither speaks.
    let days = Array(0..<50)
    let goodSet = Set(Array(0..<24) + Array(25..<43))
    let spec: [(Int, JournalCondition)] = days.map { ($0, goodSet.contains($0) ? .clear : .breakout) }
    let usageSpec: [(Int, [String])] = days.map { ($0, $0 < 25 ? ["p1", "p2"] : ["p2"]) }
    let products = [jiProduct("p1", name: "Cleanser A"), jiProduct("p2", name: "Toner B")]

    let f = JournalInsight.findings(entries: jiEntries(spec), usage: jiUsage(usageSpec),
                                    products: products, shelfFlagged: [], today: jiToday)
    #expect(jiHas(f, .product) == false)
}

@Test func journalProductContrastMoodAndCountsAreHers() {
    let good = jiFirst(jiFindings(jiContrast(p1Offsets: [0, 1, 2, 3], good: [0, 1, 2, 3, 4, 5, 6])), .product)
    #expect(good?.mood == .good)
    #expect(good?.headline == "Your good days keep this one in them")
    #expect(good?.detail == "Cleanser A — good on 4 of the 4 days you ticked it. On days without it, 3 of 6.")

    let caution = jiFirst(jiFindings(jiContrast(p1Offsets: [0, 1, 2, 3], good: [4, 5, 6, 7, 8, 9])), .product)
    #expect(caution?.mood == .caution)
    #expect(caution?.headline == "Rough days tend to show up with this one")
    #expect(caution?.detail == "Cleanser A — rough on 4 of the 4 days you ticked it. On days without it, 0 of 6.")
    // No cross-reference was asked for, so none is invented.
    #expect(caution?.sharedIngredientRaw == nil)
}

@Test func journalZeroVarianceYieldsAnInvitationNotAnAccusation() {
    // One product on all fourteen analysis days. There is no "without" side, so the
    // engine must refuse to judge it and ask for a gap instead.
    let days = Array(0..<14)
    let spec: [(Int, JournalCondition)] = days.map { ($0, $0 < 7 ? .clear : .breakout) }
    let usageSpec: [(Int, [String])] = days.map { ($0, ["p1"]) }
    let f = JournalInsight.findings(entries: jiEntries(spec), usage: jiUsage(usageSpec),
                                    products: [jiProduct("p1", name: "Cleanser A")],
                                    shelfFlagged: [], today: jiToday)

    #expect(jiHas(f, .product) == false)
    let invite = jiFirst(f, .everyDay)
    #expect(invite?.mood == .neutral)
    #expect(invite?.productID == "p1")
    #expect(invite?.headline == "Skintel can't separate this one yet")
    #expect(invite?.detail == "You've ticked Cleanser A on 14 of your last 14 logged days. A couple of days without it and Skintel can compare.")
}

@Test func journalEveryDayCardIsSuppressedWhenAProductCardExists() {
    // p2 is ticked on all ten days and would qualify for the invitation, but p1 produced
    // a real contrast, so the screen leads with that instead.
    let f = jiFindings(jiContrast(p1Offsets: [0, 1, 2, 3], good: [0, 1, 2, 3, 4, 5, 6]))
    #expect(jiHas(f, .product))
    #expect(jiHas(f, .everyDay) == false)
}

@Test func journalUnknownProductIDsAreSkippedNotRendered() {
    let days = Array(0..<10)
    let spec: [(Int, JournalCondition)] = days.map { ($0, $0 < 4 ? .clear : .breakout) }
    let usageSpec: [(Int, [String])] = days.map { ($0, $0 < 4 ? ["ghost"] : ["ghost", "phantom"]) }

    // The shelf knows neither id, so there is nothing to name and nothing to claim.
    let f = JournalInsight.findings(entries: jiEntries(spec), usage: jiUsage(usageSpec),
                                    products: [], shelfFlagged: [], today: jiToday)
    #expect(f.count == 1)
    #expect(f[0].kind == .gathering)
    #expect(f.contains(where: { $0.detail.contains("ghost") }) == false)
}

// MARK: - Findings: new-product watch (the cold-start guarantee)

@Test func journalNewProductWatchNeedsNoUsageDataAtAll() {
    // Added ten days ago. Four logged days since, all rough; three before it, all clear.
    let spec = jiSpan(0..<4, .breakout) + jiSpan(11..<14, .clear)
    let serum = jiProduct("p3", name: "New Serum",
                          createdAt: JournalInsight.day(jiToday, offset: -10) + "T09:00:00Z")

    let f = JournalInsight.findings(entries: jiEntries(spec), usage: [], products: [serum],
                                    shelfFlagged: [], today: jiToday)
    #expect(f.count == 1)
    #expect(f[0].kind == .newProduct)
    #expect(f[0].mood == .caution)
    #expect(f[0].productID == "p3")
    #expect(f[0].headline == "Your skin's been rougher since New Serum")
    #expect(f[0].detail == "You added it 10 days ago. 0 of the 4 logged days since were good — before that, 3 of 3. Worth keeping an eye on.")
}

@Test func journalNewProductWatchCanAlsoBeGoodNews() {
    let spec = jiSpan(0..<3, .clear) + jiPoints([3], .mild) + jiSpan(11..<14, .breakout)
    let serum = jiProduct("p3", name: "New Serum",
                          createdAt: JournalInsight.day(jiToday, offset: -10) + "T09:00:00Z")
    let f = JournalInsight.findings(entries: jiEntries(spec), usage: [], products: [serum],
                                    shelfFlagged: [], today: jiToday)
    #expect(f.count == 1)
    #expect(f[0].kind == .newProduct)
    #expect(f[0].mood == .good)
    #expect(f[0].headline == "New Serum has been a good fit so far")
    #expect(f[0].detail == "You added it 10 days ago. 4 of the 4 logged days since were good — before that, 0 of 3.")
}

@Test func journalNewProductWatchStaysSilentOutsideItsGates() {
    let full = jiEntries(jiSpan(0..<4, .breakout) + jiSpan(11..<14, .clear))
    let addedDay = JournalInsight.day(jiToday, offset: -10)

    // Older than thirty days: no longer new.
    let stale = jiProduct("p3", name: "New Serum", createdAt: "2026-07-01T09:00:00Z")
    #expect(jiHas(JournalInsight.findings(entries: full, usage: [], products: [stale],
                                          shelfFlagged: [], today: jiToday), .newProduct) == false)

    // Stamped in the future: never in play.
    let future = jiProduct("p3", name: "New Serum",
                           createdAt: JournalInsight.day(jiToday, offset: 3) + "T09:00:00Z")
    #expect(jiHas(JournalInsight.findings(entries: full, usage: [], products: [future],
                                          shelfFlagged: [], today: jiToday), .newProduct) == false)

    let serum = jiProduct("p3", name: "New Serum", createdAt: addedDay + "T09:00:00Z")

    // Only two logged days before it: not enough to compare against.
    let thinBefore = jiEntries(jiSpan(0..<4, .breakout) + jiSpan(11..<13, .clear))
    #expect(jiHas(JournalInsight.findings(entries: thinBefore, usage: [], products: [serum],
                                          shelfFlagged: [], today: jiToday), .newProduct) == false)

    // Only two logged days since: the same refusal on the other side.
    let thinAfter = jiEntries(jiSpan(0..<2, .breakout) + jiSpan(11..<14, .clear))
    #expect(jiHas(JournalInsight.findings(entries: thinAfter, usage: [], products: [serum],
                                          shelfFlagged: [], today: jiToday), .newProduct) == false)
}

@Test func journalNewProductWatchRespectsItsDeltaThreshold() {
    let addedDay = JournalInsight.day(jiToday, offset: -20)
    let serum = jiProduct("p3", name: "New Serum", createdAt: addedDay + "T09:00:00Z")

    // Sixteenths keep both rates exact. After: 16 good of 16 = 1.0.
    let after = jiSpan(0..<16, .clear)

    // Before: 12 good of 16 = 0.75. A gap of 0.25, under the 0.30 floor.
    let quietBefore = jiSpan(21..<33, .clear) + jiSpan(33..<37, .breakout)
    #expect(jiHas(JournalInsight.findings(entries: jiEntries(after + quietBefore), usage: [],
                                          products: [serum], shelfFlagged: [], today: jiToday),
                  .newProduct) == false)

    // Before: 11 good of 16 = 0.6875. A gap of 0.3125, over the floor.
    let loudBefore = jiSpan(21..<32, .clear) + jiSpan(32..<37, .breakout)
    #expect(jiHas(JournalInsight.findings(entries: jiEntries(after + loudBefore), usage: [],
                                          products: [serum], shelfFlagged: [], today: jiToday),
                  .newProduct))
}

// MARK: - Findings: shared-ingredient cross-reference

@Test func journalSharedIngredientNamesOneRealIngredient() {
    let fx = jiContrast(p1Offsets: [0, 1, 2, 3], good: [4, 5, 6, 7, 8, 9],
                        p1Ingredients: [("Aqua", "aqua"), ("Parfum", "parfum")])
    let caution = jiFirst(jiFindings(fx, shelfFlagged: ["aqua", "parfum"]), .product)

    #expect(caution?.mood == .caution)
    // Aqua is a filler in the knowledge table and is skipped, so the first ingredient
    // that actually means something is named instead.
    #expect(caution?.sharedIngredientRaw == "Parfum")
    #expect(caution?.detail.hasSuffix("It shares Parfum with something else on your shelf that didn't work out.") == true)
}

@Test func journalSharedIngredientIgnoresFillersAndUnflaggedIngredients() {
    let onlyFiller = jiContrast(p1Offsets: [0, 1, 2, 3], good: [4, 5, 6, 7, 8, 9],
                                p1Ingredients: [("Aqua", "aqua")])
    #expect(jiFirst(jiFindings(onlyFiller, shelfFlagged: ["aqua"]), .product)?.sharedIngredientRaw == nil)

    // The flagged set does not contain this ingredient's normalised key.
    let notFlagged = jiContrast(p1Offsets: [0, 1, 2, 3], good: [4, 5, 6, 7, 8, 9],
                                p1Ingredients: [("Parfum", "parfum")])
    #expect(jiFirst(jiFindings(notFlagged, shelfFlagged: ["glycerin"]), .product)?.sharedIngredientRaw == nil)

    // An empty shelf-flag set can never produce a cross-reference.
    #expect(jiFirst(jiFindings(notFlagged, shelfFlagged: []), .product)?.sharedIngredientRaw == nil)
}

@Test func journalSharedIngredientNeverAttachesToAGoodFinding() {
    // The same ingredient and the same flag, but the contrast is in the product's favour.
    let fx = jiContrast(p1Offsets: [0, 1, 2, 3], good: [0, 1, 2, 3, 4, 5, 6],
                        p1Ingredients: [("Parfum", "parfum")])
    let good = jiFirst(jiFindings(fx, shelfFlagged: ["parfum"]), .product)
    #expect(good?.mood == .good)
    #expect(good?.sharedIngredientRaw == nil)
    #expect(good?.detail.contains("Parfum") == false)
}

// MARK: - Findings: assembly

/// Everything fires at once: a caution product, a good product, a new product and a
/// trend. Only the first three survive, in that order.
private func jiCrowdedFixture() -> JIFixture {
    let spec = jiSpan(0..<4, .breakout) + jiSpan(4..<10, .clear) + jiSpan(14..<21, .clear)
    let usageSpec: [(Int, [String])] = (0..<4).map { ($0, ["p1"]) } + (4..<10).map { ($0, ["p2"]) }
    let products = [jiProduct("p1", name: "Cleanser A"),
                    jiProduct("p2", name: "Toner B"),
                    jiProduct("p3", name: "New Serum",
                              createdAt: JournalInsight.day(jiToday, offset: -5) + "T09:00:00Z")]
    return (jiEntries(spec), jiUsage(usageSpec), products)
}

@Test func journalFindingsAreCappedAtThreeInAFixedOrder() {
    let f = jiFindings(jiCrowdedFixture())
    #expect(f.count == 3)
    #expect(f.map(\.kind) == [JournalInsight.Finding.Kind.product, .product, .newProduct])
    #expect(f[0].mood == .caution)
    #expect(f[0].productID == "p1")
    #expect(f[1].mood == .good)
    #expect(f[1].productID == "p2")
    #expect(f[2].productID == "p3")
    // The trend was real but came fourth, so it was dropped rather than reordered.
    #expect(jiHas(f, .trend) == false)
    #expect(jiHas(f, .gathering) == false)
    // Distinct ids, so `ForEach` cannot collapse two cards into one.
    #expect(Set(f.map(\.id)).count == 3)
}

@Test func journalTrendFindingCarriesBothFortnights() {
    // No usage at all, so sections A and D are out and the trend has the stage.
    let spec = jiSpan(0..<6, .clear) + jiSpan(6..<10, .breakout) + jiSpan(14..<21, .clear)
    let f = JournalInsight.findings(entries: jiEntries(spec), usage: [], products: [],
                                    shelfFlagged: [], today: jiToday)
    #expect(f.count == 1)
    #expect(f[0].kind == .trend)
    #expect(f[0].mood == .caution)
    #expect(f[0].headline == "A rougher stretch than usual")
    #expect(f[0].detail == "6 of your last 10 logged days were good. The fortnight before: 7 of 7. Skintel's watching what changed.")
}

// MARK: - Determinism and the absence of a wall clock

@Test func journalInsightIsDeterministic() {
    let fx = jiCrowdedFixture()
    for _ in 0..<5 {
        #expect(jiFindings(fx, shelfFlagged: ["parfum"]) == jiFindings(fx, shelfFlagged: ["parfum"]))
        #expect(JournalInsight.grid(entries: fx.entries, today: jiToday)
                == JournalInsight.grid(entries: fx.entries, today: jiToday))
        #expect(JournalInsight.progress(entries: fx.entries, today: jiToday)
                == JournalInsight.progress(entries: fx.entries, today: jiToday))
        #expect(JournalInsight.trend(entries: fx.entries, today: jiToday)
                == JournalInsight.trend(entries: fx.entries, today: jiToday))
        #expect(JournalInsight.payback(entries: fx.entries, today: jiToday)
                == JournalInsight.payback(entries: fx.entries, today: jiToday))
    }
}

/// The same relative log, hung off a different frozen day in a different year, must
/// produce the same answers. A stray `Date()` or `Calendar.isDateInToday` inside the
/// engine breaks exactly this.
@Test func journalInsightReadsTheInjectedDayNotTheWallClock() {
    let contrast = jiContrast(p1Offsets: [0, 1, 2, 3], good: [0, 1, 2, 3, 4, 5, 6], today: jiAltToday)
    let good = jiFirst(jiFindings(contrast, today: jiAltToday), .product)
    #expect(good?.mood == .good)
    #expect(good?.detail == "Cleanser A — good on 4 of the 4 days you ticked it. On days without it, 3 of 6.")

    let record = jiEntries(jiSpan(0..<3, .clear), today: jiAltToday)
    #expect(JournalInsight.payback(entries: record, today: jiAltToday) == "3 good days in a row — your best run yet.")

    let p = JournalInsight.progress(entries: record, today: jiAltToday)
    #expect(p.loggedStreak == 3)
    #expect(p.currentGoodRun == 3)
    #expect(p.bestGoodRun == 3)

    // And the 2026 answers are unaffected by having run the 2019 ones first.
    #expect(JournalInsight.payback(entries: [], today: jiToday)
            == "10 more logged days and Skintel can start matching this to your shelf.")
}

@Test func journalCopyNeverUsesTheBannedWords() {
    var strings: [String] = [JournalInsight.payback(entries: [], today: jiToday)]
    for f in jiFindings(jiCrowdedFixture(), shelfFlagged: ["parfum"]) {
        strings.append(f.headline)
        strings.append(f.detail)
    }
    for f in JournalInsight.findings(entries: [], usage: [], products: [], shelfFlagged: [], today: jiToday) {
        strings.append(f.headline)
        strings.append(f.detail)
    }

    for s in strings {
        let lower = s.lowercased()
        #expect(s.contains("AI") == false)
        #expect(lower.contains("culprit") == false)
        #expect(lower.contains("verdict") == false)
    }
}
