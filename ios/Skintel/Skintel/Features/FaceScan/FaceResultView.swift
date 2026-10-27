import ImageIO
import SkintelCore
import SwiftUI
import UIKit
import Vision

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
    /// The Day 1 front photo (JPEG, on this phone only). With it the hero opens on "You". It is
    /// deleted with the Day 1 crops when the report is written, so the report map opens on 3D.
    var photo: Data? = nil

    @State private var selected: Int?
    /// The hero toggle; nil until the person picks, so it follows whether a photo exists.
    @State private var show3D: Bool?

    private var showsPhoto: Bool { photo != nil && !(show3D ?? false) }

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

            if photo != nil {
                heroToggle
                    .padding(.horizontal, SKSpace.xl)
                    .padding(.top, SKSpace.md)
            }

            Group {
                if showsPhoto, let photo {
                    FacePhotoMap(photo: photo, levels: FaceZoneLevels(result: entry?.result), labels: labels)
                        .clipShape(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                        .padding(.horizontal, SKSpace.md)
                        .padding(.vertical, SKSpace.sm)
                } else {
                    FaceMeshView(mode: .result, levels: FaceZoneLevels(result: entry?.result), labels: labels, zoom: 0.31)
                }
            }
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

    /// "You · 3D": their own Day 1 photo with the zone glow, or the 3D model.
    private var heroToggle: some View {
        HStack(spacing: 0) {
            toggleButton("You", on: showsPhoto) { show3D = false }
            toggleButton("3D", on: !showsPhoto) { show3D = true }
        }
        .padding(3)
        .background(SKColor.bg.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map view")
    }

    private func toggleButton(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(SKAnimation.ios(0.3)) { action() }
            Haptics.selection()
        } label: {
            Text(title)
                .font(SKFont.sans(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(on ? SKColor.scannerBg : SKColor.bg.opacity(0.8))
                .frame(minWidth: 64, minHeight: 32)
                .background(on ? SKColor.bg : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
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
                    Text("Is your skin getting calmer?")
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

/// Where the face and its zone centres sit in the Day 1 photo, in Vision's normalised image
/// space (0...1, origin bottom-left).
struct FacePhotoLayout: Sendable, Equatable {
    var face: CGRect
    var centres: [FaceZone: CGPoint]

    /// Zone centres in the face box's unit space when Vision finds no landmarks: the centres of
    /// the crop rectangles the sweep cuts (`SweepCamera.zoneRects`). The photo is unmirrored, so
    /// the person's right cheek is on the image's left.
    static let fallbackCentres: [FaceZone: CGPoint] = [
        .forehead: CGPoint(x: 0.5, y: 0.97), .nose: CGPoint(x: 0.5, y: 0.52),
        .rightCheek: CGPoint(x: 0.21, y: 0.41), .leftCheek: CGPoint(x: 0.79, y: 0.41),
        .chin: CGPoint(x: 0.5, y: 0.07),
    ]

    /// Runs face landmarks once on the photo. Off the main actor; nil when no face is found.
    static func locate(_ jpeg: Data) -> FacePhotoLayout? {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let face = (request.results ?? []).max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return nil }
        let box = face.boundingBox
        let unit = unitCentres(face.landmarks)
        var centres: [FaceZone: CGPoint] = [:]
        for (zone, p) in unit {
            centres[zone] = CGPoint(x: box.minX + p.x * box.width, y: box.minY + p.y * box.height)
        }
        return FacePhotoLayout(face: box, centres: centres)
    }

    /// Zone centres in face-box unit space from the landmarks, falling back per zone.
    private static func unitCentres(_ landmarks: VNFaceLandmarks2D?) -> [FaceZone: CGPoint] {
        var out = fallbackCentres
        guard let landmarks else { return out }
        func centroid(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let points = region?.normalizedPoints, !points.isEmpty else { return nil }
            let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
        }
        let eyes = [centroid(landmarks.leftEye), centroid(landmarks.rightEye)].compactMap { $0 }.sorted { $0.x < $1.x }
        let brows = [centroid(landmarks.leftEyebrow), centroid(landmarks.rightEyebrow)].compactMap { $0 }
        let nose = centroid(landmarks.nose)
        let mouth = centroid(landmarks.outerLips)
        if let nose { out[.nose] = nose }
        if eyes.count == 2 {
            let midX = (eyes[0].x + eyes[1].x) / 2
            let eyeY = (eyes[0].y + eyes[1].y) / 2
            let browY = brows.isEmpty ? eyeY + 0.1 : brows.map(\.y).reduce(0, +) / CGFloat(brows.count)
            out[.forehead] = CGPoint(x: midX, y: min(browY + 0.16, 1.05))
            let cheekY = nose.map { $0.y - 0.04 } ?? eyeY - 0.2
            // Image-left is the person's right cheek (unmirrored photo).
            out[.rightCheek] = CGPoint(x: eyes[0].x - 0.03, y: cheekY)
            out[.leftCheek] = CGPoint(x: eyes[1].x + 0.03, y: cheekY)
        }
        if let mouth { out[.chin] = CGPoint(x: mouth.x, y: max(mouth.y - 0.16, -0.04)) }
        return out
    }
}

/// The person's own Day 1 photo with the zone glow and labels drawn on it ("You" on the map).
/// Same level-to-intensity mapping and words as the 3D map; the photo never leaves the phone.
struct FacePhotoMap: View {
    let photo: Data
    var levels = FaceZoneLevels(levels: [:])
    var labels: [FaceMeshLabel] = []

    @State private var image: UIImage?
    @State private var layout: FacePhotoLayout?

    var body: some View {
        Canvas { context, size in
            guard let image else { return }
            draw(image, in: &context, size: size)
        }
        .background(SKColor.scannerBg)
        .task(id: photo) {
            image = UIImage(data: photo)
            let data = photo
            layout = await Task.detached(priority: .userInitiated) { FacePhotoLayout.locate(data) }.value
        }
        .accessibilityElement()
        .accessibilityLabel("Your Day 1 photo with zones highlighted")
        .accessibilityAddTraits(.isImage)
    }

    private func draw(_ image: UIImage, in context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let iw = image.size.width, ih = image.size.height
        guard w > 0, h > 0, iw > 0, ih > 0 else { return }
        let face = layout?.face ?? CGRect(x: 0.25, y: 0.3, width: 0.5, height: 0.4)
        let centres = layout?.centres ?? FacePhotoLayout.fallbackCentres.mapValues {
            CGPoint(x: face.minX + $0.x * face.width, y: face.minY + $0.y * face.height)
        }

        // Fill the frame, zoomed so the face takes a bit over half the height, kept centred.
        let fill = max(w / iw, h / ih)
        let s = max(fill, min(0.56 * h / max(face.height * ih, 1), fill * 3))
        let cx = face.midX * iw, cy = (1 - face.midY) * ih
        let x0 = min(0, max(w - iw * s, w / 2 - cx * s))
        let y0 = min(0, max(h - ih * s, h * 0.5 - cy * s))
        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: x0 + p.x * iw * s, y: y0 + (1 - p.y) * ih * s) }

        context.draw(Image(uiImage: image), in: CGRect(x: x0, y: y0, width: iw * s, height: ih * s))
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SKColor.scannerBg.opacity(0.18)))

        let faceW = face.width * iw * s
        for zone in FaceZone.allCases {
            let l = Double(levels.level(zone)) / 2
            guard l > 0, let c = centres[zone] else { continue }
            let centre = point(c)
            let rad = faceW * (zone == .forehead ? 0.42 : 0.27)
            let gradient = Gradient(colors: [SKColor.primary.opacity(0.55 * l), SKColor.primary.opacity(0)])
            context.fill(Path(ellipseIn: CGRect(x: centre.x - rad, y: centre.y - rad, width: rad * 2, height: rad * 2)),
                         with: .radialGradient(gradient, center: centre, startRadius: 0, endRadius: rad))
        }

        var text = context
        text.addFilter(.shadow(color: SKColor.scannerBg.opacity(0.85), radius: 3))
        for label in labels {
            guard let c = centres[label.zone] else { continue }
            let anchorPoint = point(c)
            let ax = anchorPoint.x, ay = anchorPoint.y
            let leading = label.side == .leading
            let lx = leading ? 16.0 : w - 16
            let ly = h * label.y
            let ex = leading ? min(ax - 14, lx + 96) : max(ax + 14, lx - 96)
            var leader = Path()
            leader.move(to: CGPoint(x: ax, y: ay))
            leader.addLine(to: CGPoint(x: ex, y: ly))
            leader.addLine(to: CGPoint(x: leading ? lx + 82 : lx - 82, y: ly))
            text.stroke(leader, with: .color(SKColor.bg.opacity(0.7)), lineWidth: 0.8)
            text.fill(Path(ellipseIn: CGRect(x: ax - 2.6, y: ay - 2.6, width: 5.2, height: 5.2)), with: .color(SKColor.bg))
            let anchor: UnitPoint = leading ? .leading : .trailing
            text.draw(Text(label.title).font(SKFont.label).foregroundStyle(SKColor.bg),
                      at: CGPoint(x: lx, y: ly - 9), anchor: anchor)
            text.draw(Text(label.value).font(SKFont.label)
                        .foregroundStyle(label.hot ? FaceScanColor.hot : SKColor.bg.opacity(0.85)),
                      at: CGPoint(x: lx, y: ly + 7), anchor: anchor)
        }
    }
}
