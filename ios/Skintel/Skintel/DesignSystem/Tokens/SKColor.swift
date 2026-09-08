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

    /// Scanner / camera surfaces.
    static let scannerBg = Color(hex: 0x0B0A08)
    static let scannerOverlay = Color.black.opacity(0.35)

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
