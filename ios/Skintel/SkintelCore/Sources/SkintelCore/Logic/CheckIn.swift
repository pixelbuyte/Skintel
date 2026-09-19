import Foundation

/// The one true sentence a pull-to-refresh hands back, computed entirely on this phone
/// from data the stores already hold. No network, no rotation, no randomness: the same
/// inputs always produce the same sentence, which is what makes it testable and what
/// stops it reading as a slot machine.
///
/// Every branch derives from the injected `now`. `Date()`, `.now`,
/// `Calendar.isDateInToday` and `isDateInYesterday` are banned inside this file — that
/// exact bug has already shipped in this repo once.
public enum CheckIn {
    /// Priority order is deliberate: the thing she can act on in the next sixty seconds
    /// outranks the thing that is merely interesting.
    ///
    /// - Parameters:
    ///   - productCount: products on the shelf.
    ///   - badProductCount: products marked "Broke out".
    ///   - topTrigger: highest-ranked ingredient that repeats across bad products.
    ///   - journalStreak: consecutive days logged, today or yesterday inclusive.
    ///   - routineDone: steps ticked off in the current slot.
    ///   - routineTotal: steps in the current slot.
    ///   - lastScanAt: timestamp of the newest saved scan, if any.
    ///   - now: the clock. Every branch derives from this.
    ///   - calendar: injected so tests can pin the time zone.
    public static func line(productCount: Int,
                            badProductCount: Int,
                            topTrigger: Culprit?,
                            journalStreak: Int,
                            routineDone: Int,
                            routineTotal: Int,
                            lastScanAt: Date?,
                            now: Date,
                            calendar: Calendar = .current) -> String {
        // Mirrors `RoutineStore.currentSlot(now:)`, which switches at hour 15, not 12.
        let slotPhrase = calendar.component(.hour, from: now) < 15 ? "this morning" : "tonight"

        if routineTotal > 0, routineDone < routineTotal {
            let left = routineTotal - routineDone
            return "\(left) step\(left == 1 ? "" : "s") left \(slotPhrase)."
        }

        if let trigger = topTrigger {
            return "\(trigger.name) shows up in \(trigger.badCount) products that broke you out."
        }

        if journalStreak >= 2 {
            return "\(journalStreak) days logged in a row."
        }

        if routineTotal > 0 {
            return "All \(routineTotal) step\(routineTotal == 1 ? "" : "s") done \(slotPhrase)."
        }

        if productCount == 0 {
            return "Add your first product and Skintel can start finding patterns."
        }

        if productCount == 1 {
            return "One product on your shelf. Add another and patterns start."
        }

        if badProductCount < 2 {
            return "Mark two products as Broke out and Skintel can find what they share."
        }

        if let scanned = lastScanAt {
            // `max(0, …)` absorbs clock skew: a scan stamped in the future reads "today",
            // never a negative day count.
            let days = max(0, calendar.dateComponents([.day],
                                                      from: calendar.startOfDay(for: scanned),
                                                      to: calendar.startOfDay(for: now)).day ?? 0)
            if days == 0 { return "Up to date. Last scan today." }
            if days == 1 { return "Up to date. Last scan yesterday." }
            return "Up to date. Last scan \(days) days ago."
        }

        return "Up to date."
    }
}
