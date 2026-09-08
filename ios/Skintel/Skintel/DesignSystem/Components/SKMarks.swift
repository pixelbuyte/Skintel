import SwiftUI

/// Rounded-square initial tile behind product names (design §07/§09/§11).
struct SKProductMark: View {
    let name: String
    var size: CGFloat = 48

    var body: some View {
        let t = SKColor.tile(for: name)
        Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(SKFont.sans(size * 0.42, weight: .semibold, relativeTo: .title2))
            .foregroundStyle(t.fg)
            .frame(width: size, height: size)
            .background(t.bg, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Circular avatar with initial (home greeting, settings).
struct SKAvatar: View {
    let name: String?
    var size: CGFloat = 44

    var body: some View {
        Text(String((name ?? "S").trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(SKFont.sans(size * 0.4, weight: .semibold, relativeTo: .title3))
            .foregroundStyle(SKColor.cream)
            .frame(width: size, height: size)
            .background(SKColor.primary, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The app mark used on splash and sign-in: terracotta squircle with a serif S and the
/// hairline "shelf" across it (matches designs/app-icon.svg).
struct SKAppMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xB2634F), SKColor.primary, SKColor.primaryPressed],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Rectangle()
                .fill(SKColor.cream.opacity(0.45))
                .frame(height: max(1, size * 0.02))
            Text("S")
                .font(SKFont.serif(size * 0.62, relativeTo: .largeTitle))
                .foregroundStyle(SKColor.cream)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .skPrimaryGlow(strength: 0.3)
        .accessibilityLabel("Skintel")
    }
}

/// Coloured status dot used in INCI rows and the journal week strip.
struct SKDot: View {
    let tone: SKTone
    var size: CGFloat = 8
    var body: some View {
        Circle().fill(tone == .neutral ? SKColor.line : tone.fg).frame(width: size, height: size)
    }
}
