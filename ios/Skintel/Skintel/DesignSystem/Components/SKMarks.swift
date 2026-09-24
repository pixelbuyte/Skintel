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

/// Where the chosen avatar look is kept (this device only).
enum SKAvatarLook {
    static let key = "profile.avatarLook"
}

/// A generated profile look: a skincare glyph on a soft tint, shuffled from You.
struct SKGeneratedAvatar: View {
    let look: Int
    var size: CGFloat = 64

    static var count: Int { looks.count }

    private static let looks: [(symbol: String, bg: Color, fg: Color)] = [
        ("sparkle", SKColor.primary, SKColor.cream),
        ("drop.fill", Color(hex: 0xDDE6D5), Color(hex: 0x5C7A4F)),
        ("moon.fill", Color(hex: 0xE6DDEA), Color(hex: 0x6E5A7E)),
        ("leaf.fill", Color(hex: 0xF1E4C8), Color(hex: 0x8A6A1F)),
        ("camera.macro", Color(hex: 0xF3DCD3), SKColor.primary),
        ("bubbles.and.sparkles.fill", Color(hex: 0xDCE4EA), Color(hex: 0x4F6878)),
    ]

    /// A different look from `current`, so every shuffle visibly changes.
    static func shuffled(from current: Int) -> Int {
        let now = ((current % count) + count) % count
        let next = Int.random(in: 0..<(count - 1))
        return next >= now ? next + 1 : next
    }

    var body: some View {
        let l = Self.looks[((look % Self.count) + Self.count) % Self.count]
        Image(systemName: l.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(l.fg)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: size, height: size)
            .background(l.bg, in: Circle())
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
