import SwiftUI
import SkintelCore

/// The 3D map with the 7-day check (canvas screen 5): a dark hero with the face, zone glow and
/// labels, tappable day buttons, concentric rings with a legend, the insight, zones, tonight's
/// routine, the report once it exists, the history list and Ask. Levels are words and glyphs,
/// never raw scores (PRO-SPEC §6).
///
/// With `onUnlock` (no Skintel+, e.g. the free scan's real Day 1 map), the week is locked: the
/// rings card becomes the locked 7-day check, and the routine, the scan actions and Ask stay
/// hidden. Without it, the same cycle shows unlocked.
struct FaceResultView: View {
    let calibration: FaceCalibration
    let routine: FaceRoutine?
    /// The scan action to offer today ("Take today's photo", "Final sweep"), or nil.
    let nextAction: String?
    let onNext: () -> Void
    let onAsk: (() -> Void)?
    let onClose: () -> Void
    /// Not Skintel+ only: opens the Skintel+ wall from the locked 7-day check.
    var onUnlock: (() -> Void)? = nil

    @State private var selected: Int?

    private var isFree: Bool { onUnlock != nil }

    private var scans: [FaceScanEntry] { calibration.scans }
    private var index: Int {
        guard !scans.isEmpty else { return 0 }
        return min(selected ?? scans.count - 1, scans.count - 1)
    }
    private var entry: FaceScanEntry? { scans.isEmpty ? nil : scans[index] }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(spacing: 14) {
                    if let onUnlock { lockedWeekCard(unlock: onUnlock) } else { ringsCard }
                    insightCard
                    zonesCard
                    if let report = calibration.latestReport?.report { reportCard(report) }
                    if !isFree, let routine, !(routine.pm.isEmpty && routine.am.isEmpty) { routineCard(routine) }
                    if !isFree, let nextAction { SKButton(title: nextAction, systemImage: "faceid") { onNext() } }
                    if !isFree, let onAsk { SKButton(title: "Ask Skinstel about this scan", kind: nextAction == nil ? .primary : .secondary) { onAsk() } }
                    historyCard
                    Text("\(FaceScanResult.defaultDisclaimer) Photos are read, then deleted.")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
                }
                .skPagePadding()
                .padding(.top, SKSpace.lg)
                .padding(.bottom, 30)
            }
        }
        .skPageBackground()
        .ignoresSafeArea(edges: .top)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                Spacer()
                Text("FACE SCAN").font(SKFont.mono(12)).tracking(1.5)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, SKSpace.sm)
            VStack(alignment: .leading, spacing: SKSpace.xs) {
                Text("YOUR SKIN MAP · DAY \(index + 1) OF 7").font(SKFont.label).tracking(1.5).foregroundStyle(FaceScanColor.hot)
                Text(insight.title).font(SKFont.pageTitle).accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, 14)

            FaceMeshView(mode: .result, levels: FaceZoneLevels(result: entry?.result), labels: labels, zoom: 0.31)
                .frame(height: 330)
                .frame(maxWidth: SKLayout.readableWidth)
                .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                ZStack {
                    Rectangle().fill(SKColor.bg.opacity(0.14)).frame(height: 2).padding(.horizontal, 18)
                    HStack {
                        ForEach(1...7, id: \.self) { n in
                            dayButton(n)
                            if n < 7 { Spacer(minLength: 0) }
                        }
                    }
                }
                HStack {
                    Text("Tap a day · drag the face to turn it")
                    Spacer()
                    Text("◆ = unlock day").font(SKFont.label).foregroundStyle(FaceScanColor.hot)
                }
                .font(SKFont.caption).foregroundStyle(SKColor.bg.opacity(0.62))
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 54)
        .padding(.bottom, 22)
        .foregroundStyle(SKColor.bg)
        .background(SKColor.scannerBg, in: UnevenRoundedRectangle(bottomLeadingRadius: SKRadius.sheet, bottomTrailingRadius: SKRadius.sheet))
    }

    private func dayButton(_ n: Int) -> some View {
        let unlock = [1, 3, 5, 7].contains(n)
        let has = n <= scans.count
        let on = has && n - 1 == index
        let past = has && !on
        return Button { selected = n - 1; Haptics.selection() } label: {
            Text(unlock ? "\(n)◆" : "\(n)")
                .font(SKFont.mono(13))
                .foregroundStyle(on ? SKColor.scannerBg : past ? SKColor.cream : SKColor.bg.opacity(0.75))
                .frame(width: 44, height: 44)
                .background(on ? SKColor.bg : past ? SKColor.primary : SKColor.scannerBg, in: Circle())
                .overlay(Circle().stroke(on ? SKColor.bg : unlock ? SKColor.primary : SKColor.bg.opacity(0.25),
                                         lineWidth: on ? 2 : unlock ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .disabled(!has)
        .accessibilityLabel("Day \(n)")
        .accessibilityValue(has ? (on ? "Showing" : "Scanned") : "Not scanned yet")
    }

    // MARK: Zones

    /// Display order and label sides from the canvas.
    private static let zoneOrder: [(zone: FaceZone, side: FaceMeshLabel.Side, y: CGFloat)] = [
        (.forehead, .leading, 0.17), (.nose, .trailing, 0.36), (.rightCheek, .leading, 0.56),
        (.leftCheek, .trailing, 0.66), (.chin, .leading, 0.86),
    ]

    /// The zone's strongest metric in this scan, and its band.
    private func top(_ zone: FaceZone, in result: FaceScanResult?) -> (metric: FaceMetric, band: FaceCalibration.Band)? {
        guard let z = result?.zone(zone), let best = z.scores.max(by: { $0.value < $1.value }) else { return nil }
        return (best.key, FaceCalibration.band(best.value))
    }

    private var labels: [FaceMeshLabel] {
        Self.zoneOrder.compactMap { item in
            guard let t = top(item.zone, in: entry?.result) else { return nil }
            return FaceMeshLabel(zone: item.zone, title: item.zone.label.uppercased(),
                                 value: "\(t.metric.label) · \(t.band.label)".uppercased(),
                                 side: item.side, y: item.y, hot: t.band == .noticeable)
        }
    }

    private var zonesCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.zoneOrder.enumerated()), id: \.offset) { i, item in
                zoneRow(item.zone)
                if i < Self.zoneOrder.count - 1 { Divider().overlay(SKColor.line) }
            }
        }
        .padding(.horizontal, SKSpace.lg).padding(.vertical, SKSpace.xs)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .skCardShadow()
    }

    private func zoneRow(_ zone: FaceZone) -> some View {
        let t = top(zone, in: entry?.result)
        let level = t.map { FaceZoneLevels.level(for: $0.band) } ?? 0
        let trend = trendText(zone, metric: t?.metric)
        return HStack(spacing: SKSpace.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(zone.label).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                Text(trend.text).font(SKFont.caption).foregroundStyle(trend.calmer ? SKColor.goodFg : SKColor.muted)
            }
            Spacer()
            Text(t?.metric.label ?? "").font(SKFont.caption).foregroundStyle(SKColor.muted)
            HStack(spacing: 3) {
                Capsule().fill(level >= 1 ? SKColor.primary : SKColor.line).frame(width: 14, height: 6)
                Capsule().fill(level >= 2 ? SKColor.primary : SKColor.line).frame(width: 14, height: 6)
            }
            .accessibilityHidden(true)
            Text(t?.band.label ?? "Not read").font(SKFont.sans(13, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(SKColor.ink).frame(minWidth: 74, alignment: .trailing)
        }
        .padding(.vertical, SKSpace.md)
        .accessibilityElement(children: .combine)
    }

    /// The selected scan against Day 1, by band so it never implies more precision than it has.
    private func trendText(_ zone: FaceZone, metric: FaceMetric?) -> (text: String, calmer: Bool) {
        guard index > 0, let metric, let first = scans.first?.result.score(metric, in: zone),
              let now = entry?.result.score(metric, in: zone) else { return ("Day 1 baseline", false) }
        let a = FaceZoneLevels.level(for: FaceCalibration.band(first))
        let b = FaceZoneLevels.level(for: FaceCalibration.band(now))
        if b < a { return ("Calmer than Day 1", true) }
        if b > a { return ("More than Day 1", false) }
        return ("Same as Day 1", false)
    }

    // MARK: Rings

    private struct Ring { let milestone: FaceCalibration.Milestone; let color: Color; let radius: CGFloat }

    private var rings: [Ring] {
        [Ring(milestone: .faceMap, color: SKColor.ink, radius: 58),
         Ring(milestone: .oilPattern, color: SKColor.primary, radius: 46),
         Ring(milestone: .rednessBaseline, color: FaceScanColor.ringThree, radius: 34),
         Ring(milestone: .fullReport, color: SKColor.goodFg, radius: 22)]
    }

    private func ringStatus(_ m: FaceCalibration.Milestone) -> String {
        if calibration.isUnlocked(m) { return "READY ✓" }
        let left = calibration.scansToGo(for: m)
        if left == 0 { return m.requiresFinalScan ? "FINAL SWEEP" : "FIRST SWEEP" }
        return left == 1 ? "1 SCAN" : "\(left) SCANS"
    }

    private var ringsCard: some View {
        HStack(spacing: SKSpace.lg) {
            ZStack {
                ForEach(rings, id: \.radius) { ring in
                    Circle().stroke(SKColor.ink.opacity(0.07), lineWidth: 10)
                        .frame(width: ring.radius * 2, height: ring.radius * 2)
                    Circle().trim(from: 0, to: CGFloat(calibration.isUnlocked(ring.milestone) ? 1 : min(calibration.progress(for: ring.milestone), 0.999)))
                        .stroke(ring.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: ring.radius * 2, height: ring.radius * 2)
                }
            }
            .frame(width: 132, height: 132)
            .accessibilityElement()
            .accessibilityLabel(rings.map { "\($0.milestone.label) \(ringStatus($0.milestone).lowercased())" }.joined(separator: ", "))
            VStack(alignment: .leading, spacing: 9) {
                ForEach(rings, id: \.radius) { ring in
                    HStack(spacing: SKSpace.sm) {
                        RoundedRectangle(cornerRadius: 3).fill(ring.color).frame(width: 10, height: 10)
                        Text(ring.milestone.label).font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                        Spacer(minLength: 0)
                        Text(ringStatus(ring.milestone)).font(SKFont.label)
                            .foregroundStyle(calibration.isUnlocked(ring.milestone) ? SKColor.goodFg : SKColor.muted)
                    }
                }
            }
            .accessibilityHidden(true)
        }
        .padding(SKSpace.lg)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .skCardShadow()
    }

    // MARK: Locked week (free scan)

    /// The free scan's stand-in for the rings: the four rings drawn empty around a lock, the
    /// question the week answers, and the way into Skintel+.
    private func lockedWeekCard(unlock: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            HStack(spacing: SKSpace.lg) {
                ZStack {
                    ForEach(rings, id: \.radius) { ring in
                        Circle().stroke(SKColor.ink.opacity(0.07), lineWidth: 10)
                            .frame(width: ring.radius * 2, height: ring.radius * 2)
                    }
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.primary)
                }
                .frame(width: 132, height: 132)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("7-DAY CHECK").font(SKFont.label).tracking(1).foregroundStyle(SKColor.primary)
                    Text("Want to know if it's getting better?")
                        .font(SKFont.sans(17, weight: .semibold, relativeTo: .headline)).foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Follow it for 7 days with Skintel+")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            SKButton(title: "Get Skintel+", action: unlock)
        }
        .padding(SKSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .skCardShadow()
    }

    // MARK: Insight

    private var insight: (kicker: String, title: String, body: String) {
        let count = index + 1
        let summary = entry?.result.summary ?? ""
        if count >= 7, calibration.isUnlocked(.fullReport), let report = calibration.latestReport {
            return ("DAY 7 · FULL REPORT", "Your week, zone by zone.", report.summary.isEmpty ? summary : report.summary)
        }
        if count >= 5, calibration.isUnlocked(.rednessBaseline), let redness = calibration.rednessBaseline {
            var body = "Across five scans your redness was \(redness.label.lowercased())."
            if let steady = calibration.barrierSteady {
                body += steady ? " Your cheeks barely changed, so your barrier looks steady." : " Your cheeks changed from day to day, so your barrier looks less steady."
            }
            return ("DAY 5 · REDNESS BASELINE", redness == .steady ? "Your redness stays steady." : "Your redness comes and goes.", body)
        }
        if count >= 3, calibration.isUnlocked(.oilPattern), let oil = calibration.oilPattern {
            let title: String = switch oil {
            case .combination: "Shine sits on your T-zone."
            case .oily: "Shine shows all over."
            case .dry: "Your skin stays matte."
            case .normal, .unknown: "Your shine is balanced."
            }
            return ("DAY 3 · OIL PATTERN", title, "Across three scans your pattern reads as \(oil.label.lowercased()). \(summary)")
        }
        if count == 1 { return ("DAY 1 · FACE MAP", "Your first map is ready.", summary) }
        return ("DAY \(count) · DAILY READ", "Day \(count) of your week.", summary)
    }

    private var insightCard: some View {
        SKCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(insight.kicker).font(SKFont.label).tracking(1).foregroundStyle(SKColor.primary)
                Text(insight.body.isEmpty ? "No read for this day." : insight.body)
                    .font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Report

    private func reportCard(_ report: FaceReport) -> some View {
        SKCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR SKIN REPORT").font(SKFont.label).foregroundStyle(SKColor.muted)
                reportRow("Oil pattern", report.oilPattern.label)
                reportRow("Redness", report.redness.label)
                reportRow("Barrier", report.barrier.label)
                reportRow("Marks", report.marks.label)
                if let active = report.suggestedActive {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested active: \(active.name)").font(SKFont.sans(15, weight: .semibold, relativeTo: .body))
                        if let nights = active.nightsPerWeek { Text("\(nights) nights a week").font(SKFont.secondary).foregroundStyle(SKColor.muted) }
                        if !active.why.isEmpty { Text(active.why).font(SKFont.secondary).foregroundStyle(SKColor.muted) }
                    }
                    .foregroundStyle(SKColor.ink)
                }
            }
        }
    }

    private func reportRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.ink)
            Spacer()
            Text(value).font(SKFont.sans(15, weight: .medium, relativeTo: .body)).foregroundStyle(SKColor.ink)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Routine

    private func routineCard(_ routine: FaceRoutine) -> some View {
        let steps = routine.pm.isEmpty ? routine.am : routine.pm
        return SKCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(routine.pm.isEmpty ? "THIS MORNING" : "TONIGHT, FROM YOUR SHELF").font(SKFont.label).foregroundStyle(SKColor.muted)
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(SKFont.sans(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(SKColor.clayTileFg)
                            .frame(width: 24, height: 24)
                            .background(SKColor.clayTileBg, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.product.map { "\(step.step): \($0)" } ?? step.step)
                                .font(SKFont.sans(14, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                            if !step.note.isEmpty { Text(step.note).font(SKFont.caption).foregroundStyle(SKColor.muted) }
                        }
                    }
                }
                ForEach(routine.conflicts, id: \.self) { conflict in
                    Text(conflict).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.cautionFg)
                        .padding(.horizontal, SKSpace.md).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SKColor.cautionBg, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                }
            }
        }
    }

    // MARK: History

    private var historyCard: some View {
        SKCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("THIS WEEK'S SCANS").font(SKFont.label).foregroundStyle(SKColor.muted)
                if scans.isEmpty {
                    Text("No scans yet.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }
                ForEach(Array(scans.enumerated()), id: \.offset) { i, scan in
                    Button { selected = i } label: {
                        HStack {
                            Text("Day \(i + 1)").font(SKFont.sans(15, weight: .semibold, relativeTo: .body))
                            Text(Self.stageLabel(scan.stage)).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                            Spacer()
                            Text(scan.day).font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
                        }
                        .foregroundStyle(SKColor.ink)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(i == index ? .isSelected : [])
                }
            }
        }
    }

    static func stageLabel(_ stage: FaceScanStage) -> String {
        switch stage {
        case .baseline: "First sweep"
        case .daily: "Daily photo"
        case .final: "Final sweep"
        case .report: "Report"
        }
    }
}
