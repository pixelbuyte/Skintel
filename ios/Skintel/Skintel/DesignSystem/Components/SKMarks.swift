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

/// The app mark used on splash and sign-in: terracotta squircle with the same sparkle
/// glyph as the real App Store icon (public/icons/skintel.svg), so the mark a user sees
/// on launch matches the one on their home screen instead of a leftover serif "S".
struct SKAppMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xB2634F), SKColor.primary, SKColor.primaryPressed],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            SparkleMark()
                .fill(SKColor.cream)
                .frame(width: size * 0.46, height: size * 0.46)
        }
        .frame(width: size, height: size)
        .skPrimaryGlow(strength: 0.3)
        .accessibilityLabel("Skintel")
    }
}

/// The four-point sparkle from the brand mark, traced from public/icons/skintel.svg's
/// star path (0..144 local space, normalized to a unit square here).
private struct SparkleMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + fx * w, y: rect.minY + fy * h)
        }
        var p = Path()
        p.move(to: pt(0.5, 0))
        p.addLine(to: pt(0.6111, 0.3889))
        p.addLine(to: pt(1, 0.5))
        p.addLine(to: pt(0.6111, 0.6111))
        p.addLine(to: pt(0.5, 1))
        p.addLine(to: pt(0.3889, 0.6111))
        p.addLine(to: pt(0, 0.5))
        p.addLine(to: pt(0.3889, 0.3889))
        p.closeSubpath()
        return p
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
