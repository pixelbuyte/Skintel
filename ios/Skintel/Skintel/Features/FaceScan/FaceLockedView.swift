import SwiftUI
import SkintelCore

/// The free scan's result (canvas `Paywall.dc.html`): the person's map with the zones that have
/// findings softly lit and labelled LOCKED, and a sheet that opens the app's Skintel+ wall.
/// A locked result carries only those zones, with no scores, so nothing here is invented.
struct FaceLockedView: View {
    let result: FaceScanResult
    let onUnlock: () -> Void
    let onClose: () -> Void

    private static let sides: [FaceZone: (side: FaceMeshLabel.Side, y: CGFloat)] = [
        .forehead: (.leading, 0.2), .nose: (.trailing, 0.4), .rightCheek: (.leading, 0.58),
        .leftCheek: (.trailing, 0.66), .chin: (.leading, 0.86),
    ]

    private var zones: [FaceZone] { FaceZone.allCases.filter { result.zone($0) != nil } }

    private var levels: FaceZoneLevels {
        FaceZoneLevels(levels: Dictionary(uniqueKeysWithValues: zones.map { ($0, 2) }))
    }

    private var labels: [FaceMeshLabel] {
        zones.compactMap { zone in
            guard let s = Self.sides[zone] else { return nil }
            return FaceMeshLabel(zone: zone, title: zone.label.uppercased(), value: "LOCKED", side: s.side, y: s.y, hot: true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
                Spacer()
                Text(zones.count == 1 ? "1 AREA FOUND" : "\(zones.count) AREAS FOUND")
                    .font(SKFont.label).tracking(1.5).foregroundStyle(FaceScanColor.hot)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, SKSpace.sm)
            .padding(.top, SKSpace.md)
            .foregroundStyle(SKColor.bg)

            FaceMeshView(mode: .result, levels: levels, labels: labels, zoom: 0.32)
                .frame(maxWidth: SKLayout.readableWidth, minHeight: 240, maxHeight: 300)

            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    Text("Your face map is ready.").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("See what each area shows, follow it for 7 days and get a routine built from your shelf.")
                        .font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.muted)
                    feature("3D face map, zone by zone")
                    feature("7-day check: oil, redness, what's changing")
                    feature("A routine that skips your Triggers")
                    SKButton(title: "Get Skintel+", action: onUnlock).padding(.top, SKSpace.sm)
                    Text(FaceScanResult.defaultDisclaimer).font(SKFont.caption).foregroundStyle(SKColor.muted)
                        .frame(maxWidth: .infinity)
                }
                .skPagePadding()
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
            .background(SKColor.cream, in: UnevenRoundedRectangle(topLeadingRadius: SKRadius.sheet, topTrailingRadius: SKRadius.sheet))
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SKColor.scannerBg.ignoresSafeArea())
    }

    private func feature(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(SKColor.primary)
                .accessibilityHidden(true)
            Text(text).font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.ink)
        }
    }
}

/// Face scan is 13 and over (COPPA). Asked when onboarding gave no age or "Under 18".
struct FaceAgeGateView: View {
    let tooYoung: Bool
    let onAnswer: (Bool) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.ink).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
            }
            if tooYoung {
                Text("Face scan is for people 13 and over.").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Everything else in Skintel is still here for you.")
                    .font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.muted)
                Spacer()
                SKButton(title: "Close", action: onClose)
            } else {
                Text("Are you 13 or older?").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Face scan reads photos of your face, so it is for people 13 and over.")
                    .font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.muted)
                Spacer()
                SKButton(title: "Yes") { onAnswer(true) }
                SKButton(title: "No", kind: .secondary) { onAnswer(false) }
            }
        }
        .skPagePadding()
        .padding(.vertical, SKSpace.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .skPageBackground()
    }
}
