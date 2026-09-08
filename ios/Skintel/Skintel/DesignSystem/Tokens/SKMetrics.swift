import SwiftUI

enum SKSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 22   // page gutter in the 393pt frames
    static let xxl: CGFloat = 32
}

enum SKRadius {
    static let chip: CGFloat = 999
    static let tile: CGFloat = 12
    static let button: CGFloat = 14
    static let card: CGFloat = 16
    static let sheet: CGFloat = 28
}

enum SKAnimation {
    /// cubic-bezier(0.32, 0.72, 0, 1) — the design's iOS curve.
    static func ios(_ duration: Double = 0.45) -> Animation {
        .timingCurve(0.32, 0.72, 0, 1, duration: duration)
    }
    /// cubic-bezier(0.23, 1, 0.32, 1) — "emil", used for overshoot-free settles.
    static func emil(_ duration: Double = 0.5) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }
    static let press: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.15)
}

extension View {
    /// `0 1px 2px rgba(26,24,20,.04), 0 1px 3px rgba(26,24,20,.06)`
    func skCardShadow() -> some View {
        self.shadow(color: SKColor.ink.opacity(0.04), radius: 1, y: 1)
            .shadow(color: SKColor.ink.opacity(0.06), radius: 1.5, y: 1)
    }

    /// `0 4px 12px rgba(26,24,20,.06)`
    func skSoftShadow() -> some View {
        self.shadow(color: SKColor.ink.opacity(0.06), radius: 6, y: 4)
    }

    /// Primary button / FAB glow: `0 6px 16px rgba(163,88,72,.35)`
    func skPrimaryGlow(strength: Double = 0.35) -> some View {
        self.shadow(color: SKColor.primary.opacity(strength), radius: 8, y: 6)
    }

    /// Page gutter used by every screen.
    func skPagePadding() -> some View {
        self.padding(.horizontal, SKSpace.xl)
    }
}
