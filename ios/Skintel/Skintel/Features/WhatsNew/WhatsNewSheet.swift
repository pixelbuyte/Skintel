import SwiftUI

/// The one-time 2.0 sheet: Face scan is here. `HomeView` shows it once on Today after sign-in or
/// onboarding, never over another sheet or cover, and never to someone who already has a scan.
/// Cosmetic words only.
struct WhatsNewSheet: View {
    /// `@AppStorage` key, set the moment the sheet is shown so it only ever shows once.
    static let seenKey = "whatsNew.2.0.seen"

    let onScan: () -> Void
    let onLater: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.xl) {
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    FaceScanThumb(size: 88)
                    HStack(spacing: SKSpace.sm) {
                        Text("New in Skinstel").skLabelStyle()
                        SKNewBadge()
                    }
                    Text("Face scan is here")
                        .font(SKFont.pageTitle)
                        .foregroundStyle(SKColor.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    point(icon: "arrow.left.and.right", title: "A 15-second head turn",
                          detail: "Look ahead, then turn slowly left and right, phone at eye level.")
                    point(icon: "face.dashed", title: "A zone-by-zone map of your face",
                          detail: "Forehead, nose, cheeks and chin, each in plain words.")
                    point(icon: "calendar", title: "A 7-day check",
                          detail: "A quick photo each day shows what's changing.")
                }
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.xxl)
            .padding(.bottom, SKSpace.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: SKSpace.xs) {
                SKButton(title: "Scan my face", systemImage: "faceid", action: onScan)
                SKButton(title: "Later", kind: .ghost, action: onLater)
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.sm)
            .padding(.bottom, SKSpace.md)
            .background(SKColor.cream)
        }
        .background(SKColor.cream)
    }

    private func point(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: SKSpace.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SKColor.primary)
                .frame(width: 40, height: 40)
                .background(SKColor.blush, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                Text(detail)
                    .font(SKFont.secondary)
                    .foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
