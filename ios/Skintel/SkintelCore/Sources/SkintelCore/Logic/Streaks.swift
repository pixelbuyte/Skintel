import Foundation

/// Check-in streaks from journal day keys (`YYYY-MM-DD`, the person's calendar days — the
/// shape `JournalEntry.entryDate` has). Everything is integer day arithmetic on those keys:
/// no wall clock, no DST, no `isDateInToday`. The only clock input is the `today` key (or the
/// injected `now` + time zone that produces it), so every branch is testable.
public struct Streaks: Sendable, Hashable {
    /// Consecutive logged days ending today, or ending yesterday while today is still open.
    public let current: Int
    /// Longest run of consecutive logged days in `days` (never less than `current`).
    public let best: Int
    /// Whether today itself is logged, i.e. today's check-in already counted.
    public let loggedToday: Bool
    /// Distinct valid days logged.
    public let totalDays: Int

    public init(current: Int, best: Int, loggedToday: Bool, totalDays: Int) {
        self.current = current
        self.best = max(best, current)
        self.loggedToday = loggedToday
        self.totalDays = totalDays
    }

    /// - Parameters:
    ///   - days: Logged day keys. Duplicates and malformed keys are ignored; a timestamp's
    ///     first ten characters are used.
    ///   - today: The person's current day key.
    public init(days: [String], today: String) {
        let set = Set(days.compactMap(Self.dayNumber))
        guard let t = Self.dayNumber(today) else {
            self.init(current: 0, best: Self.longestRun(set), loggedToday: false, totalDays: set.count)
            return
        }
        let loggedToday = set.contains(t)
        var cursor = loggedToday ? t : t - 1
        var current = 0
        while set.contains(cursor) {
            current += 1
            cursor -= 1
        }
        self.init(current: current, best: Self.longestRun(set), loggedToday: loggedToday, totalDays: set.count)
    }

    /// Same as `init(days:today:)` with today taken from `now` in `timeZone` (the device's by
    /// default — the same calendar day `ISO8601.dayString` writes journal entries under).
    public init(days: [String], now: Date, timeZone: TimeZone = .autoupdatingCurrent) {
        self.init(days: days, today: Self.dayKey(now, timeZone: timeZone))
    }

    // MARK: Milestones

    /// Streak lengths worth marking. The ring on You fills toward the next one.
    public static let milestones = [3, 7, 14, 30, 60, 90, 180, 365]

    /// The first milestone above `streak`, or nil past the last one.
    public static func nextMilestone(after streak: Int) -> Int? {
        milestones.first { $0 > streak }
    }

    /// The next milestone for `current`.
    public var nextMilestone: Int? { Self.nextMilestone(after: current) }

    /// 0...1 progress from the previous milestone (or zero) to the next one; 1 past the last.
    public var milestoneProgress: Double {
        guard let next = nextMilestone else { return 1 }
        let previous = Self.milestones.last { $0 <= current } ?? 0
        let span = next - previous
        return span > 0 ? Double(current - previous) / Double(span) : 0
    }

    // MARK: Week row

    public enum DayState: String, Sendable, Hashable {
        /// A check-in exists for the day.
        case logged
        /// A past day with no check-in, after the person's first check-in.
        case missed
        /// Today, not logged yet — still open.
        case open
        /// Later this week.
        case upcoming
        /// Before the first check-in on record: not a miss, nothing was expected yet.
        case notStarted
    }

    public struct Day: Sendable, Hashable, Identifiable {
        public let key: String
        /// 1 = Sunday … 7 = Saturday, like `Calendar.component(.weekday, …)`.
        public let weekday: Int
        public let isToday: Bool
        public let state: DayState
        public var id: String { key }
    }

    /// The seven days of the week containing `today`, in order from `firstWeekday`
    /// (1 = Sunday … 7 = Saturday; pass `Calendar.current.firstWeekday`).
    public static func week(days: [String], today: String, firstWeekday: Int = 1) -> [Day] {
        guard let t = dayNumber(today) else { return [] }
        let set = Set(days.compactMap(dayNumber))
        let first = set.min()
        let start = ((firstWeekday - 1) % 7 + 7) % 7 + 1
        let offset = (weekday(ofDayNumber: t) - start + 7) % 7
        return (0..<7).map { i in
            let n = t - offset + i
            let state: DayState
            if set.contains(n) { state = .logged }
            else if n > t { state = .upcoming }
            else if n == t { state = .open }
            else if let first, n > first { state = .missed }
            else { state = .notStarted }
            return Day(key: key(forDayNumber: n), weekday: weekday(ofDayNumber: n), isToday: n == t, state: state)
        }
    }

    // MARK: Day keys

    /// `YYYY-MM-DD` for `now` in `timeZone`.
    public static func dayKey(_ now: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return key(forDayNumber: dayNumber(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1))
    }

    /// 1 = Sunday … 7 = Saturday for a day key, or nil when the key is malformed.
    public static func weekday(of key: String) -> Int? {
        dayNumber(key).map(weekday(ofDayNumber:))
    }

    /// Days since 1970-01-01 for a strict `YYYY-MM-DD` (first ten characters), rejecting
    /// impossible dates such as 2026-02-30.
    static func dayNumber(_ key: String) -> Int? {
        let parts = key.prefix(10).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        let n = dayNumber(year: y, month: m, day: d)
        return civil(n) == (y, m, d) ? n : nil
    }

    static func key(forDayNumber n: Int) -> String {
        let (y, m, d) = civil(n)
        return "\(pad(y, 4))-\(pad(m, 2))-\(pad(d, 2))"
    }

    /// 1970-01-01 was a Thursday (5).
    static func weekday(ofDayNumber n: Int) -> Int {
        ((n + 4) % 7 + 7) % 7 + 1
    }

    // Howard Hinnant's days_from_civil / civil_from_days (proleptic Gregorian).
    static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civil(_ n: Int) -> (Int, Int, Int) {
        let z = n + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }

    private static func longestRun(_ set: Set<Int>) -> Int {
        var best = 0
        for n in set where !set.contains(n - 1) {
            var length = 1
            while set.contains(n + length) { length += 1 }
            best = max(best, length)
        }
        return best
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let s = String(value)
        return s.count >= width ? s : String(repeating: "0", count: width - s.count) + s
    }
}
