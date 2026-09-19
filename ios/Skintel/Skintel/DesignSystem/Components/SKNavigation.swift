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

/// Circular native glass control with a warm opaque accessibility fallback.
struct SKGlassButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SKColor.ink)
                .frame(width: 44, height: 44)
                .skGlassControl(in: Circle())
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel(label)
    }
}

extension View {
    func skGlassControl<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(SKGlassControlSurface(shape: shape, interactive: interactive))
    }

    @ViewBuilder
    func skGlassGroup() -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) { self }
        } else {
            self
        }
    }
}

private struct SKGlassControlSurface<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular.tint(SKColor.cream.opacity(0.8)).interactive(interactive), in: shape)
        } else {
            content
                .background(SKColor.cream, in: shape)
                .overlay(shape.stroke(SKColor.line, lineWidth: 1))
                .shadow(color: SKColor.ink.opacity(0.06), radius: 12, y: 4)
        }
    }
}
