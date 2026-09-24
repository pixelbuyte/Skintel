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

/// The Skintel drop mascot, traced from the reference drawing: a round-bottomed terracotta
/// drop leaning right, boot feet, stubby arms with mitten hands, face in three-quarter view.
/// Each pose loops; Reduce Motion holds a still frame.
struct DropMascot: View {
    enum Pose { case idle, wave, cheer, think, sleep, oops }

    var pose: Pose = .idle
    /// Height of the drawing; the width follows.
    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    nonisolated private static let skin = Color(hex: 0xD3725F)
    nonisolated private static let outline = Color(hex: 0x44272C)
    nonisolated private static let eye = Color(hex: 0x442632)
    nonisolated private static let mouthFill = Color(hex: 0x7A2E28)
    nonisolated private static let line: CGFloat = 2.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let current = pose
            Canvas { g, canvasSize in Self.draw(&g, canvasSize, t, current) }
        }
        .frame(width: size * 240 / 250, height: size)
        .accessibilityHidden(true)
    }

    // Drawn in a 240×250 box (x from -20), the same coordinates as the design file.
    nonisolated private static func draw(_ g: inout GraphicsContext, _ canvasSize: CGSize, _ t: Double, _ pose: Pose) {
        let s = min(canvasSize.width / 240, canvasSize.height / 250)
        g.translateBy(x: (canvasSize.width - 240 * s) / 2 + 20 * s, y: canvasSize.height - 250 * s)
        g.scaleBy(x: s, y: s)

        let tau = 2 * Double.pi
        var dy = 0.0, sx = 1.0, sy = 1.0, tilt = 0.0
        switch pose {
        case .idle, .wave:
            let b = 0.5 - 0.5 * cos(tau * t / 2.4)
            dy = -4 * b; sx = 1 + 0.02 * b; sy = 1 - 0.02 * b
        case .cheer:
            let p = (t / 1.2).truncatingRemainder(dividingBy: 1)
            if p < 0.7 {
                let a = sin(.pi * p / 0.7)
                dy = -38 * a; sx = 1 - 0.05 * a; sy = 1 + 0.06 * a
            } else {
                let q = sin(.pi * (p - 0.7) / 0.3)
                sx = 1 + 0.1 * q; sy = 1 - 0.1 * q
            }
        case .think:
            tilt = 5 * sin(tau * t / 2.6)
        case .sleep:
            let b = 0.5 - 0.5 * cos(tau * t / 3.6)
            sx = 1 + 0.04 * b; sy = 1 - 0.04 * b
        case .oops:
            let b = 0.5 - 0.5 * cos(tau * t / 3)
            sx = 1 + 0.06 * b; sy = 1 - 0.07 * b; tilt = -2 * b
        }

        let lift = min(1, -dy / 38)
        let shadowW = 92 * (1 - 0.4 * lift)
        g.fill(Path(ellipseIn: CGRect(x: 100 - shadowW / 2, y: 234, width: shadowW, height: 12)),
               with: .color(Color(hex: 0x3C1E1E).opacity(0.14)))

        var fig = g
        fig.translateBy(x: 100, y: 240 + dy)
        fig.rotate(by: .degrees(tilt))
        fig.scaleBy(x: sx, y: sy)
        fig.translateBy(x: -100, y: -240)

        fig.fill(legsPath, with: .color(skin))
        fig.stroke(legsPath, with: .color(outline), style: StrokeStyle(lineWidth: line, lineJoin: .round))

        switch pose {
        case .wave:
            limb(&fig, (52, 170), (42, 180), (38, 192))
            limb(&fig, (152, 150), (172, 132), (176, 110), pivot: (152, 152), degrees: 5 + 17 * sin(tau * t / 0.9))
        case .cheer:
            let swing = 10 + 10 * sin(tau * t / 1.2)
            limb(&fig, (50, 150), (30, 132), (26, 110), pivot: (50, 152), degrees: -swing)
            limb(&fig, (152, 150), (172, 132), (176, 110), pivot: (152, 152), degrees: swing)
        case .think:
            limb(&fig, (52, 170), (42, 180), (38, 192))
        default:
            limb(&fig, (52, 170), (42, 180), (38, 192))
            limb(&fig, (152, 176), (162, 186), (164, 198))
        }

        fig.fill(dropPath, with: .radialGradient(
            Gradient(stops: [.init(color: Color(hex: 0xD97A66), location: 0),
                             .init(color: skin, location: 0.62),
                             .init(color: Color(hex: 0xA04C41), location: 1)]),
            center: CGPoint(x: 82.7, y: 115.6), startRadius: 0, endRadius: 144))
        fig.stroke(dropPath, with: .color(outline), lineWidth: line)
        fig.fill(shinePath, with: .color(Color(hex: 0xE8A596).opacity(0.9)))
        fig.fill(Path(ellipseIn: CGRect(x: 109.8, y: 151.9, width: 22, height: 10.8)), with: .color(Color(hex: 0xC45D4C).opacity(0.6)))

        drawFace(&fig, t, pose)
        if pose == .think { limb(&fig, (154, 174), (158, 156), (134, 152)) }
        drawExtras(&g, t, pose)
    }

    nonisolated private static func drawFace(_ g: inout GraphicsContext, _ t: Double, _ pose: Pose) {
        let lid = StrokeStyle(lineWidth: 2.8, lineCap: .round)
        let pen = StrokeStyle(lineWidth: 2.6, lineCap: .round)
        let cycle = t.truncatingRemainder(dividingBy: 4)
        let blink: CGFloat = cycle > 3.72 && cycle < 3.88 ? 0.12 : 1
        func eyes(dx: CGFloat = 0, dy: CGFloat = 0, shrink: CGFloat = 0) {
            let spots: [(CGFloat, CGFloat, CGFloat)] = [(62.4, 136.9, 6.3), (109.7, 143.2, 6.7)]
            for (x, y, rx) in spots {
                let w = (rx - shrink) * 2, h = (6.8 - shrink) * 2 * blink
                g.fill(Path(ellipseIn: CGRect(x: x + dx - w / 2, y: y + dy - h / 2, width: w, height: h)), with: .color(eye))
            }
        }
        func curve(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat), _ c: (CGFloat, CGFloat)? = nil) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: a.0, y: a.1))
            if let c {
                p.addQuadCurve(to: CGPoint(x: b.0, y: b.1), control: CGPoint(x: c.0, y: c.1))
            } else {
                p.addLine(to: CGPoint(x: b.0, y: b.1))
            }
            return p
        }

        switch pose {
        case .idle, .wave:
            eyes()
            g.stroke(curve((73, 146), (95, 146), (84, 162)), with: .color(eye), style: pen)
        case .cheer:
            g.stroke(curve((56, 138), (69, 138), (62.4, 131)), with: .color(eye), style: lid)
            g.stroke(curve((103, 144), (116, 144), (109.7, 137)), with: .color(eye), style: lid)
            var mouth = curve((74, 146), (94, 146), (84, 166))
            mouth.closeSubpath()
            g.fill(mouth, with: .color(mouthFill))
            g.stroke(mouth, with: .color(eye), lineWidth: 2.4)
        case .think:
            eyes(dx: 2, dy: -4)
            g.stroke(curve((76, 151), (92, 149)), with: .color(eye), style: pen)
        case .sleep:
            g.stroke(curve((56, 137), (69, 137), (62.4, 142)), with: .color(eye), style: lid)
            g.stroke(curve((103, 143), (116, 143), (109.7, 148)), with: .color(eye), style: lid)
            g.fill(Path(ellipseIn: CGRect(x: 80.5, y: 148.4, width: 7, height: 5.2)), with: .color(mouthFill))
        case .oops:
            eyes(dy: 1, shrink: 0.6)
            g.stroke(curve((53, 127), (70, 123)), with: .color(eye), style: pen)
            g.stroke(curve((118, 131), (101, 127)), with: .color(eye), style: pen)
            g.stroke(curve((74, 155), (94, 155), (84, 146)), with: .color(eye), style: pen)
        }
    }

    nonisolated private static func drawExtras(_ g: inout GraphicsContext, _ t: Double, _ pose: Pose) {
        switch pose {
        case .think:
            let p = (t / 2.2).truncatingRemainder(dividingBy: 1)
            var scale = 1.0
            if p < 0.2 { scale = 0 } else if p < 0.35 { scale = (p - 0.2) / 0.15 * 1.2 } else if p > 0.85 { scale = max(0, 1 - (p - 0.85) / 0.15) }
            var c = g
            c.opacity = min(1, scale)
            c.translateBy(x: 172, y: 40)
            c.scaleBy(x: max(0.01, scale), y: max(0.01, scale))
            c.draw(Text("?").font(.system(size: 36, weight: .bold)).foregroundColor(SKColor.primary), at: .zero)
        case .sleep:
            for i in 0..<3 {
                let p = ((t + Double(i)) / 3).truncatingRemainder(dividingBy: 1)
                var c = g
                c.opacity = sin(.pi * p)
                c.draw(Text("z").font(.system(size: 22 - CGFloat(i) * 4, weight: .bold)).foregroundColor(SKColor.muted),
                       at: CGPoint(x: 150 + 22 * p, y: 70 - 50 * p))
            }
        case .cheer:
            let spots: [(CGFloat, CGFloat, CGFloat)] = [(14, 60, 20), (176, 40, 16), (190, 120, 12)]
            for (i, spot) in spots.enumerated() {
                var c = g
                c.opacity = 0.2 + 0.8 * abs(sin(t * 2.2 + Double(i)))
                c.draw(Text("✦").font(.system(size: spot.2)).foregroundColor(Color(hex: 0xE3A04A)), at: CGPoint(x: spot.0, y: spot.1))
            }
        case .oops:
            let p = (t / 2).truncatingRemainder(dividingBy: 1)
            var c = g
            c.opacity = p < 0.3 ? 1.0 : 1 - (p - 0.3) / 0.7
            c.translateBy(x: 0, y: p < 0.3 ? 0.0 : (p - 0.3) / 0.7 * 40)
            c.fill(sweatPath, with: .color(Color(hex: 0x9CC4E4)))
            c.stroke(sweatPath, with: .color(Color(hex: 0x4A7A9C)), lineWidth: 2)
        default:
            break
        }
    }

    /// A stubby arm: outlined stroke, round mitten hand, then the skin stroke over the join.
    nonisolated private static func limb(_ g: inout GraphicsContext, _ from: (CGFloat, CGFloat), _ control: (CGFloat, CGFloat), _ hand: (CGFloat, CGFloat),
                                         pivot: (CGFloat, CGFloat)? = nil, degrees: Double = 0) {
        var c = g
        if let pivot {
            c.translateBy(x: pivot.0, y: pivot.1)
            c.rotate(by: .degrees(degrees))
            c.translateBy(x: -pivot.0, y: -pivot.1)
        }
        var arm = Path()
        arm.move(to: CGPoint(x: from.0, y: from.1))
        arm.addQuadCurve(to: CGPoint(x: hand.0, y: hand.1), control: CGPoint(x: control.0, y: control.1))
        c.stroke(arm, with: .color(outline), style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
        let mitten = Path(ellipseIn: CGRect(x: hand.0 - 7.5, y: hand.1 - 7.5, width: 15, height: 15))
        c.fill(mitten, with: .color(skin))
        c.stroke(mitten, with: .color(outline), lineWidth: line)
        c.stroke(arm, with: .color(skin), style: StrokeStyle(lineWidth: 8.6, lineCap: .round, lineJoin: .round))
    }

    /// Traced from the reference: round belly, tip leaning right.
    nonisolated private static let dropPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 119.1, y: 40.0))
        p.addCurve(to: CGPoint(x: 123.0, y: 47.3), control1: CGPoint(x: 121.5, y: 40.0), control2: CGPoint(x: 121.8, y: 43.6))
        p.addCurve(to: CGPoint(x: 126.0, y: 62.0), control1: CGPoint(x: 124.2, y: 51.0), control2: CGPoint(x: 124.8, y: 57.1))
        p.addCurve(to: CGPoint(x: 130.4, y: 76.7), control1: CGPoint(x: 127.2, y: 66.9), control2: CGPoint(x: 128.7, y: 71.8))
        p.addCurve(to: CGPoint(x: 136.5, y: 91.4), control1: CGPoint(x: 132.2, y: 81.6), control2: CGPoint(x: 134.3, y: 86.5))
        p.addCurve(to: CGPoint(x: 143.8, y: 106.1), control1: CGPoint(x: 138.7, y: 96.3), control2: CGPoint(x: 141.3, y: 101.2))
        p.addCurve(to: CGPoint(x: 151.4, y: 120.8), control1: CGPoint(x: 146.3, y: 111.0), control2: CGPoint(x: 149.1, y: 115.9))
        p.addCurve(to: CGPoint(x: 157.6, y: 135.5), control1: CGPoint(x: 153.7, y: 125.7), control2: CGPoint(x: 156.0, y: 130.6))
        p.addCurve(to: CGPoint(x: 161.0, y: 150.2), control1: CGPoint(x: 159.2, y: 140.4), control2: CGPoint(x: 160.3, y: 146.5))
        p.addCurve(to: CGPoint(x: 161.7, y: 157.6), control1: CGPoint(x: 161.7, y: 153.9), control2: CGPoint(x: 161.6, y: 155.1))
        p.addCurve(to: CGPoint(x: 161.5, y: 164.9), control1: CGPoint(x: 161.8, y: 160.1), control2: CGPoint(x: 161.9, y: 161.2))
        p.addCurve(to: CGPoint(x: 159.0, y: 179.6), control1: CGPoint(x: 161.1, y: 168.6), control2: CGPoint(x: 159.9, y: 175.9))
        p.addCurve(to: CGPoint(x: 156.1, y: 186.9), control1: CGPoint(x: 158.1, y: 183.3), control2: CGPoint(x: 157.2, y: 184.4))
        p.addCurve(to: CGPoint(x: 152.2, y: 194.3), control1: CGPoint(x: 155.0, y: 189.4), control2: CGPoint(x: 153.9, y: 191.9))
        p.addCurve(to: CGPoint(x: 146.0, y: 201.6), control1: CGPoint(x: 150.5, y: 196.8), control2: CGPoint(x: 148.4, y: 199.2))
        p.addCurve(to: CGPoint(x: 137.5, y: 209.0), control1: CGPoint(x: 143.6, y: 204.0), control2: CGPoint(x: 141.4, y: 206.6))
        p.addCurve(to: CGPoint(x: 122.5, y: 216.3), control1: CGPoint(x: 133.6, y: 211.4), control2: CGPoint(x: 128.8, y: 214.5))
        p.addCurve(to: CGPoint(x: 100.0, y: 220.0), control1: CGPoint(x: 116.2, y: 218.1), control2: CGPoint(x: 107.4, y: 219.9))
        p.addCurve(to: CGPoint(x: 78.0, y: 217.1), control1: CGPoint(x: 92.6, y: 220.1), control2: CGPoint(x: 84.1, y: 218.6))
        p.addCurve(to: CGPoint(x: 63.3, y: 210.9), control1: CGPoint(x: 71.9, y: 215.6), control2: CGPoint(x: 67.0, y: 212.8))
        p.addCurve(to: CGPoint(x: 55.9, y: 206.0), control1: CGPoint(x: 59.6, y: 209.1), control2: CGPoint(x: 58.3, y: 208.4))
        p.addCurve(to: CGPoint(x: 48.6, y: 196.2), control1: CGPoint(x: 53.5, y: 203.6), control2: CGPoint(x: 50.6, y: 199.9))
        p.addCurve(to: CGPoint(x: 43.7, y: 184.0), control1: CGPoint(x: 46.6, y: 192.5), control2: CGPoint(x: 44.9, y: 188.5))
        p.addCurve(to: CGPoint(x: 41.2, y: 169.3), control1: CGPoint(x: 42.5, y: 179.5), control2: CGPoint(x: 41.8, y: 174.2))
        p.addCurve(to: CGPoint(x: 40.2, y: 154.6), control1: CGPoint(x: 40.6, y: 164.4), control2: CGPoint(x: 40.3, y: 159.3))
        p.addCurve(to: CGPoint(x: 40.7, y: 141.1), control1: CGPoint(x: 40.1, y: 149.9), control2: CGPoint(x: 40.4, y: 145.5))
        p.addCurve(to: CGPoint(x: 42.2, y: 128.2), control1: CGPoint(x: 41.0, y: 136.7), control2: CGPoint(x: 41.5, y: 131.6))
        p.addCurve(to: CGPoint(x: 45.1, y: 120.8), control1: CGPoint(x: 42.9, y: 124.8), control2: CGPoint(x: 43.1, y: 124.5))
        p.addCurve(to: CGPoint(x: 54.0, y: 106.1), control1: CGPoint(x: 47.1, y: 117.1), control2: CGPoint(x: 50.5, y: 111.0))
        p.addCurve(to: CGPoint(x: 66.0, y: 91.4), control1: CGPoint(x: 57.5, y: 101.2), control2: CGPoint(x: 61.7, y: 96.3))
        p.addCurve(to: CGPoint(x: 79.9, y: 76.7), control1: CGPoint(x: 70.3, y: 86.5), control2: CGPoint(x: 75.2, y: 81.6))
        p.addCurve(to: CGPoint(x: 94.1, y: 62.0), control1: CGPoint(x: 84.6, y: 71.8), control2: CGPoint(x: 89.3, y: 66.9))
        p.addCurve(to: CGPoint(x: 108.8, y: 47.3), control1: CGPoint(x: 98.9, y: 57.1), control2: CGPoint(x: 104.6, y: 51.0))
        p.addCurve(to: CGPoint(x: 119.1, y: 40.0), control1: CGPoint(x: 113.0, y: 43.6), control2: CGPoint(x: 116.7, y: 40.0))
        p.closeSubpath()
        return p
    }()

    /// Two boot feet, toes pointing left like the reference.
    nonisolated private static let legsPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 71, y: 206))
        p.addLine(to: CGPoint(x: 86.5, y: 206))
        p.addLine(to: CGPoint(x: 86.5, y: 231))
        p.addQuadCurve(to: CGPoint(x: 81.5, y: 236), control: CGPoint(x: 86.5, y: 236))
        p.addLine(to: CGPoint(x: 70.5, y: 236))
        p.addQuadCurve(to: CGPoint(x: 67.5, y: 233), control: CGPoint(x: 67.5, y: 236))
        p.addQuadCurve(to: CGPoint(x: 71, y: 227), control: CGPoint(x: 67.5, y: 229))
        p.closeSubpath()
        p.move(to: CGPoint(x: 105.5, y: 206))
        p.addLine(to: CGPoint(x: 122, y: 206))
        p.addLine(to: CGPoint(x: 122, y: 237))
        p.addQuadCurve(to: CGPoint(x: 117, y: 242), control: CGPoint(x: 122, y: 242))
        p.addLine(to: CGPoint(x: 105.5, y: 242))
        p.addQuadCurve(to: CGPoint(x: 102.5, y: 239), control: CGPoint(x: 102.5, y: 242))
        p.addQuadCurve(to: CGPoint(x: 105.5, y: 233), control: CGPoint(x: 102.5, y: 235))
        p.closeSubpath()
        return p
    }()

    nonisolated private static let shinePath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 101, y: 64))
        p.addQuadCurve(to: CGPoint(x: 66, y: 110), control: CGPoint(x: 89.1, y: 91.2))
        p.addQuadCurve(to: CGPoint(x: 101, y: 64), control: CGPoint(x: 77.9, y: 82.8))
        p.closeSubpath()
        return p
    }()

    nonisolated private static let sweatPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 150, y: 88))
        p.addCurve(to: CGPoint(x: 158, y: 104), control1: CGPoint(x: 154, y: 96), control2: CGPoint(x: 158, y: 100))
        p.addArc(center: CGPoint(x: 150, y: 104), radius: 8, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: 150, y: 88), control1: CGPoint(x: 142, y: 100), control2: CGPoint(x: 146, y: 96))
        p.closeSubpath()
        return p
    }()
}
