import SwiftUI

/// Type tokens. Instrument Serif for display, DM Sans for UI, JetBrains Mono for data
/// (INCI names, barcodes, confidence, section labels). Every style is registered
/// `relativeTo` a text style so Dynamic Type scales it.
enum SKFont {
    static let serifName = "InstrumentSerif-Regular"
    static let serifItalicName = "InstrumentSerif-Italic"
    static let monoName = "JetBrainsMono-Regular"
    static let monoBoldName = "JetBrainsMono-Bold"

    static func sansName(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: "DMSans-Bold"
        case .semibold: "DMSans-SemiBold"
        case .medium: "DMSans-Medium"
        default: "DMSans-Regular"
        }
    }

    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title, italic: Bool = false) -> Font {
        .custom(italic ? serifItalicName : serifName, size: size, relativeTo: style)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(sansName(weight), size: size, relativeTo: style)
    }

    static func mono(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .footnote) -> Font {
        .custom(bold ? monoBoldName : monoName, size: size, relativeTo: style)
    }

    // Semantic scale, sized from the 393pt design frames.
    static let hero = serif(40, relativeTo: .largeTitle)          // "Tell us about your skin."
    static let greeting = serif(34, relativeTo: .largeTitle)      // "Good morning, Riya"
    static let pageTitle = serif(34, relativeTo: .largeTitle)     // "Routine", "Journal"
    static let section = serif(24, relativeTo: .title2)           // "Recent scans"
    static let stat = serif(28, relativeTo: .title)               // 128 / 62 / 41
    static let score = serif(44, relativeTo: .largeTitle)         // ring number
    static let price = serif(56, relativeTo: .largeTitle)

    static let navTitle = sans(17, weight: .semibold, relativeTo: .headline)
    static let cardTitle = sans(17, weight: .semibold, relativeTo: .headline)
    static let body = sans(16, relativeTo: .body)
    static let bodyMedium = sans(16, weight: .medium, relativeTo: .body)
    static let secondary = sans(14, relativeTo: .subheadline)
    static let caption = sans(12, relativeTo: .caption)
    static let button = sans(16, weight: .semibold, relativeTo: .body)
    static let chip = sans(12, weight: .semibold, relativeTo: .caption)
    static let tab = sans(10.5, weight: .medium, relativeTo: .caption2)

    static let label = mono(11, relativeTo: .caption)             // "SKIN TYPE"
    static let data = mono(15, relativeTo: .body)                 // INCI rows
    static let dataSmall = mono(12, relativeTo: .caption)         // barcode, confidence
}

extension View {
    /// Mono, uppercase, tracked — the design's section label treatment.
    func skLabelStyle() -> some View {
        self.font(SKFont.label)
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(SKColor.muted)
    }
}
