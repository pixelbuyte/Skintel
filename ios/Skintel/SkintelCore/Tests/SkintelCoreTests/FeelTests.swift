import Foundation
import Testing
@testable import SkintelCore

// MARK: - Helpers

/// Location-independent calendar: every `CheckIn` test pins UTC so a CI machine in any
/// time zone reads the same hour out of the same `Date`.
private func utcCalendar() -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.timeZone = TimeZone(secondsFromGMT: 0)
    return Calendar(identifier: .gregorian).date(from: components)!
}

private func parfum(badCount: Int = 3) -> Culprit {
    Culprit(name: "Parfum", normalized: "parfum", badCount: badCount, goodCount: 0,
            badProducts: [], goodProducts: [], risk: .high)
}

/// Every `CheckIn.line` argument in one place so each test states only what it changes.
private func checkIn(productCount: Int = 6,
                     badProductCount: Int = 3,
                     topTrigger: Culprit? = nil,
                     journalStreak: Int = 0,
                     routineDone: Int = 0,
                     routineTotal: Int = 0,
                     lastScanAt: Date? = nil,
                     now: Date = utcDate(2026, 3, 10, 20),
                     calendar: Calendar = utcCalendar()) -> String {
    CheckIn.line(productCount: productCount,
                 badProductCount: badProductCount,
                 topTrigger: topTrigger,
                 journalStreak: journalStreak,
                 routineDone: routineDone,
                 routineTotal: routineTotal,
                 lastScanAt: lastScanAt,
                 now: now,
                 calendar: calendar)
}

// MARK: - HapticProfile

@Test func everyIntensityIsInsideTheEnvelope() {
    for event in HapticEvent.allCases {
        for strength in HapticStrength.allCases {
            let i = HapticProfile.intensity(event, strength: strength)
            #expect(i >= HapticProfile.floor)
            #expect(i <= 1.0)
        }
    }
}

@Test func intensityRisesWithStrength() {
    for event in HapticEvent.allCases {
        // `<=` because the floor clamps `refreshDone` at `.gentle`.
        #expect(HapticProfile.intensity(event, strength: .gentle)
                <= HapticProfile.intensity(event, strength: .medium))
        #expect(HapticProfile.intensity(event, strength: .medium)
                < HapticProfile.intensity(event, strength: .full))
    }
}

@Test func floorIsLiveNotDecorative() {
    #expect(HapticProfile.intensity(.refreshDone, strength: .gentle) == HapticProfile.floor)
    #expect(HapticEvent.refreshDone.base * HapticStrength.gentle.scale < HapticProfile.floor)
}

@Test func nothingReachesFullWhack() {
    for event in HapticEvent.allCases {
        #expect(HapticProfile.intensity(event, strength: .full) <= 0.62)
    }
}

@Test func successRisesAndErrorFalls() {
    for strength in HapticStrength.allCases {
        #expect(HapticProfile.intensity(.successB, strength: strength)
                > HapticProfile.intensity(.successA, strength: strength))
        #expect(HapticProfile.intensity(.errorB, strength: strength)
                < HapticProfile.intensity(.errorA, strength: strength))
    }
}

@Test func strengthRoundTripsThroughItsRawValue() {
    for strength in HapticStrength.allCases {
        #expect(HapticStrength(rawValue: strength.rawValue) == strength)
    }
    #expect(HapticStrength(rawValue: "bogus") == nil)
    #expect(HapticStrength.gentle.rawValue == "gentle")
}

@Test func everyStrengthHasANonEmptyLabel() {
    for strength in HapticStrength.allCases {
        #expect(!strength.label.isEmpty)
        #expect(strength.id == strength.rawValue)
    }
}

// MARK: - CheckIn.line

@Test func routineOutranksEverythingAndPluralisesCorrectly() {
    #expect(checkIn(topTrigger: parfum(),
                    journalStreak: 9,
                    routineDone: 2,
                    routineTotal: 5,
                    lastScanAt: utcDate(2026, 3, 9)) == "3 steps left tonight.")

    #expect(checkIn(topTrigger: parfum(),
                    journalStreak: 9,
                    routineDone: 4,
                    routineTotal: 5,
                    lastScanAt: utcDate(2026, 3, 9)) == "1 step left tonight.")
}

@Test func slotPhraseComesFromNowNotTheWallClock() {
    #expect(checkIn(routineDone: 2, routineTotal: 5, now: utcDate(2026, 3, 10, 8))
            == "3 steps left this morning.")
    #expect(checkIn(routineDone: 2, routineTotal: 5, now: utcDate(2026, 3, 10, 20))
            == "3 steps left tonight.")
}

@Test func slotPhraseSwitchesAtFifteenHundred() {
    // Must match `RoutineStore.currentSlot(now:)`, which switches at hour 15, not 12.
    #expect(checkIn(routineDone: 0, routineTotal: 3, now: utcDate(2026, 3, 10, 14, 59))
            == "3 steps left this morning.")
    #expect(checkIn(routineDone: 0, routineTotal: 3, now: utcDate(2026, 3, 10, 15, 0))
            == "3 steps left tonight.")
}

@Test func triggerOutranksStreak() {
    #expect(checkIn(topTrigger: parfum(badCount: 3), journalStreak: 9)
            == "Parfum shows up in 3 products that broke you out.")
}

@Test func streakLineWhenThereIsNoTrigger() {
    #expect(checkIn(journalStreak: 6) == "6 days logged in a row.")
    // The threshold is 2 — a one-day streak is not a streak.
    #expect(checkIn(journalStreak: 1) != "1 days logged in a row.")
}

@Test func finishedRoutineFallsBelowTheTriggerLine() {
    #expect(checkIn(topTrigger: parfum(), routineDone: 5, routineTotal: 5)
            == "Parfum shows up in 3 products that broke you out.")
    #expect(checkIn(routineDone: 5, routineTotal: 5) == "All 5 steps done tonight.")
    // A one-step routine is common on the "Sensitive Skin" template, and "All 1 steps
    // done" is the kind of wording that makes an app feel unfinished.
    #expect(checkIn(routineDone: 1, routineTotal: 1) == "All 1 step done tonight.")
}

@Test func emptyAndNearlyEmptyShelf() {
    #expect(checkIn(productCount: 0, badProductCount: 0)
            == "Add your first product and Skintel can start finding patterns.")
    #expect(checkIn(productCount: 1, badProductCount: 0)
            == "One product on your shelf. Add another and patterns start.")
    #expect(checkIn(productCount: 4, badProductCount: 1)
            == "Mark two products as Broke out and Skintel can find what they share.")
}

@Test func lastScanRelativeDaysDeriveFromNow() {
    let now = utcDate(2026, 3, 10, 9)
    #expect(checkIn(lastScanAt: utcDate(2026, 3, 10, 23), now: now) == "Up to date. Last scan today.")
    #expect(checkIn(lastScanAt: utcDate(2026, 3, 9, 1), now: now) == "Up to date. Last scan yesterday.")
    #expect(checkIn(lastScanAt: utcDate(2026, 3, 5, 12), now: now) == "Up to date. Last scan 5 days ago.")
    // Clock skew: a scan stamped after `now` reads "today", never a negative count.
    #expect(checkIn(lastScanAt: utcDate(2026, 3, 12, 12), now: now) == "Up to date. Last scan today.")
}

@Test func fullFallback() {
    // Note: `productCount: 0` is caught by the empty-shelf branch above, so the true
    // fallback needs a stocked shelf with nothing else to say.
    #expect(checkIn(productCount: 3, badProductCount: 2, lastScanAt: nil) == "Up to date.")
}

@Test func isDeterministic() {
    let a = checkIn(productCount: 9, badProductCount: 4, topTrigger: parfum(badCount: 4),
                    journalStreak: 3, routineDone: 1, routineTotal: 4,
                    lastScanAt: utcDate(2026, 3, 8))
    let b = checkIn(productCount: 9, badProductCount: 4, topTrigger: parfum(badCount: 4),
                    journalStreak: 3, routineDone: 1, routineTotal: 4,
                    lastScanAt: utcDate(2026, 3, 8))
    #expect(a == b)
}

@Test func isPureOfTheWallClock() {
    // Same hour, one week apart. If a bare `Date()` leaked in, these would diverge.
    let first = checkIn(routineDone: 1, routineTotal: 4, now: utcDate(2026, 3, 3, 20))
    let second = checkIn(routineDone: 1, routineTotal: 4, now: utcDate(2026, 3, 10, 20))
    #expect(first == second)
    #expect(first == "3 steps left tonight.")
}

@Test func copyNeverUsesTheBannedWords() {
    let now = utcDate(2026, 3, 10, 20)
    let lines = [
        checkIn(routineDone: 2, routineTotal: 5, now: now),
        checkIn(topTrigger: parfum(), now: now),
        checkIn(journalStreak: 6, now: now),
        checkIn(routineDone: 4, routineTotal: 4, now: now),
        checkIn(productCount: 0, badProductCount: 0, now: now),
        checkIn(productCount: 1, badProductCount: 0, now: now),
        checkIn(productCount: 4, badProductCount: 1, now: now),
        checkIn(lastScanAt: utcDate(2026, 3, 10, 1), now: now),
        checkIn(lastScanAt: utcDate(2026, 3, 9, 1), now: now),
        checkIn(lastScanAt: utcDate(2026, 3, 1, 1), now: now),
        checkIn(now: now),
    ]
    for line in lines {
        let s = line.lowercased()
        #expect(!s.isEmpty)
        #expect(!s.contains("ai "))
        #expect(!s.contains("culprit"))
        #expect(!s.contains("verdict"))
    }
}
