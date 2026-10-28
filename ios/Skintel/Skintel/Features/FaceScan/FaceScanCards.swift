import SkintelCore
import SwiftUI
import UIKit

/// The NEW tag on Face scan: shown everywhere the feature is offered for 14 days from the first
/// launch that has it, so it is seen even by someone who opened the feature once already.
enum FaceScanNew {
    static let key = "faceScan.newUntil"
    static let days: Double = 14

    /// Starts the 14 days on first call; true until they pass.
    static func isActive(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        let until = defaults.double(forKey: key)
        if until == 0 {
            defaults.set(now.timeIntervalSince1970 + days * 86_400, forKey: key)
            return true
        }
        return now.timeIntervalSince1970 < until
    }
}

/// Opens the face scan from anywhere below the tab bar (Today's card, You's card). Set by
/// `MainTabView`, which owns the full-screen cover.
struct OpenFaceScanAction {
    let handler: @MainActor () -> Void
    @MainActor func callAsFunction() { handler() }
}

private struct OpenFaceScanKey: EnvironmentKey {
    static let defaultValue = OpenFaceScanAction { }
}

extension EnvironmentValues {
    var openFaceScan: OpenFaceScanAction {
        get { self[OpenFaceScanKey.self] }
        set { self[OpenFaceScanKey.self] = newValue }
    }
}

/// The face scan thumbnail: their Day 1 photo, mirrored, with the mesh and glow (as on the map),
/// or the 3D face before there is a photo.
struct FaceScanThumb: View {
    var photo: Data?
    var levels = FaceZoneLevels(levels: [:])
    var zoom: CGFloat = 0.4

    var body: some View {
        Group {
            if let photo {
                FacePhotoMap(photo: photo, levels: levels)
            } else {
                FaceMeshView(mode: .result, levels: levels, zoom: zoom, palette: .light)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum FaceScanDates {
    /// "TUE 27 OCT" from a stored `YYYY-MM-DD` day, or "" when it can't be read.
    static func short(_ day: String) -> String {
        let parse = DateFormatter()
        parse.calendar = Calendar(identifier: .gregorian)
        parse.locale = Locale(identifier: "en_US_POSIX")
        parse.dateFormat = "yyyy-MM-dd"
        guard let date = parse.date(from: day) else { return "" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_GB")
        out.dateFormat = "EEE d MMM"
        return out.string(from: date)
    }
}

/// Where the face map lives on Today (Face Scan Pro v2 "Today"): before the first scan, the
/// invitation with the 3D face; after it, the photo, the day of the week and the 7 dots.
struct FaceMapCard: View {
    @Environment(\.openFaceScan) private var openFaceScan
    @State private var store = FaceScanStore.shared
    @State private var showsNew = FaceScanNew.isActive()

    private var latest: FaceScanEntry? { store.hasCycle ? store.calibration.scans.last : nil }

    var body: some View {
        Button { openFaceScan() } label: {
            Group {
                if let latest { mapCard(latest) } else { inviteCard }
            }
            .background(SKColor.cream)
            .clipShape(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
            .skCardShadow()
            .contentShape(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(latest == nil ? "Starts a face scan" : "Opens your face map")
    }

    private var kicker: some View {
        HStack(spacing: SKSpace.sm) {
            Text("FACE SCAN").font(SKFont.label).tracking(1.4).foregroundStyle(SKColor.primary)
            if showsNew { SKNewBadge() }
        }
    }

    private var inviteCard: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                kicker
                Text("See your skin zone by zone.").font(SKFont.serif(26, relativeTo: .title2)).foregroundStyle(SKColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A 15-second head turn and a few questions. Your first map is free.")
                    .font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text("Scan my face")
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                }
                .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.primary)
                .frame(minHeight: 44)
            }
            .padding(.leading, 18).padding(.top, 18).padding(.bottom, SKSpace.sm)
            Spacer(minLength: SKSpace.sm)
            FaceScanThumb(levels: FaceZoneLevels(levels: [.nose: 1]))
                .frame(width: 118)
                .frame(maxHeight: .infinity)
                .background(SKColor.primary.opacity(0.06))
        }
        .frame(minHeight: 190)
    }

    private func mapCard(_ latest: FaceScanEntry) -> some View {
        let cal = store.calibration
        let count = cal.scans.count
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                FaceScanThumb(photo: store.day1Front, levels: FaceZoneLevels(result: latest.result), zoom: 0.42)
                    .frame(width: 112, height: 156)
                    .clipped()
                VStack(alignment: .leading, spacing: 6) {
                    kicker
                    Text(title(latest)).font(SKFont.serif(26, relativeTo: .title2)).foregroundStyle(SKColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(status).font(SKFont.label).tracking(1.2).foregroundStyle(SKColor.clayTileFg)
                    let summary = latest.result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !summary.isEmpty {
                        Text(summary).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.leading, 6).padding(.trailing, SKSpace.lg).padding(.top, SKSpace.lg).padding(.bottom, 14)
                Spacer(minLength: 0)
            }
            .background(SKColor.primary.opacity(0.06))
            HStack(spacing: SKSpace.md) {
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        if i < count {
                            Circle().fill(i == count - 1 ? SKColor.cream : SKColor.primary)
                                .overlay(Circle().stroke(SKColor.primary, lineWidth: 2))
                                .frame(width: 14, height: 14)
                        } else {
                            Circle().stroke(SKColor.muted, style: StrokeStyle(lineWidth: 1.4, dash: [2, 2]))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Day \(count) of 7 done")
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Text("See your map")
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                }
                .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.primary)
            }
            .padding(.leading, SKSpace.lg).padding(.trailing, SKSpace.md)
            .frame(minHeight: 48)
            .overlay(alignment: .top) { Rectangle().fill(SKColor.line).frame(height: 1) }
        }
    }

    private func title(_ latest: FaceScanEntry) -> String {
        if latest.stage == .report { return "Your skin report is ready" }
        return store.calibration.scans.count <= 1 ? "Your first map is ready" : "Day \(store.calibration.scans.count) map is ready"
    }

    /// "DAY 1 OF 7 · NEXT PHOTO TOMORROW".
    private var status: String {
        let cal = store.calibration
        if cal.latestReport != nil { return "WEEK DONE · START A NEW ONE ANY TIME" }
        let day = "DAY \(max(cal.scans.count, 1)) OF 7"
        return cal.scannedToday(now: Date()) ? "\(day) · NEXT PHOTO TOMORROW" : "\(day) · TODAY'S PHOTO IS READY"
    }
}

/// "YOUR FACE SCANS" on You: the latest map with its photo, the report and the Day 1 map. Before
/// the first scan it shows the same invitation as Today.
struct FaceScansSection: View {
    @Environment(\.openFaceScan) private var openFaceScan
    @State private var store = FaceScanStore.shared
    @State private var showsNew = FaceScanNew.isActive()

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            HStack(spacing: SKSpace.sm) {
                Text("YOUR FACE SCANS").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.muted)
                if showsNew { SKNewBadge() }
            }
            .padding(.leading, SKSpace.xs)
            if store.hasCycle, let latest = store.calibration.scans.last {
                scansCard(latest)
                Text("Maps and Day 1 photos stay on this phone. Delete them in Settings.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted)
                    .padding(.horizontal, SKSpace.xs)
            } else {
                FaceMapCard()
            }
        }
    }

    private func scansCard(_ latest: FaceScanEntry) -> some View {
        let cal = store.calibration
        let first = cal.scans.first
        return VStack(spacing: 0) {
            Button { openFaceScan() } label: {
                HStack(alignment: .top, spacing: 0) {
                    FaceScanThumb(photo: store.day1Front, levels: FaceZoneLevels(result: latest.result), zoom: 0.42)
                        .frame(width: 112, height: 148)
                        .clipped()
                    VStack(alignment: .leading, spacing: 5) {
                        Text("LATEST · \(FaceScanDates.short(latest.day).uppercased())")
                            .font(SKFont.label).tracking(1.2).foregroundStyle(SKColor.primary)
                        Text("This week's map").font(SKFont.serif(24, relativeTo: .title2)).foregroundStyle(SKColor.ink)
                        Text(statusLine).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 4) {
                            Text("Open map")
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                        }
                        .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.primary)
                        .padding(.top, 2)
                    }
                    .padding(.leading, SKSpace.xs).padding(.trailing, 14).padding(.top, SKSpace.lg).padding(.bottom, 14)
                    Spacer(minLength: 0)
                }
                .background(SKColor.primary.opacity(0.06))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens your face map")
            if cal.latestReport != nil {
                row(title: "Your skin report", detail: "Day 7 · zone by zone")
            }
            if let first, cal.scans.count > 1 {
                row(title: "Day 1 map · \(FaceScanDates.short(first.day))",
                    detail: "\(FaceResultView.stageLabel(first.stage)) · \(first.result.zones.count) zones read")
            }
        }
        .background(SKColor.cream)
        .clipShape(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
        .skCardShadow()
    }

    private func row(title: String, detail: String) -> some View {
        Button { openFaceScan() } label: {
            HStack(spacing: SKSpace.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                    Text(detail).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
            }
            .padding(.leading, SKSpace.lg).padding(.trailing, 14)
            .frame(minHeight: 64)
            .overlay(alignment: .top) { Rectangle().fill(SKColor.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var statusLine: String {
        let cal = store.calibration
        if cal.latestReport != nil { return "Week done · your report is ready" }
        let day = "Day \(max(cal.scans.count, 1)) of 7"
        return cal.scannedToday(now: Date()) ? "\(day) · next photo tomorrow" : "\(day) · today's photo is ready"
    }
}

/// "Face scan is here" (Face Scan Pro v2 "What's New"): once, on Today, the first launch with the
/// feature. Scan my face opens the scan; Later (or a swipe) just closes.
struct FaceScanWhatsNewSheet: View {
    static let seenKey = "faceScan.whatsNewSeen"

    let onScan: () -> Void
    let onLater: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NEW IN SKINSTEL 2.0").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.primary)
                        Text("Face scan is here").font(SKFont.serif(38, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("See your skin zone by zone, then follow it for a week.")
                            .font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, SKSpace.sm)
                    Spacer(minLength: 0)
                    FaceScanThumb(levels: FaceZoneLevels(levels: [.nose: 1, .forehead: 1]), zoom: 0.42)
                        .frame(width: 104, height: 136)
                        .background(SKColor.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
                }
                VStack(spacing: 0) {
                    feature("viewfinder", "Your photo and a 3D map, in one view", "Mirrored like a selfie, with each zone in plain words.")
                    feature("sparkles", "Suggestions for your goals", "Say what you want to improve. Ask Skinstel about the scan any time.")
                    feature("checkmark.circle", "Your first scan is free", "Following your face for 7 days is part of Skintel+.", last: true)
                }
                .overlay(alignment: .top) { Rectangle().fill(SKColor.line).frame(height: 1) }
                SKButton(title: "Scan my face", action: onScan)
                Button(action: onLater) {
                    Text("Later")
                        .font(SKFont.sans(16, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous).stroke(SKColor.line))
                        .contentShape(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
                }
                .buttonStyle(SKPressStyle())
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.lg)
            .padding(.bottom, SKSpace.xxl)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SKColor.cream)
        .presentationCornerRadius(SKRadius.sheet)
    }

    private func feature(_ icon: String, _ title: String, _ detail: String, last: Bool = false) -> some View {
        HStack(alignment: .top, spacing: SKSpace.md) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(SKColor.primary)
                .frame(width: 36, height: 36)
                .background(SKColor.blush, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(SKFont.sans(16, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                Text(detail).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, SKSpace.md)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(SKColor.line).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Face scan" on Insights (Face Scan Pro v2 "Insights"): one row per zone, one bar per scan of
/// the week against Day 1. Missed days stay empty; dashed columns fill in as they scan. Shown
/// once there is a scan.
struct FaceScanInsightsCard: View {
    @Environment(\.openFaceScan) private var openFaceScan
    @State private var store = FaceScanStore.shared
    @State private var showsNew = FaceScanNew.isActive()
    @State private var asking = false

    private static let zones: [FaceZone] = [.forehead, .nose, .leftCheek, .rightCheek, .chin]

    var body: some View {
        let scans = store.hasCycle ? store.calibration.scans : []
        if !scans.isEmpty {
            card(scans)
                .skAskSheet(isPresented: $asking, initialQuestion: "What changed on my face this week?", faceTagged: true)
        }
    }

    private func level(_ scan: FaceScanEntry, _ zone: FaceZone) -> Int? {
        guard let z = scan.result.zone(zone), let top = z.scores.values.max() else { return nil }
        return FaceZoneLevels.level(for: FaceCalibration.band(top))
    }

    private func card(_ scans: [FaceScanEntry]) -> some View {
        let n = min(scans.count, 7)
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: SKSpace.sm) {
                    Text("Face scan").font(SKFont.section).foregroundStyle(SKColor.ink)
                    if showsNew { SKNewBadge() }
                    Spacer(minLength: 0)
                    Text(n == 1 ? "Day 1 baseline" : "\(n) of 7 scans")
                        .font(SKFont.label).foregroundStyle(SKColor.muted)
                }
                Text(n == 1 ? "One scan so far, so this is your starting point. Each morning photo adds a column."
                            : "Each column is one morning photo, compared with Day 1. Missed days stay empty, never filled in.")
                    .font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: 112)
                    HStack(spacing: 4) {
                        ForEach(1...7, id: \.self) { d in
                            Text("\(d)").font(SKFont.mono(10)).foregroundStyle(d <= n ? SKColor.ink : SKColor.muted)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Color.clear.frame(width: 70)
                }
                .accessibilityHidden(true)
                ForEach(Self.zones) { zone in zoneRow(zone, scans: Array(scans.prefix(7))) }
            }
            Text(n == 1 ? "Trends start with tomorrow's photo. Dashed columns fill in as you scan."
                        : "A cosmetic read of your photos. Patterns, not proof.")
                .font(SKFont.caption).foregroundStyle(SKColor.muted)
            HStack(spacing: SKSpace.sm) {
                SKButton(title: "Open your map", kind: .secondary) { openFaceScan() }
                SKButton(title: "Ask about it", kind: .secondary, systemImage: "sparkles") { asking = true }
            }
        }
        .padding(SKSpace.lg)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
        .skCardShadow()
    }

    private func zoneRow(_ zone: FaceZone, scans: [FaceScanEntry]) -> some View {
        let levels = scans.map { level($0, zone) }
        let first = levels.first.flatMap { $0 } ?? 0
        let last = levels.last.flatMap { $0 } ?? 0
        let base = scans.count == 1
        let word = base ? (first == 0 ? "Clear" : ["None", "Some", "Noticeable"][first])
                        : last < first ? "Calmer" : last > first ? "More" : "Same"
        let color = base ? (first == 0 ? SKColor.goodFg : SKColor.clayTileFg)
                         : last < first ? SKColor.goodFg : last > first ? SKColor.cautionFg : SKColor.muted
        let kind: String = {
            guard let z = scans.last?.result.zone(zone), let top = z.scores.max(by: { $0.value < $1.value }),
                  FaceCalibration.band(top.value) != .clear else { return "All five reads" }
            return top.key.label
        }()
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(zone.label).font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                Text(kind).font(SKFont.caption).foregroundStyle(SKColor.muted).lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Group {
                        if i < levels.count {
                            let v = levels[i] ?? 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(v == 0 ? SKColor.ink.opacity(0.16) : SKColor.primary)
                                .frame(height: v == 2 ? 22 : v == 1 ? 12 : 3)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(SKColor.ink.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                .frame(height: 22)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 24, alignment: .bottom)
            Text(word).font(SKFont.sans(13, weight: .semibold, relativeTo: .footnote)).foregroundStyle(color)
                .frame(width: 70, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(zone.label): \(base ? "Day 1 baseline, \(word.lowercased())" : "\(word) than Day 1")")
    }
}
