import SwiftUI

/// Product tile: the real front-of-pack photo when a scan or search found one, otherwise
/// an illustrated bottle (pump, tube or dropper, picked from the name/category).
struct SKProductMark: View {
    let name: String
    var size: CGFloat = 48
    var category: String? = nil
    /// An explicit photo; when nil, a photo remembered from an earlier scan is used.
    var imageURL: String? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
        ZStack {
            shape.fill(SKColor.tile(for: name).bg)
            if let url = (imageURL ?? ProductImages.url(for: name)).flatMap({ URL(string: $0) }) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if let image = phase.image {
                        ZStack {
                            Color.white
                            image.resizable().scaledToFit().padding(size * 0.06)
                        }
                    } else {
                        bottle
                    }
                }
            } else {
                bottle
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private var bottle: some View {
        Image(ProductArt.asset(for: name, category: category))
            .resizable()
            .scaledToFit()
            .padding(.vertical, size * 0.1)
            .shadow(color: .black.opacity(0.12), radius: size * 0.04, y: size * 0.03)
    }
}

/// The bottle illustrations shipped in the asset catalog (from the website sprite).
enum ProductArt {
    static let pump = "ProductPump"
    static let tube = "ProductTube"
    static let dropper = "ProductDropper"
    static let tubeBack = "ProductTubeBack"

    static func asset(for name: String, category: String? = nil) -> String {
        let text = "\(category ?? "") \(name)".lowercased()
        let droppers = ["serum", "oil", "essence", "drops", "ampoule", "toner", "treatment"]
        let pumps = ["cleanser", "wash", "foam", "micellar", "lotion", "gel", "milk"]
        let tubes = ["cream", "spf", "sunscreen", "balm", "mask", "moistur", "exfoliant", "scrub"]
        if droppers.contains(where: { text.contains($0) }) { return dropper }
        if pumps.contains(where: { text.contains($0) }) { return pump }
        if tubes.contains(where: { text.contains($0) }) { return tube }
        let all = [pump, tube, dropper]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return all[sum % all.count]
    }
}

/// Product photos found while scanning or searching, keyed by product name (this device only).
enum ProductImages {
    static let key = "product.images"
    private static let limit = 400

    static func url(for name: String) -> String? {
        let k = normalized(name)
        guard !k.isEmpty else { return nil }
        return (UserDefaults.standard.dictionary(forKey: key) as? [String: String])?[k]
    }

    static func remember(_ url: String?, for names: [String?]) {
        guard let url, url.hasPrefix("https://") else { return }
        var all = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        for name in names.compactMap({ $0 }) {
            let k = normalized(name)
            if !k.isEmpty { all[k] = url }
        }
        if all.count > limit { all = Dictionary(uniqueKeysWithValues: all.suffix(limit).map { ($0.key, $0.value) }) }
        UserDefaults.standard.set(all, forKey: key)
    }

    private static func normalized(_ s: String) -> String {
        s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
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

/// The app mark used on splash and sign-in: the real app icon's terracotta circle with a
/// cream four-point sparkle and two small ones (matches designs/app-icon-ios.svg).
struct SKAppMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle().fill(SKColor.primary)
            SparkleShape().fill(SKColor.cream)
                .frame(width: size * 0.45, height: size * 0.45)
            SparkleShape().fill(SKColor.cream)
                .frame(width: size * 0.125, height: size * 0.125)
                .offset(x: size * 0.175, y: size * 0.175)
            SparkleShape().fill(SKColor.cream)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: size * 0.169, y: -size * 0.231)
        }
        .frame(width: size, height: size)
        .skPrimaryGlow(strength: 0.3)
        .accessibilityLabel("Skintel")
    }
}

/// The four-point sparkle from the app icon (designs/app-icon-ios.svg): a diamond with
/// concave sides, not a plain star. Fills its given frame.
private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [
            (0.5, 0), (0.6111, 0.3889), (1, 0.5), (0.6111, 0.6111),
            (0.5, 1), (0.3889, 0.6111), (0, 0.5), (0.3889, 0.3889),
        ]
        var p = Path()
        for (i, pt) in pts.enumerated() {
            let point = CGPoint(x: rect.minX + pt.0 * rect.width, y: rect.minY + pt.1 * rect.height)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
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
