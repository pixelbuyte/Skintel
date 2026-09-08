import SwiftUI

/// `.card` from the spec: cream, 1px line, 16pt radius, the two-layer hairline shadow.
struct SKCard<Content: View>: View {
    var padding: CGFloat = SKSpace.lg
    var tint: SKTone? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
            .skCardShadow()
    }

    private var background: some ShapeStyle {
        if let tint {
            return AnyShapeStyle(LinearGradient(colors: [tint.bg, SKColor.cream], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(SKColor.cream)
    }

    private var border: Color {
        if let tint { return tint.fg.opacity(0.25) }
        return SKColor.line
    }
}

/// Dashed "add" affordance (design §13 "+ Add step from shelf").
struct SKDashedButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SKFont.bodyMedium)
                .foregroundStyle(SKColor.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay {
                    RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                        .foregroundStyle(SKColor.line)
                }
        }
        .buttonStyle(SKPressStyle())
    }
}

/// Row inside a list card with a hairline divider (product INCI rows, settings rows).
struct SKRow<Leading: View, Trailing: View>: View {
    var showDivider = true
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: SKSpace.md) {
                leading()
                Spacer(minLength: SKSpace.sm)
                trailing()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, SKSpace.lg)
            if showDivider {
                Rectangle().fill(SKColor.line).frame(height: 1).padding(.leading, SKSpace.lg)
            }
        }
    }
}
