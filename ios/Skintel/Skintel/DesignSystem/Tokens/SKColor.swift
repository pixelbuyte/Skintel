import SwiftUI
import SkintelCore

/// Colour tokens from designs/skintel-ios-designs.html (mirrors tailwind.config.ts).
/// The design is light-only; `UIUserInterfaceStyle = Light` in Info.plist pins it.
enum SKColor {
    static let bg = Color(hex: 0xF4EDE0)
    static let cream = Color(hex: 0xFFFEFA)
    static let primary = Color(hex: 0xA35848)
    static let primaryPressed = Color(hex: 0x8E4538)
    static let ink = Color(hex: 0x1A1814)
    static let muted = Color(hex: 0x6B6760)
    static let line = Color(hex: 0xEAE6DF)
    static let neutralChip = Color(hex: 0xEFEAE2)
    static let blush = Color(hex: 0xA35848).opacity(0.08)

    static let goodBg = Color(hex: 0xEEF2DD)
    static let goodFg = Color(hex: 0x5C7A4F)
    static let badBg = Color(hex: 0xFDEAEA)
    static let badFg = Color(hex: 0xB22B2B)
    static let cautionBg = Color(hex: 0xFFF4E0)
    static let cautionFg = Color(hex: 0x8B6914)

    /// Scanner / camera surfaces. Every colour the camera screen uses lives here so the
    /// whole palette can be retuned from one place when the reference shot lands.
    /// Warm cream and peach on a warm-black scrim, rather than pure white on pure black.
    enum Scanner {
        /// Warm near-black behind the camera feed; a hair warmer than the old 0x0B0A08.
        static let ground = Color(hex: 0x120D0A)
        /// Top and bottom scrims. Warm brown-black so the cream chrome doesn't read cold.
        static let scrimTop = Color(hex: 0x120D0A).opacity(0.50)
        static let scrimBottom = Color(hex: 0x120D0A).opacity(0.62)
        /// Viewfinder brackets — warm cream, not pure white.
        static let bracket = Color(hex: 0xFFF4E8)
        /// The breathing scan line: peach core fading to nothing at both ends.
        static let scanCore = Color(hex: 0xF0A88C)
        static let scanGlow = Color(hex: 0xE08A6B)
        /// Caption pill behind the instruction text.
        static let captionBg = Color(hex: 0x120D0A).opacity(0.58)
        static let captionInk = Color(hex: 0xFFF4E8)
        /// "Type it" / "Photo of ingredients" pills.
        static let pillFill = Color(hex: 0xFFF4E8).opacity(0.15)
        static let pillStroke = Color(hex: 0xFFF4E8).opacity(0.28)
        static let pillInk = Color(hex: 0xFFF4E8)
    }

    /// Kept for anything still referring to the flat overlay.
    static let scannerBg = Scanner.ground
    static let scannerOverlay = Scanner.scrimTop

    /// Quiet placeholder while a product photo loads — never flashes the initial first.
    static let tileLoading = Color(hex: 0xEDE6DB)

    /// Pastel tiles behind product initials (design §07/§11). Deterministic per name.
    static let tilePalette: [(bg: Color, fg: Color)] = [
        (Color(hex: 0xD6E0EA), Color(hex: 0x3F5E7A)),   // blue
        (Color(hex: 0xE9DEC3), Color(hex: 0x7A6230)),   // gold
        (Color(hex: 0xEED2CC), Color(hex: 0x8E4538)),   // blush
        (Color(hex: 0xDCE5D2), Color(hex: 0x4E6B44)),   // sage
        (Color(hex: 0xE3DAE8), Color(hex: 0x5F4A73)),   // lilac
    ]

    static func tile(for name: String) -> (bg: Color, fg: Color) {
        let h = name.unicodeScalars.reduce(5381) { ($0 &<< 5) &+ $0 &+ Int($1.value) }
        return tilePalette[Int(h.magnitude % UInt(tilePalette.count))]
    }
}

/// Verdict tones used by chips, cards, rings and the journal dots.
enum SKTone: Sendable, Hashable {
    case good, caution, bad, neutral

    var fg: Color {
        switch self {
        case .good: SKColor.goodFg
        case .caution: SKColor.cautionFg
        case .bad: SKColor.badFg
        case .neutral: SKColor.muted
        }
    }

    var bg: Color {
        switch self {
        case .good: SKColor.goodBg
        case .caution: SKColor.cautionBg
        case .bad: SKColor.badBg
        case .neutral: SKColor.neutralChip
        }
    }
}

extension Outcome {
    var tone: SKTone {
        switch self {
        case .good: .good
        case .bad: .bad
        case .unsure: .caution
        }
    }

    /// Journal-style wording used on Home and product lists.
    var label: String {
        switch self {
        case .good: "Worked"
        case .bad: "Broke out"
        case .unsure: "Unsure"
        }
    }
}

extension ScanVerdict {
    var tone: SKTone {
        switch self {
        case .clean: .good
        case .caution: .caution
        case .avoid: .bad
        }
    }
}

extension JournalCondition {
    var tone: SKTone {
        switch self {
        case .clear: .good
        case .mild: .caution
        case .moderate: .caution
        case .breakout: .bad
        }
    }

    var label: String {
        switch self {
        case .clear: "Clear"
        case .mild: "Mild"
        case .moderate: "Moderate"
        case .breakout: "Broke out"
        }
    }

    var emoji: String {
        switch self {
        case .clear: "✨"
        case .mild: "🙂"
        case .moderate: "🤔"
        case .breakout: "🌋"
        }
    }
}

/// Score → tone thresholds, shared by rings and badges so a 64 is amber everywhere.
enum SKScore {
    static func tone(_ score: Int) -> SKTone {
        switch score {
        case 75...: .good
        case 50..<75: .caution
        default: .bad
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}
