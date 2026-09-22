import SwiftUI
import SkintelCore

/// Local-only (no API call) read of the last 30 days of journal entries: a calm-day count,
/// a plain-language trend versus the two weeks before, and the products mentioned most in
/// "Used: …" note lines. Fills the dead space between the week strip and the paid pattern
/// analysis with something that costs nothing to compute.
struct JournalInsights {
    struct Day { let date: Date; let entry: JournalEntry? }
    struct ProductMention { let name: String; let count: Int }

    let last30: [Day]
    let calmDays: Int
    let loggedDays: Int
    let trendLabel: String?
    let topProducts: [ProductMention]

    private static func rank(_ c: JournalCondition) -> Int {
        switch c {
        case .clear: 3
        case .mild: 2
        case .moderate: 1
        case .breakout: 0
        }
    }

    static func build(entries: [JournalEntry]) -> JournalInsights? {
        guard !entries.isEmpty else { return nil }
        let cal = Calendar.current
        let today = Date()
        let byDay = Dictionary(uniqueKeysWithValues: entries.map { ($0.entryDate, $0) })
        let last30: [Day] = (0..<30).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            return Day(date: d, entry: byDay[ISO8601.dayString(d)])
        }

        let calmDays = last30.filter { $0.entry.map { $0.condition == .clear || $0.condition == .mild } == true }.count
        let loggedDays = last30.filter { $0.entry != nil }.count

        let priorHalf = last30.prefix(15).compactMap(\.entry)
        let recentHalf = last30.suffix(15).compactMap(\.entry)
        var trendLabel: String?
        if priorHalf.count >= 3, recentHalf.count >= 3 {
            let priorAvg = Double(priorHalf.map { rank($0.condition) }.reduce(0, +)) / Double(priorHalf.count)
            let recentAvg = Double(recentHalf.map { rank($0.condition) }.reduce(0, +)) / Double(recentHalf.count)
            let delta = recentAvg - priorAvg
            if delta > 0.4 { trendLabel = "Calmer than the two weeks before" }
            else if delta < -0.4 { trendLabel = "A bit bumpier than the two weeks before" }
            else { trendLabel = "About the same as the two weeks before" }
        }

        var counts: [String: Int] = [:]
        var order: [String] = []
        for day in last30 {
            guard let notes = day.entry?.notes, let range = notes.range(of: "Used: ") else { continue }
            let line = notes[range.upperBound...].split(separator: "\n").first.map(String.init) ?? ""
            for name in line.split(separator: ",") {
                let n = name.trimmingCharacters(in: .whitespaces)
                guard !n.isEmpty else { continue }
                if counts[n] == nil { order.append(n) }
                counts[n, default: 0] += 1
            }
        }
        let topProducts = order.map { ProductMention(name: $0, count: counts[$0] ?? 0) }
            .sorted { $0.count > $1.count }
            .prefix(3)

        return JournalInsights(last30: last30, calmDays: calmDays, loggedDays: loggedDays,
                                trendLabel: trendLabel, topProducts: Array(topProducts))
    }
}

/// Calm-day meter (30 dots), the plain-language trend, a promoted streak, and "shelf mates" —
/// all derived from data already loaded by `JournalStore`, so this adds no new request.
struct JournalInsightsCard: View {
    let insights: JournalInsights
    let streak: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 10)

    var body: some View {
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                Text("Your last 30 days").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)

                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(Array(insights.last30.enumerated()), id: \.offset) { _, day in
                        SKDot(tone: day.entry?.condition.tone ?? .neutral, size: 9)
                            .opacity(day.entry == nil ? 0.35 : 1)
                    }
                }

                Text(insights.loggedDays == 0
                     ? "Log a few days and this fills in on its own."
                     : "\(insights.calmDays) of your last 30 days were calm or good.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)

                if let trend = insights.trendLabel {
                    Text(trend).font(SKFont.sans(13, weight: .semibold)).foregroundStyle(SKColor.primary)
                }

                if streak > 0 || !insights.topProducts.isEmpty {
                    Rectangle().fill(SKColor.line).frame(height: 1)
                }

                if streak > 0 {
                    HStack(spacing: SKSpace.sm) {
                        Text("🔥").font(.system(size: 15))
                        Text(streak == 1 ? "1 day in a row" : "\(streak) days in a row")
                            .font(SKFont.sans(13, weight: .semibold)).foregroundStyle(SKColor.ink)
                    }
                }

                if !insights.topProducts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Most logged lately").font(SKFont.sans(12, weight: .semibold)).foregroundStyle(SKColor.muted)
                        FlowLayout(spacing: 6) {
                            ForEach(insights.topProducts, id: \.name) { p in
                                SKChip("\(p.name) · \(p.count)×")
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Shown instead of a blank "Earlier" section when the user has never logged a day.
struct JournalEmptyHistory: View {
    var body: some View {
        SKCard {
            VStack(spacing: SKSpace.md) {
                SKMascot(size: 64)
                Text("Your entries will live here").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                Text("Most people start noticing their own skin's rhythm after about a week of logging.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
