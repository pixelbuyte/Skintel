import Foundation
import Testing
@testable import SkintelCore

// MARK: - Streaks (You › streak card, Today › check-in "Day N")

@Test func streakCountsBackFromToday() {
    let s = Streaks(days: ["2026-09-25", "2026-09-24", "2026-09-23", "2026-09-20"], today: "2026-09-25")
    #expect(s.current == 3)
    #expect(s.loggedToday)
    #expect(s.best == 3)
    #expect(s.totalDays == 4)
}

@Test func streakStaysAliveUntilTodayEnds() {
    // Today not logged yet: the run ending yesterday still counts.
    let s = Streaks(days: ["2026-09-24", "2026-09-23"], today: "2026-09-25")
    #expect(s.current == 2)
    #expect(!s.loggedToday)
    // A gap of a full day breaks it.
    let broken = Streaks(days: ["2026-09-23", "2026-09-22"], today: "2026-09-25")
    #expect(broken.current == 0)
    #expect(broken.best == 2)
}

@Test func bestStreakFindsTheLongestRunAnywhere() {
    let days = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05",
                "2026-09-10", "2026-09-24", "2026-09-25"]
    let s = Streaks(days: days, today: "2026-09-25")
    #expect(s.current == 2)
    #expect(s.best == 5)
}

@Test func streakCrossesMonthYearAndLeapDay() {
    #expect(Streaks(days: ["2025-12-31", "2026-01-01"], today: "2026-01-01").current == 2)
    #expect(Streaks(days: ["2028-02-28", "2028-02-29", "2028-03-01"], today: "2028-03-01").current == 3)
    // 2026 is not a leap year: Feb 28 → Mar 1 is consecutive.
    #expect(Streaks(days: ["2026-02-28", "2026-03-01"], today: "2026-03-01").current == 2)
}

@Test func streakIgnoresDuplicatesMalformedAndImpossibleDays() {
    let s = Streaks(days: ["2026-09-25", "2026-09-25", "garbage", "2026-02-30", "2026-9-24", "", "2026-09-24T08:00:00Z"],
                    today: "2026-09-25")
    #expect(s.totalDays == 2)       // 25th once, plus the 24th from the timestamp's day part
    #expect(s.current == 2)
    #expect(Streaks(days: [], today: "2026-09-25") == Streaks(current: 0, best: 0, loggedToday: false, totalDays: 0))
    #expect(Streaks(days: ["2026-09-25"], today: "not a day").current == 0)
}

@Test func streakUsesTheInjectedClockAndTimeZone() throws {
    // 2026-09-25 03:30 UTC is still the 24th in Los Angeles.
    let now = Date(timeIntervalSince1970: 1_790_307_000)
    let utc = try #require(TimeZone(identifier: "UTC"))
    let la = try #require(TimeZone(identifier: "America/Los_Angeles"))
    #expect(Streaks.dayKey(now, timeZone: utc) == "2026-09-25")
    #expect(Streaks.dayKey(now, timeZone: la) == "2026-09-24")
    let days = ["2026-09-24", "2026-09-23"]
    #expect(Streaks(days: days, now: now, timeZone: la).loggedToday)
    #expect(!Streaks(days: days, now: now, timeZone: utc).loggedToday)
    #expect(Streaks(days: days, now: now, timeZone: utc).current == 2)
}

@Test func milestonesFillTowardTheNextOne() {
    #expect(Streaks.nextMilestone(after: 0) == 3)
    #expect(Streaks.nextMilestone(after: 3) == 7)
    #expect(Streaks.nextMilestone(after: 365) == nil)
    let four = Streaks(current: 4, best: 4, loggedToday: true, totalDays: 4)
    #expect(four.nextMilestone == 7)
    #expect(four.milestoneProgress == 0.25)          // 3 → 7, one day in
    #expect(Streaks(current: 0, best: 0, loggedToday: false, totalDays: 0).milestoneProgress == 0)
    #expect(Streaks(current: 400, best: 400, loggedToday: true, totalDays: 400).milestoneProgress == 1)
}

@Test func weekRowMarksLoggedMissedOpenUpcomingAndNotStarted() {
    // Friday 2026-09-25, week starting Monday (firstWeekday 2): Mon 21 … Sun 27.
    let days = ["2026-09-22", "2026-09-24"]
    let week = Streaks.week(days: days, today: "2026-09-25", firstWeekday: 2)
    #expect(week.map(\.key) == ["2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24",
                                "2026-09-25", "2026-09-26", "2026-09-27"])
    #expect(week.map(\.state) == [.notStarted, .logged, .missed, .logged, .open, .upcoming, .upcoming])
    #expect(week.map(\.weekday) == [2, 3, 4, 5, 6, 7, 1])
    #expect(week.filter(\.isToday).map(\.key) == ["2026-09-25"])
}

@Test func weekRowStartsOnSundayByDefaultAndLogsToday() {
    let week = Streaks.week(days: ["2026-09-20", "2026-09-25"], today: "2026-09-25")
    #expect(week.first?.key == "2026-09-20")          // Sunday
    #expect(week.first?.weekday == 1)
    #expect(week[5].state == .logged)                  // today, logged
    #expect(week[1].state == .missed)
    #expect(Streaks.week(days: [], today: "2026-09-25").allSatisfy { $0.state != .missed })
    #expect(Streaks.week(days: [], today: "bad").isEmpty)
}

@Test func dayKeysRoundTripAndKnowTheirWeekday() {
    #expect(Streaks.dayNumber("1970-01-01") == 0)
    #expect(Streaks.key(forDayNumber: 0) == "1970-01-01")
    #expect(Streaks.weekday(of: "1970-01-01") == 5)    // Thursday
    #expect(Streaks.weekday(of: "2026-09-25") == 6)    // Friday
    #expect(Streaks.weekday(of: "1969-12-28") == 1)    // Sunday, before the epoch
    for key in ["1999-12-31", "2000-02-29", "2026-09-25", "2100-03-01"] {
        #expect(Streaks.dayNumber(key).map(Streaks.key(forDayNumber:)) == key)
    }
    #expect(Streaks.dayNumber("2100-02-29") == nil)    // 2100 is not a leap year
}
