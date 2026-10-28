import SwiftUI
import SkintelCore

/// Insights' face scan section: one row per zone with its top finding in words, a bar per scan
/// of the week against Day 1, and the way into the full map. Missed days and zones that were not
/// read stay empty, never drawn as clear; dashed columns fill in as they scan. Before a first scan
/// it offers one, with the NEW tag.
struct InsightsFaceScanCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openFaceScan) private var openFaceScan

    private static let days = 7

    var body: some View {
        let summary = FaceScanSummary(env: env)
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack(alignment: .firstTextBaseline, spacing: SKSpace.sm) {
                    Text("Face scan").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    if !summary.hasScans { SKNewBadge() }
                    Spacer(minLength: SKSpace.sm)
                    if summary.newest != nil {
                        Text(newestLine(summary)).font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
                    }
                }
                if let newest = summary.newest {
                    // This week's scans; a map kept from an earlier week stands alone as Day 1.
                    let week = summary.week.isEmpty ? [newest] : summary.week
                    Text(week.count == 1 ? "One scan so far, so this is your starting point. Each daily photo adds a column."
                                         : "Each column is one scan, compared with Day 1. Missed days stay empty.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    dayHeader(count: week.count)
                    VStack(spacing: 0) {
                        ForEach(Array(FaceZone.allCases.enumerated()), id: \.element) { index, zone in
                            if index > 0 { Rectangle().fill(SKColor.line).frame(height: 1) }
                            zoneRow(zone, week: week, newest: newest.result)
                        }
                    }
                    Text("Newest scan, \(FaceScanSummary.dayLabel(newest.day)). A cosmetic read, not a diagnosis.")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                    SKButton(title: "See your map", kind: .secondary, systemImage: "face.dashed") { openFaceScan() }
                } else {
                    Text(summary.hasScans ? "Your last scan couldn't be read. Try another in good light."
                                          : "A 15-second head turn gives you a zone-by-zone map of your face.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    SKButton(title: "Scan your face", kind: .secondary, systemImage: "faceid") { openFaceScan() }
                }
            }
        }
    }

    /// "Day 1 baseline" with one scan, else which day of the week the newest scan is.
    private func newestLine(_ summary: FaceScanSummary) -> String {
        summary.scanCount <= 1 ? "Day 1 baseline" : "Day \(min(summary.scanCount, Self.days)) of \(Self.days)"
    }

    private func dayHeader(count: Int) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 112)
            HStack(spacing: 4) {
                ForEach(1...Self.days, id: \.self) { d in
                    Text("\(d)").font(SKFont.label).foregroundStyle(d <= count ? SKColor.ink : SKColor.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            Color.clear.frame(width: 64)
        }
        .accessibilityHidden(true)
    }

    private func zoneRow(_ zone: FaceZone, week: [FaceScanEntry], newest: FaceScanResult) -> some View {
        let levels: [Int?] = week.map { FaceScanSummary.level(zone, in: $0.result) }
        let slots: [Int??] = (0..<Self.days).map { i -> Int?? in i < levels.count ? .some(levels[i]) : .none }
        let first = levels.first ?? nil
        let last = levels.last ?? nil
        let baseline = week.count == 1
        let word: String
        let color: Color
        if let first, let last {
            if baseline {
                word = first == 0 ? "Clear" : first >= 2 ? FaceCalibration.Band.noticeable.label : FaceCalibration.Band.mild.label
                color = first == 0 ? SKColor.goodFg : SKColor.ink
            } else {
                word = last < first ? "Calmer" : last > first ? "More" : "Same"
                color = last < first ? SKColor.goodFg : last > first ? SKColor.cautionFg : SKColor.muted
            }
        } else {
            word = "Not read"
            color = SKColor.muted
        }
        let finding: String = {
            guard let read = newest.zone(zone) else { return "Not read" }
            if read.isClear { return "All five reads clear" }
            return read.topFinding?.metric.label ?? "Not read"
        }()
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(zone.label).font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Text(finding).font(SKFont.caption).foregroundStyle(SKColor.muted).lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<Self.days, id: \.self) { i in
                    bar(slots[i]).frame(maxWidth: .infinity)
                }
            }
            .frame(height: 24, alignment: .bottom)
            Text(word).font(SKFont.sans(13, weight: .semibold, relativeTo: .footnote)).foregroundStyle(color)
                .frame(width: 64, alignment: .trailing)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(zone.label), \(finding.lowercased()): \(spoken(word, baseline: baseline))")
    }

    /// The row's word for VoiceOver: "Day 1 baseline, some", "calmer than Day 1", "same as Day 1".
    private func spoken(_ word: String, baseline: Bool) -> String {
        if word == "Not read" { return "not read" }
        if baseline { return "Day 1 baseline, \(word.lowercased())" }
        return word == "Same" ? "same as Day 1" : "\(word.lowercased()) than Day 1"
    }

    /// One scan's column: nil is a day still to come (dashed), `.some(nil)` a zone that scan did
    /// not read (empty), else a bar by level.
    @ViewBuilder
    private func bar(_ slot: Int??) -> some View {
        switch slot {
        case .none:
            RoundedRectangle(cornerRadius: 2)
                .stroke(SKColor.ink.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(height: 22)
        case .some(.none):
            Color.clear.frame(height: 22)
        case .some(.some(let level)):
            RoundedRectangle(cornerRadius: 2)
                .fill(level == 0 ? SKColor.ink.opacity(0.16) : SKColor.primary)
                .frame(height: level >= 2 ? 22 : level == 1 ? 12 : 3)
        }
    }
}
