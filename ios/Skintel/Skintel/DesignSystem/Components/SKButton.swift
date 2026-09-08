import SwiftUI

enum SKButtonKind {
    case primary, secondary, ghost, dark, destructive
}

/// 52pt buttons from the spec (.btn-p / .btn-s / .btn-ghost), with a press scale on the
/// iOS curve and a built-in loading state so views never juggle a spinner themselves.
struct SKButton: View {
    let title: String
    var kind: SKButtonKind = .primary
    var systemImage: String? = nil
    var isLoading = false
    var fullWidth = true
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: SKSpace.sm) {
                if isLoading {
                    ProgressView().tint(foreground).controlSize(.small)
                } else {
                    if let systemImage { Image(systemName: systemImage).font(.system(size: 15, weight: .semibold)) }
                    Text(title)
                }
            }
            .font(kind == .ghost ? SKFont.secondary : SKFont.button)
            .foregroundStyle(foreground)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: kind == .ghost ? 40 : 52)
            .padding(.horizontal, fullWidth ? 0 : SKSpace.xl)
            .background(background, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous).stroke(SKColor.line, lineWidth: 1)
                }
            }
        }
        .buttonStyle(SKPressStyle())
        .disabled(isLoading)
        .opacity(isEnabled ? 1 : 0.5)
        .modifier(GlowIfPrimary(kind: kind, enabled: isEnabled))
        .accessibilityLabel(title)
        .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
    }

    private var foreground: Color {
        switch kind {
        case .primary, .dark: SKColor.cream
        case .secondary: SKColor.ink
        case .ghost: SKColor.muted
        case .destructive: SKColor.cream
        }
    }

    private var background: Color {
        switch kind {
        case .primary: SKColor.primary
        case .secondary: SKColor.cream
        case .ghost: .clear
        case .dark: SKColor.ink
        case .destructive: SKColor.badFg
        }
    }
}

private struct GlowIfPrimary: ViewModifier {
    let kind: SKButtonKind
    let enabled: Bool
    func body(content: Content) -> some View {
        if kind == .primary && enabled { content.skPrimaryGlow() } else { content }
    }
}

/// Scale-to-0.97 press feedback shared by every tappable card and chip.
struct SKPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(SKAnimation.press, value: configuration.isPressed)
    }
}

/// Inline text link ("Review ›", "Shelf ›", "Show all 24 ingredients ▾").
struct SKLinkButton: View {
    let title: String
    var chevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(title)
                if chevron { Text("›") }
            }
            .font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
            .foregroundStyle(SKColor.primary)
        }
        .buttonStyle(.plain)
    }
}
