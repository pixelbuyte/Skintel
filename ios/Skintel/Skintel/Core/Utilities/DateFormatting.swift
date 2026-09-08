import Foundation

enum DateFormatting {
    nonisolated(unsafe) private static let dayLabel: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
        return f
    }()

    nonisolated(unsafe) private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    nonisolated(unsafe) private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// "THU · JUL 16" (uppercased by the label style).
    static func header(_ d: Date = Date()) -> String { dayLabel.string(from: d) }

    static func weekdayShort(_ d: Date) -> String { weekday.string(from: d) }

    static func short(_ d: Date) -> String { shortDate.string(from: d) }

    /// "today" / "yesterday" / "Mon" / "Jul 3"
    static func relative(_ d: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "today" }
        if cal.isDateInYesterday(d) { return "yesterday" }
        if let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: now)).day, days < 7 {
            return weekday.string(from: d)
        }
        return shortDate.string(from: d)
    }

    static func greeting(_ d: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: d) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}
