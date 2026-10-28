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

/// Where the face map lives outside the scan: the latest read in one card (Today and You), or
/// an invitation before the first scan. Tapping opens the scan, which opens on the map.
struct FaceMapCard: View {
    @Environment(\.openFaceScan) private var openFaceScan
    @State private var store = FaceScanStore.shared
    @State private var showsNew = FaceScanNew.isActive()

    private var latest: FaceScanEntry? { store.hasCycle ? store.calibration.scans.last : nil }

    var body: some View {
        Button { openFaceScan() } label: {
            HStack(spacing: SKSpace.md) {
                thumbnail
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: SKSpace.sm) {
                        if showsNew { SKNewBadge() }
                        Text(kicker).font(SKFont.label).tracking(1).foregroundStyle(SKColor.primary)
                    }
                    Text(title).font(SKFont.sans(16, weight: .semibold, relativeTo: .headline)).foregroundStyle(SKColor.ink)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Text(subtitle).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Text(latest == nil ? "Scan my face ›" : "Open my map ›")
                        .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.primary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(SKSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(SKColor.line))
            .skCardShadow()
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(latest == nil ? "Starts a face scan" : "Opens your face map")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photo = store.day1Front, let image = UIImage(data: photo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(x: -1, y: 1)
                .frame(width: 64, height: 82)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(SKColor.line))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "face.dashed")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(SKColor.primary)
                .frame(width: 64, height: 82)
                .background(SKColor.blush, in: Capsule())
                .accessibilityHidden(true)
        }
    }

    private var kicker: String {
        guard let latest else { return "FACE SCAN" }
        if latest.stage == .report { return "YOUR SKIN REPORT" }
        return "YOUR FACE MAP · DAY \(store.calibration.scans.count) OF 7"
    }

    private var title: String {
        guard let latest else { return "See your skin, zone by zone" }
        let summary = latest.result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if summary.isEmpty { return "Your map is ready" }
        let first = summary.split(separator: ".", maxSplits: 1).first.map(String.init) ?? summary
        return first.trimmingCharacters(in: .whitespaces) + "."
    }

    private var subtitle: String {
        guard latest != nil else { return "Three angles, about 20 seconds. Your map and tips follow." }
        let cal = store.calibration
        if cal.latestReport != nil { return "Your week is done. Start a new one any time." }
        if cal.scannedToday(now: Date()) { return "Today is counted. Next photo tomorrow." }
        let left = cal.scansToGo(for: .fullReport)
        return left > 0 ? "Today's photo is ready to take. \(left) to go for your report." : "Ready for today's photo."
    }
}

/// The first time Face scan opens: what it is and how it goes, before any consent or camera.
struct FaceScanIntroSheet: View {
    let onStart: () -> Void
    let onLater: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                HStack(spacing: SKSpace.sm) {
                    SKNewBadge()
                    Text("FACE SCAN").font(SKFont.mono(12)).tracking(1.5).foregroundStyle(SKColor.muted)
                }
                FaceMeshView(mode: .result, levels: FaceZoneLevels(levels: [.nose: 1]), zoom: 0.36, palette: .light)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(SKColor.bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Text("See your skin, zone by zone.")
                    .font(SKFont.serif(34, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    step(1, "Turn your head, three ways", "About 20 seconds. The camera tells you when the light is right.")
                    step(2, "Tell us what you want to improve", "Tap ready answers, skip anything. Your read starts meanwhile.")
                    step(3, "Get your face map and tips", "On your own face, with what to try first. Ask Skinstel about it any time.")
                }
                Text("A cosmetic read, not a diagnosis. Your photo stays on this phone.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted)
                VStack(spacing: SKSpace.xs) {
                    SKButton(title: "Start my face scan") { onStart() }
                    SKButton(title: "Later", kind: .ghost) { onLater() }
                }
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.xl)
            .padding(.bottom, SKSpace.lg)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SKColor.cream)
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: SKSpace.md) {
            Text("\(n)").font(SKFont.sans(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(SKColor.clayTileFg)
                .frame(width: 26, height: 26)
                .background(SKColor.clayTileBg, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                Text(detail).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
