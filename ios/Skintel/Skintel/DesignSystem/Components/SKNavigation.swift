import SwiftUI

extension View {
    /// Inline nav title in DM Sans semibold (the spec's "Analysis" / "Product" bars).
    func skNavigationTitle(_ title: String) -> some View {
        self.navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(SKFont.navTitle).foregroundStyle(SKColor.ink)
                }
            }
    }

    /// Cream page background with the warm radial wash from src/index.css.
    func skPageBackground() -> some View {
        self.background {
            ZStack {
                SKColor.bg
                RadialGradient(colors: [Color(hex: 0xF7E3D6).opacity(0.55), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Color(hex: 0xE4E9EA).opacity(0.5), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 380)
            }
            .ignoresSafeArea()
        }
    }
}

/// Section heading row: serif title + optional trailing link ("Recent scans   Shelf ›").
struct SKSectionHeader: View {
    let title: String
    var linkTitle: String? = nil
    var linkAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(SKFont.section).foregroundStyle(SKColor.ink)
            Spacer()
            if let linkTitle, let linkAction {
                SKLinkButton(title: linkTitle, action: linkAction)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Circular glass button for dark surfaces (scanner close / torch).
struct SKGlassButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(SKPressStyle(scale: 0.92))
        .accessibilityLabel(label)
    }
}
