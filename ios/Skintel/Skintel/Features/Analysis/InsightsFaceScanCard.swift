import SwiftUI
import SkintelCore

/// Insights' face scan section: each zone's top finding from the newest scan, in words, and the
/// way into the full map. Before a first scan it offers one, with the NEW tag.
struct InsightsFaceScanCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openFaceScan) private var openFaceScan

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
                    let zones = FaceScanSummary.zoneWords(newest.result)
                    VStack(spacing: 0) {
                        ForEach(Array(zones.enumerated()), id: \.element.id) { index, line in
                            if index > 0 { Rectangle().fill(SKColor.line).frame(height: 1) }
                            zoneRow(line)
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
        summary.scanCount <= 1 ? "Day 1 baseline" : "Day \(min(summary.scanCount, 7)) of 7"
    }

    private func zoneRow(_ line: FaceScanSummary.ZoneWords) -> some View {
        HStack(spacing: SKSpace.sm) {
            Text(line.zone.label)
                .font(SKFont.sans(15, weight: .medium, relativeTo: .subheadline))
                .foregroundStyle(SKColor.ink)
            Spacer(minLength: SKSpace.sm)
            Text(line.words)
                .font(SKFont.secondary)
                .foregroundStyle(line.isClear ? SKColor.goodFg : SKColor.ink)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
    }
}
