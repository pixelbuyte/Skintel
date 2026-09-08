import SwiftUI

/// `.chip` — 999 radius, 12pt semibold, toned.
struct SKChip: View {
    let text: String
    var tone: SKTone = .neutral
    var dot = false

    init(_ text: String, tone: SKTone = .neutral, dot: Bool = false) {
        self.text = text; self.tone = tone; self.dot = dot
    }

    var body: some View {
        HStack(spacing: 5) {
            if dot { Circle().fill(tone.fg).frame(width: 6, height: 6) }
            Text(text)
        }
        .font(SKFont.chip)
        .foregroundStyle(tone.fg)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(tone.bg, in: Capsule())
    }
}

/// Score badge ("82") — serif number on a tone pill (home list, routine rows).
struct SKScoreBadge: View {
    let score: Int
    var body: some View {
        Text("\(score)")
            .font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
            .foregroundStyle(SKScore.tone(score).fg)
            .frame(minWidth: 44)
            .padding(.vertical, 8)
            .background(SKScore.tone(score).bg, in: Capsule())
            .accessibilityLabel("Score \(score) of 100")
    }
}

/// Single-select chip from onboarding §04: filled terracotta with ✓ when selected.
struct SKSelectChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if selected { Text("✓") }
            }
            .font(SKFont.sans(16, weight: selected ? .semibold : .medium, relativeTo: .body))
            .foregroundStyle(selected ? SKColor.cream : SKColor.ink)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(selected ? SKColor.primary : SKColor.neutralChip, in: Capsule())
        }
        .buttonStyle(SKPressStyle())
        .animation(SKAnimation.ios(0.25), value: selected)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Multi-select card from onboarding §04: 1.5pt terracotta border on blush when selected.
struct SKSelectCard: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(SKFont.sans(16, weight: .medium, relativeTo: .body))
                    .foregroundStyle(SKColor.ink)
                Spacer()
                if selected {
                    Text("✓").font(SKFont.sans(15, weight: .semibold)).foregroundStyle(SKColor.primary)
                }
            }
            .padding(.horizontal, SKSpace.lg)
            .frame(height: 56)
            .background(selected ? SKColor.blush : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                    .stroke(selected ? SKColor.primary : SKColor.line, lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(SKPressStyle())
        .animation(SKAnimation.ios(0.25), value: selected)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Segmented pill ("AM | PM", "Ingredients · 24 | AI insight").
struct SKSegmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    withAnimation(SKAnimation.ios(0.3)) { selection = value }
                } label: {
                    Text(label)
                        .font(SKFont.sans(15, weight: selection == value ? .semibold : .medium, relativeTo: .subheadline))
                        .foregroundStyle(selection == value ? SKColor.ink : SKColor.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if selection == value {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(SKColor.cream)
                                    .skCardShadow()
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(SKColor.neutralChip, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
