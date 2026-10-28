import ImageIO
import SkintelCore
import SwiftUI
import UIKit
import Vision

/// The face scan result (Face Scan Pro v2 "Main"): a cream hero with the map (their own Day 1
/// photo, mirrored, or the 3D face, picked with Photo/3D), zone by zone with all five reads, what
/// Skinstel suggests, a row per goal with a ready Ask question, tonight's routine, the 7-day check
/// and Ask. Levels are words and glyphs, never raw scores (PRO-SPEC §6).
///
/// With `onUnlock` (no Skintel+, e.g. the free scan's real Day 1 map), the week is locked: the
/// 7-day check becomes the Skintel+ card, and the routine, the scan actions and Ask stay hidden.
struct FaceResultView: View {
    let calibration: FaceCalibration
    let routine: FaceRoutine?
    /// The scan action to offer today ("Take today's photo", "Final sweep"), or nil.
    let nextAction: String?
    let onNext: () -> Void
    /// Opens Ask with the scan tagged, with a ready question (nil: the general one).
    let onAsk: ((String?) -> Void)?
    let onClose: () -> Void
    /// Not Skintel+ only: opens the Skintel+ wall from the locked 7-day check.
    var onUnlock: (() -> Void)? = nil
    /// The Day 1 front photo (JPEG, on this phone only), shown mirrored with the mesh over it. It
    /// is deleted with the Day 1 crops when the report is written, so the report map is 3D only.
    var photo: Data? = nil
    /// What they want to improve, from the questions: one row each under "For your goals".
    var goals: [String] = []
    /// "Anything you want to know?" picks: the "You asked" rows.
    var asked: [String] = []
    /// Products on their shelf, for "A simpler routine".
    var shelfCount: Int = 0
    /// Back to the questions, from "For your goals · Edit".
    var onEditGoals: (() -> Void)? = nil

    private enum MapView: Hashable { case photo, mesh }

    @State private var selected: Int?
    @State private var mapView: MapView = .photo
    @State private var openZone: FaceZone?

    private var showsPhoto: Bool { photo != nil && mapView == .photo }

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
                    zonesSection
                    if let tips = entry?.result.tips, !tips.isEmpty { suggestsCard(tips) }
                    if !goalRows.isEmpty { goalsCard }
                    if let report = calibration.latestReport?.report { reportCard(report) }
                    if !isFree, let routine, !(routine.pm.isEmpty && routine.am.isEmpty) { routineCard(routine) }
                    if let onUnlock { lockedWeekCard(unlock: onUnlock) } else { weekCard }
                    if scans.count > 1 { historyCard }
                    if !isFree, let nextAction { SKButton(title: nextAction, kind: onAsk == nil ? .primary : .secondary, systemImage: "faceid") { onNext() } }
                    if let onAsk { askButton { onAsk(nil) } }
                    Text("\(FaceScanResult.defaultDisclaimer) Photos are read, then deleted; your Day 1 photo stays on this phone.")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .skPagePadding()
                .padding(.top, 18)
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
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                Spacer()
                HStack(spacing: SKSpace.sm) {
                    Text("FACE SCAN").font(SKFont.mono(12)).tracking(1.5)
                    if FaceScanNew.isActive() { SKNewBadge() }
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.leading, SKSpace.sm).padding(.trailing, 14)

            VStack(alignment: .leading, spacing: SKSpace.xs) {
                Text("YOUR SKIN MAP · DAY \(index + 1) OF 7").font(SKFont.label).tracking(1.5).foregroundStyle(SKColor.primary)
                Text(insight.title).font(SKFont.serif(34, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if !insight.body.isEmpty {
                    Text(insight.body).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.md)

            HStack(spacing: SKSpace.md) {
                if photo != nil {
                    HStack(spacing: 0) {
                        viewButton("Photo", .photo)
                        viewButton("3D", .mesh)
                    }
                    .padding(3)
                    .background(SKColor.neutralChip, in: Capsule())
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Map view")
                }
                Spacer(minLength: 0)
                if showsPhoto {
                    Label("Mirrored, like a selfie", systemImage: "arrow.left.and.right")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                }
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, 14)

            ZStack(alignment: .top) {
                Group {
                    if showsPhoto, let photo {
                        FacePhotoMap(photo: photo, levels: FaceZoneLevels(result: entry?.result))
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .padding(.horizontal, SKSpace.xl)
                            .padding(.top, 40)
                            .padding(.bottom, SKSpace.sm)
                    } else {
                        FaceMeshView(mode: .result, levels: FaceZoneLevels(result: entry?.result), zoom: 0.33, palette: .light)
                    }
                }
                .frame(height: 340)
                HStack {
                    Text(showsPhoto ? "YOUR PHOTO · ON THIS PHONE" : "3D · DRAG TO TURN")
                        .font(SKFont.label).tracking(1).foregroundStyle(SKColor.clayTileFg)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(SKColor.cream, in: Capsule())
                        .overlay(Capsule().stroke(SKColor.line))
                    Spacer()
                    Text("YOUR RIGHT ›").font(SKFont.label).tracking(1).foregroundStyle(SKColor.muted)
                }
                .padding(.horizontal, SKSpace.xl)
                .padding(.top, SKSpace.sm)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: SKLayout.readableWidth)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)

            HStack(spacing: 6) {
                Circle().fill(SKColor.primary.opacity(0.22)).frame(width: 14, height: 14)
                Text("Glow means more showing")
            }
            .font(SKFont.caption).foregroundStyle(SKColor.muted)
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.xs)
            .accessibilityElement(children: .combine)
        }
        .padding(.top, 54)
        .padding(.bottom, SKSpace.lg)
        .foregroundStyle(SKColor.ink)
        .background(SKColor.primary.opacity(0.06))
        .background(SKColor.cream)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
        .overlay(alignment: .bottom) {
            UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous)
                .stroke(SKColor.line, lineWidth: 1)
        }
    }

    private func viewButton(_ title: String, _ view: MapView) -> some View {
        let on = mapView == view
        return Button {
            withAnimation(SKAnimation.ios(0.25)) { mapView = view }
            Haptics.selection()
        } label: {
            Text(title)
                .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(on ? SKColor.ink : SKColor.muted)
                .padding(.horizontal, 14)
                .frame(minWidth: 74, minHeight: 44)
                .background {
                    if on {
                        Capsule().fill(SKColor.cream)
                            .shadow(color: SKColor.ink.opacity(0.08), radius: 1, y: 1)
                            .shadow(color: SKColor.ink.opacity(0.08), radius: 1.5, y: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Zone by zone

    /// The display order from the design.
    private static let zoneOrder: [FaceZone] = [.forehead, .nose, .leftCheek, .rightCheek, .chin]

    /// The zone's strongest metric in this scan, and its band.
    private func top(_ zone: FaceZone, in result: FaceScanResult?) -> (metric: FaceMetric, band: FaceCalibration.Band)? {
        guard let z = result?.zone(zone), let best = z.scores.max(by: { $0.value < $1.value }) else { return nil }
        return (best.key, FaceCalibration.band(best.value))
    }

    private var zonesSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("ZONE BY ZONE").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.muted)
                Spacer()
                Text("Tap a zone for all five reads").font(SKFont.caption).foregroundStyle(SKColor.muted)
            }
            .padding(.horizontal, 2)
            VStack(spacing: 0) {
                ForEach(Array(Self.zoneOrder.enumerated()), id: \.element) { i, zone in
                    zoneRow(zone)
                    if i < Self.zoneOrder.count - 1 { Rectangle().fill(SKColor.line).frame(height: 1) }
                }
            }
            .padding(.horizontal, SKSpace.lg).padding(.vertical, 2)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
            .skCardShadow()
        }
    }

    private func zoneRow(_ zone: FaceZone) -> some View {
        let result = entry?.result
        let t = top(zone, in: result)
        let level = t.map { FaceZoneLevels.level(for: $0.band) } ?? 0
        let open = openZone == zone
        let note = result?.zone(zone)?.note ?? defaultNote(t)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(SKAnimation.ios(0.3)) { openZone = open ? nil : zone }
                Haptics.selection()
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text(zone.label).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                            Spacer(minLength: 0)
                            toneChip(t, level: level)
                        }
                        Text(note).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(SKColor.muted)
                        .padding(.top, 6)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, SKSpace.md)
                .frame(minHeight: 72)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(open ? "Hides the five reads" : "Shows all five reads")
            if open {
                VStack(spacing: 9) {
                    ForEach(FaceMetric.allCases) { metric in
                        metricBar(metric, score: result?.score(metric, in: zone))
                    }
                }
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
    }

    private func defaultNote(_ t: (metric: FaceMetric, band: FaceCalibration.Band)?) -> String {
        guard let t else { return "Not read in this photo." }
        if t.band == .clear { return "Even tone. Nothing stands out." }
        return "\(t.metric.label) reads \(t.band.label.lowercased())."
    }

    @ViewBuilder
    private func toneChip(_ t: (metric: FaceMetric, band: FaceCalibration.Band)?, level: Int) -> some View {
        let fg = level == 0 ? SKColor.goodFg : level == 1 ? SKColor.cautionFg : SKColor.clayTileFg
        let bg = level == 0 ? SKColor.goodBg : level == 1 ? SKColor.cautionBg : SKColor.clayTileBg
        HStack(spacing: 6) {
            if level == 0 {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy))
            } else {
                HStack(spacing: 2) {
                    Circle().fill(fg).frame(width: 6, height: 6)
                    Circle().fill(level == 2 ? fg : .clear).frame(width: 5, height: 5)
                        .overlay(Circle().stroke(fg, lineWidth: 1.2))
                }
            }
            Text(t == nil ? "Not read" : level == 0 ? "Clear" : "\(t!.metric.label) · \(t!.band.label)")
                .font(SKFont.sans(13, weight: .semibold, relativeTo: .footnote))
                .lineLimit(1)
        }
        .foregroundStyle(fg)
        .padding(.leading, 8).padding(.trailing, 10)
        .frame(height: 28)
        .background(bg, in: Capsule())
        .fixedSize()
    }

    private func metricBar(_ metric: FaceMetric, score: Int?) -> some View {
        let level = score.map { FaceZoneLevels.level(for: FaceCalibration.band($0)) } ?? 0
        let word = score.map { FaceCalibration.band($0).label } ?? "Not read"
        return HStack(spacing: 10) {
            Text(metric.label).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.ink)
                .frame(width: 116, alignment: .leading)
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 3).fill(level >= 1 ? SKColor.primary : SKColor.line).frame(height: 8)
                RoundedRectangle(cornerRadius: 3).fill(level >= 2 ? SKColor.primary : SKColor.line).frame(height: 8)
            }
            .accessibilityHidden(true)
            Text(word).font(SKFont.sans(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(level == 0 ? SKColor.muted : SKColor.ink)
                .frame(width: 82, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Suggests

    private func suggestsCard(_ tips: [FaceTip]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WHAT SKINSTEL SUGGESTS").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.primary)
                Spacer()
                Text("From this scan").font(SKFont.caption).foregroundStyle(SKColor.muted)
            }
            ForEach(Array(tips.enumerated()), id: \.offset) { i, tip in
                VStack(spacing: 12) {
                    Rectangle().fill(SKColor.line).frame(height: 1)
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)").font(SKFont.mono(12))
                            .foregroundStyle(SKColor.clayTileFg)
                            .frame(width: 28, height: 28)
                            .background(SKColor.clayTileBg, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tip.title).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                            if !tip.why.isEmpty {
                                Text(tip.why).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Text("Ideas to try, not a treatment plan.").font(SKFont.caption).foregroundStyle(SKColor.muted)
        }
        .modifier(FaceCardStyle())
    }

    // MARK: For your goals

    private struct GoalRow: Hashable { let title: String; let hint: String; let question: String }

    /// Where a metric shows most in this scan, as "Nose & T-zone · Some", or nil when clear everywhere.
    private func whereShows(_ metric: FaceMetric) -> String? {
        guard let result = entry?.result else { return nil }
        let best = Self.zoneOrder.compactMap { zone in result.score(metric, in: zone).map { (zone, $0) } }
            .max { $0.1 < $1.1 }
        guard let best else { return nil }
        let band = FaceCalibration.band(best.1)
        return band == .clear ? nil : "\(best.0.label) · \(band.label)"
    }

    private var goalRows: [GoalRow] {
        var rows: [GoalRow] = []
        for goal in goals {
            let metric: FaceMetric?
            let question: String
            switch goal {
            case "Less shine": metric = .shine; question = "How do I get less shine?"
            case "Fewer breakouts": metric = .raisedBlemishes; question = "How do I get fewer breakouts?"
            case "Fade marks": metric = .flatMarks; question = "How do I fade my marks?"
            case "Calmer redness": metric = .redness; question = "How do I calm the redness?"
            case "Smoother texture": metric = .texture; question = "How do I get smoother texture?"
            case "Smaller-looking pores": metric = .texture; question = "How do I make my pores look smaller?"
            case "More glow": metric = nil; question = "How do I get more glow?"
            case "A simpler routine": metric = nil; question = "Which steps can I drop?"
            default: continue
            }
            let hint: String
            if goal == "A simpler routine" {
                hint = shelfCount == 1 ? "1 product on your shelf" : "\(shelfCount) products on your shelf"
            } else if let metric {
                hint = whereShows(metric) ?? "Clear in this scan"
            } else {
                hint = "Across your face"
            }
            rows.append(GoalRow(title: goal, hint: hint, question: question))
        }
        for question in asked {
            rows.append(GoalRow(title: "You asked", hint: "From your answers", question: question))
        }
        return rows
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("FOR YOUR GOALS").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.muted)
                Spacer()
                if let onEditGoals {
                    Button("Edit", action: onEditGoals)
                        .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(SKColor.primary)
                        .frame(minHeight: 44)
                }
            }
            .frame(minHeight: 44)
            ForEach(goalRows, id: \.self) { row in
                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.title).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                        Spacer(minLength: 0)
                        Text(row.hint).font(SKFont.caption).foregroundStyle(SKColor.muted)
                    }
                    .accessibilityElement(children: .combine)
                    if let onAsk, !isFree {
                        Button { onAsk(row.question) } label: {
                            Label(row.question, systemImage: "sparkle")
                                .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                                .foregroundStyle(SKColor.primaryPressed)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(SKColor.primary.opacity(0.06), in: Capsule())
                                .overlay(Capsule().stroke(SKColor.line))
                        }
                        .buttonStyle(SKPressStyle())
                        .accessibilityHint("Asks Skinstel with your scan tagged")
                    }
                }
                .padding(.vertical, SKSpace.md)
                .overlay(alignment: .top) { Rectangle().fill(SKColor.line).frame(height: 1) }
            }
        }
        .padding(.horizontal, SKSpace.lg).padding(.top, SKSpace.sm).padding(.bottom, SKSpace.xs)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
        .skCardShadow()
    }

    // MARK: 7-day check

    private struct Ring { let milestone: FaceCalibration.Milestone; let color: Color; let radius: CGFloat }

    private var rings: [Ring] {
        [Ring(milestone: .faceMap, color: SKColor.clayTileFg, radius: 58),
         Ring(milestone: .oilPattern, color: SKColor.primary, radius: 46),
         Ring(milestone: .rednessBaseline, color: SKColor.primary.opacity(0.55), radius: 34),
         Ring(milestone: .fullReport, color: SKColor.goodFg, radius: 22)]
    }

    private func ringStatus(_ m: FaceCalibration.Milestone) -> String {
        if calibration.isUnlocked(m) { return "READY" }
        let left = calibration.scansToGo(for: m)
        if left == 0 { return m.requiresFinalScan ? "FINAL SWEEP" : "FIRST SWEEP" }
        return left == 1 ? "1 SCAN" : "\(left) SCANS"
    }

    private var weekFooter: String {
        let day = scans.count
        if calibration.latestReport != nil { return "Your week is done. Start a new one any time." }
        if calibration.scannedToday(now: Date()) {
            return "Day \(max(day, 1)) of 7 · next photo tomorrow, inside your skin check-in."
        }
        return "Day \(max(day, 1)) of 7 · today's photo is ready to take."
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("7-DAY CHECK").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.muted)
            HStack(spacing: SKSpace.lg) {
                ZStack {
                    ForEach(rings, id: \.radius) { ring in
                        Circle().stroke(SKColor.neutralChip, lineWidth: 10)
                            .frame(width: ring.radius * 2, height: ring.radius * 2)
                        Circle().trim(from: 0, to: CGFloat(calibration.isUnlocked(ring.milestone) ? 1 : min(calibration.progress(for: ring.milestone), 0.999)))
                            .stroke(ring.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: ring.radius * 2, height: ring.radius * 2)
                    }
                }
                .frame(width: 128, height: 128)
                .accessibilityElement()
                .accessibilityLabel(rings.map { "\($0.milestone.label) \(ringStatus($0.milestone).lowercased())" }.joined(separator: ", "))
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(rings, id: \.radius) { ring in
                        let ready = calibration.isUnlocked(ring.milestone)
                        HStack(spacing: SKSpace.sm) {
                            RoundedRectangle(cornerRadius: 3).fill(ring.color).frame(width: 10, height: 10)
                            Text(ring.milestone.label).font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                            Spacer(minLength: 0)
                            HStack(spacing: 3) {
                                if ready { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)) }
                                Text(ringStatus(ring.milestone)).font(SKFont.label)
                            }
                            .foregroundStyle(ready ? SKColor.goodFg : SKColor.muted)
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            Text(weekFooter).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                .padding(.top, SKSpace.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(SKColor.line).frame(height: 1) }
        }
        .modifier(FaceCardStyle())
    }

    /// The free scan's 7-day check: what the week answers, and the way into Skintel+.
    private func lockedWeekCard(unlock: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            Text("7-DAY CHECK").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.primary)
            Text("Is your skin getting calmer?").font(SKFont.serif(26, relativeTo: .title2)).foregroundStyle(SKColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Follow it for 7 days with Skintel+. One photo can't show change; a 10-second photo each morning can.")
                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                ForEach(["Day 3 · your oil pattern", "Day 5 · redness and barrier", "Day 7 · full report and a routine from your shelf"], id: \.self) { line in
                    HStack(spacing: SKSpace.sm) {
                        Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(SKColor.primary)
                            .accessibilityHidden(true)
                        Text(line).font(SKFont.sans(14, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                    }
                }
            }
            SKButton(title: "Get Skintel+", action: unlock)
        }
        .modifier(FaceCardStyle())
    }

    // MARK: Ask

    private func askButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Ask Skinstel about this scan", systemImage: "sparkles")
                .font(SKFont.button)
                .foregroundStyle(SKColor.cream)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(SKColor.primary, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
                .shadow(color: SKColor.primary.opacity(0.35), radius: 8, y: 6)
        }
        .buttonStyle(SKPressStyle())
    }

    // MARK: Insight

    private var insight: (title: String, body: String) {
        let count = index + 1
        let summary = entry?.result.summary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if count >= 7, calibration.isUnlocked(.fullReport), let report = calibration.latestReport {
            return ("Your week, zone by zone.", report.summary.isEmpty ? summary : report.summary)
        }
        if count >= 5, calibration.isUnlocked(.rednessBaseline), let redness = calibration.rednessBaseline {
            var body = "Across five scans your redness was \(redness.label.lowercased())."
            if let steady = calibration.barrierSteady {
                body += steady ? " Your cheeks barely changed, so your barrier looks steady." : " Your cheeks changed from day to day, so your barrier looks less steady."
            }
            return (redness == .steady ? "Your redness stays steady." : "Your redness comes and goes.", body)
        }
        if count >= 3, calibration.isUnlocked(.oilPattern), let oil = calibration.oilPattern {
            let title: String = switch oil {
            case .combination: "Shine sits on your T-zone."
            case .oily: "Shine shows all over."
            case .dry: "Your skin stays matte."
            case .normal, .unknown: "Your shine is balanced."
            }
            return (title, "Across three scans your pattern reads as \(oil.label.lowercased()). \(summary)")
        }
        if count == 1 { return ("Your first map is ready.", summary) }
        return ("Day \(count) of your week.", summary)
    }

    // MARK: Report

    private func reportCard(_ report: FaceReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR SKIN REPORT").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.muted)
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
        .modifier(FaceCardStyle())
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
        return VStack(alignment: .leading, spacing: 10) {
            Text(routine.pm.isEmpty ? "THIS MORNING, FROM YOUR SHELF" : "TONIGHT, FROM YOUR SHELF")
                .font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.muted)
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
                    .padding(.top, 3)
                }
            }
            ForEach(routine.conflicts, id: \.self) { conflict in
                HStack(alignment: .top, spacing: SKSpace.sm) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 13, weight: .semibold))
                        .padding(.top, 1)
                        .accessibilityHidden(true)
                    (Text("Clash: ").fontWeight(.semibold) + Text(conflict))
                        .font(SKFont.sans(13, relativeTo: .footnote))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(SKColor.cautionFg)
                .padding(.horizontal, SKSpace.md).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SKColor.cautionBg, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
            }
        }
        .modifier(FaceCardStyle())
    }

    // MARK: History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THIS WEEK'S SCANS").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.muted)
            ForEach(Array(scans.enumerated()), id: \.offset) { i, scan in
                Button { selected = i; Haptics.selection() } label: {
                    HStack {
                        Text("Day \(i + 1)").font(SKFont.sans(15, weight: .semibold, relativeTo: .body))
                        Text(Self.stageLabel(scan.stage)).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        Spacer()
                        if i == index { Text("SHOWING").font(SKFont.label).foregroundStyle(SKColor.primary) }
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
        .modifier(FaceCardStyle())
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

/// The result's cards: cream, a hairline border, 16 pt corners and the card shadow.
private struct FaceCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(SKSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
            .skCardShadow()
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

/// The person's own Day 1 photo, mirrored like a selfie, with the 3D face mesh laid over it, the
/// zone glow and the labels: one view, so the 3D map and their face are the same picture. Same
/// level-to-intensity mapping and words as the 3D map; the photo never leaves the phone.
struct FacePhotoMap: View {
    let photo: Data
    var levels = FaceZoneLevels(levels: [:])
    var labels: [FaceMeshLabel] = []
    /// Mirrored like the front camera's preview (how people see themselves).
    var mirrored = true

    @State private var image: UIImage?
    @State private var layout: FacePhotoLayout?

    var body: some View {
        Canvas { context, size in
            guard let image else { return }
            draw(image, in: &context, size: size)
        }
        .background(SKColor.neutralChip)
        .task(id: photo) {
            image = UIImage(data: photo)
            let data = photo
            layout = await Task.detached(priority: .userInitiated) { FacePhotoLayout.locate(data) }.value
        }
        .accessibilityElement()
        .accessibilityLabel("Your Day 1 photo with the 3D map and zones highlighted")
        .accessibilityAddTraits(.isImage)
    }

    /// Normalised image x seen through the mirror.
    private func flip(_ p: CGPoint) -> CGPoint { mirrored ? CGPoint(x: 1 - p.x, y: p.y) : p }

    private func draw(_ image: UIImage, in context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let iw = image.size.width, ih = image.size.height
        guard w > 0, h > 0, iw > 0, ih > 0 else { return }
        let rawFace = layout?.face ?? CGRect(x: 0.25, y: 0.3, width: 0.5, height: 0.4)
        let face = mirrored ? CGRect(x: 1 - rawFace.maxX, y: rawFace.minY, width: rawFace.width, height: rawFace.height) : rawFace
        let rawCentres = layout?.centres ?? FacePhotoLayout.fallbackCentres.mapValues {
            CGPoint(x: rawFace.minX + $0.x * rawFace.width, y: rawFace.minY + $0.y * rawFace.height)
        }
        let centres = rawCentres.mapValues { flip($0) }

        // Fill the frame, zoomed so the face takes a bit over half the height, kept centred.
        let fill = max(w / iw, h / ih)
        let s = max(fill, min(0.56 * h / max(face.height * ih, 1), fill * 3))
        let cx = face.midX * iw, cy = (1 - face.midY) * ih
        let x0 = min(0, max(w - iw * s, w / 2 - cx * s))
        let y0 = min(0, max(h - ih * s, h * 0.5 - cy * s))
        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: x0 + p.x * iw * s, y: y0 + (1 - p.y) * ih * s) }

        let rect = CGRect(x: x0, y: y0, width: iw * s, height: ih * s)
        var photoLayer = context
        if mirrored {
            photoLayer.translateBy(x: rect.midX, y: 0)
            photoLayer.scaleBy(x: -1, y: 1)
            photoLayer.translateBy(x: -rect.midX, y: 0)
        }
        photoLayer.draw(Image(uiImage: image), in: rect)

        drawMesh(over: face, in: &context, point: point)

        let faceW = face.width * iw * s
        for zone in FaceZone.allCases {
            let l = Double(levels.level(zone)) / 2
            guard l > 0, let c = centres[zone] else { continue }
            let centre = point(c)
            let rad = faceW * (zone == .forehead ? 0.42 : 0.27)
            let gradient = Gradient(colors: [SKColor.primary.opacity(0.5 * l), SKColor.primary.opacity(0)])
            context.fill(Path(ellipseIn: CGRect(x: centre.x - rad, y: centre.y - rad, width: rad * 2, height: rad * 2)),
                         with: .radialGradient(gradient, center: centre, startRadius: 0, endRadius: rad))
        }

        for label in labels {
            guard let c = centres[label.zone] else { continue }
            let anchorPoint = point(c)
            let ax = anchorPoint.x, ay = anchorPoint.y
            let leading = label.side == .leading
            let title = context.resolve(Text(label.title).font(SKFont.label).foregroundStyle(SKColor.ink))
            let value = context.resolve(Text(label.value).font(SKFont.label)
                .foregroundStyle(label.hot ? SKColor.primary : SKColor.goodFg))
            let tSize = title.measure(in: CGSize(width: 160, height: 40))
            let vSize = value.measure(in: CGSize(width: 160, height: 40))
            let boxW = max(tSize.width, vSize.width) + 16
            let boxH = tSize.height + vSize.height + 10
            let ly = h * label.y
            let bx = leading ? 12 : w - 12 - boxW
            let box = CGRect(x: bx, y: ly - boxH / 2, width: boxW, height: boxH)
            var leader = Path()
            leader.move(to: CGPoint(x: ax, y: ay))
            leader.addLine(to: CGPoint(x: leading ? box.maxX : box.minX, y: ly))
            context.stroke(leader, with: .color(SKColor.cream.opacity(0.85)), lineWidth: 1)
            context.fill(Path(ellipseIn: CGRect(x: ax - 3, y: ay - 3, width: 6, height: 6)), with: .color(SKColor.cream))
            let shape = Path(roundedRect: box, cornerRadius: 9)
            context.fill(shape, with: .color(SKColor.cream.opacity(0.93)))
            if label.hot { context.stroke(shape, with: .color(SKColor.primary), lineWidth: 1) }
            context.draw(title, at: CGPoint(x: box.minX + 8, y: box.minY + 5), anchor: .topLeading)
            context.draw(value, at: CGPoint(x: box.minX + 8, y: box.minY + 5 + tSize.height), anchor: .topLeading)
        }
    }

    /// The canonical face mesh's front half, fitted to the face box (a bit taller, since Vision's
    /// box stops at the brows), as a fine cream wireframe: the 3D map on their own face.
    private func drawMesh(over face: CGRect, in context: inout GraphicsContext, point: (CGPoint) -> CGPoint) {
        guard let mesh = FaceMeshData.shared else { return }
        let P = mesh.positions, F = mesh.faces
        var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        for i in 0..<mesh.vertexCount {
            minX = min(minX, P[i * 3]); maxX = max(maxX, P[i * 3])
            minY = min(minY, P[i * 3 + 1]); maxY = max(maxY, P[i * 3 + 1])
        }
        let mw = Double(max(maxX - minX, 0.001)), mh = Double(max(maxY - minY, 0.001))
        let midX = Double(minX + maxX) / 2, midY = Double(minY + maxY) / 2
        let width = Double(face.width) * 1.02, height = Double(face.height) * 1.38
        let centreX = Double(face.midX), centreY = Double(face.midY) + Double(face.height) * 0.1
        func project(_ i: Int) -> CGPoint {
            let x = Double(P[i * 3]) * (mirrored ? -1 : 1)
            let y = Double(P[i * 3 + 1])
            return point(CGPoint(x: centreX + (x - (mirrored ? -midX : midX)) / mw * width,
                                 y: centreY + (y - midY) / mh * height))
        }
        var wire = Path()
        var k = 0
        while k + 2 < F.count {
            let a = F[k], b = F[k + 1], c = F[k + 2]
            k += 3
            // The front half only: the back of the head would draw over the face.
            guard P[a * 3 + 2] > -0.1, P[b * 3 + 2] > -0.1, P[c * 3 + 2] > -0.1 else { continue }
            let pa = project(a), pb = project(b), pc = project(c)
            wire.move(to: pa)
            wire.addLine(to: pb)
            wire.addLine(to: pc)
            wire.closeSubpath()
        }
        context.stroke(wire, with: .color(SKColor.cream.opacity(0.28)), lineWidth: 0.5)
    }
}
