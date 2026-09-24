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

/// The Skintel drop mascot (designs: DropMoves): a plump terracotta drop with stubby
/// arms and mitten hands. Each pose loops; Reduce Motion holds a still frame.
struct DropMascot: View {
    enum Pose { case idle, wave, cheer, think, sleep, oops }

    var pose: Pose = .idle
    /// Height of the drawing; the width follows.
    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    nonisolated private static let skin = Color(hex: 0xD3725F)
    nonisolated private static let leg = Color(hex: 0xC96A58)
    nonisolated private static let outline = Color(hex: 0x44272C)
    nonisolated private static let eye = Color(hex: 0x442632)
    nonisolated private static let mouthFill = Color(hex: 0x7A2E28)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let current = pose
            Canvas { g, canvasSize in Self.draw(&g, canvasSize, t, current) }
        }
        .frame(width: size * 240 / 250, height: size)
        .accessibilityHidden(true)
    }

    // Drawn in a 240×250 box (x from -20), matching the design file's coordinates.
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
        let shadowW = 100 * (1 - 0.4 * lift)
        g.fill(Path(ellipseIn: CGRect(x: 100 - shadowW / 2, y: 225, width: shadowW, height: 14)),
               with: .color(Color(hex: 0x3C1E1E).opacity(0.14)))

        var fig = g
        fig.translateBy(x: 100, y: 230 + dy)
        fig.rotate(by: .degrees(tilt))
        fig.scaleBy(x: sx, y: sy)
        fig.translateBy(x: -100, y: -230)

        for x: CGFloat in [72, 107] {
            let legPath = Path(roundedRect: CGRect(x: x, y: 196, width: 21, height: 32), cornerRadius: 10)
            fig.fill(legPath, with: .color(Self.leg))
            fig.stroke(legPath, with: .color(Self.outline), lineWidth: 2.6)
        }

        switch pose {
        case .wave:
            limb(&fig, (52, 158), (38, 170), (33, 186))
            limb(&fig, (146, 150), (166, 132), (172, 108), pivot: (146, 152), degrees: 5 + 17 * sin(tau * t / 0.9))
        case .cheer:
            let swing = 10 + 10 * sin(tau * t / 1.2)
            limb(&fig, (54, 150), (34, 132), (28, 108), pivot: (54, 152), degrees: -swing)
            limb(&fig, (146, 150), (166, 132), (172, 108), pivot: (146, 152), degrees: swing)
        case .think:
            limb(&fig, (52, 158), (38, 170), (33, 186))
        default:
            limb(&fig, (52, 158), (38, 170), (33, 186))
            limb(&fig, (148, 158), (162, 170), (167, 186))
        }

        let drop = Self.dropPath
        fig.fill(drop, with: .radialGradient(
            Gradient(stops: [.init(color: Color(hex: 0xDA7C68), location: 0),
                             .init(color: Self.skin, location: 0.6),
                             .init(color: Color(hex: 0xA04C41), location: 1)]),
            center: CGPoint(x: 83, y: 113), startRadius: 0, endRadius: 140))
        fig.stroke(drop, with: .color(Self.outline), lineWidth: 2.6)
        var shine = Path()
        shine.move(to: CGPoint(x: 104, y: 70))
        shine.addQuadCurve(to: CGPoint(x: 88, y: 104), control: CGPoint(x: 92, y: 84))
        fig.stroke(shine, with: .color(Color(hex: 0xE5A194).opacity(0.9)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        for x: CGFloat in [56, 128] {
            fig.fill(Path(ellipseIn: CGRect(x: x, y: 162, width: 20, height: 12)), with: .color(Color(hex: 0xC45D4C).opacity(0.55)))
        }

        drawFace(&fig, t, pose)
        if pose == .think { limb(&fig, (150, 170), (146, 186), (128, 184)) }
        drawExtras(&g, t, pose)
    }

    nonisolated private static func drawFace(_ g: inout GraphicsContext, _ t: Double, _ pose: Pose) {
        let lid = StrokeStyle(lineWidth: 3.2, lineCap: .round)
        let cycle = t.truncatingRemainder(dividingBy: 4)
        let blink: CGFloat = cycle > 3.72 && cycle < 3.88 ? 0.12 : 1
        func eyes(_ y: CGFloat, dx: CGFloat = 0, ry: CGFloat = 7.5) {
            for x: CGFloat in [83, 121] {
                let h = ry * 2 * blink
                g.fill(Path(ellipseIn: CGRect(x: x + dx - 6.5, y: y - h / 2, width: 13, height: h)), with: .color(Self.eye))
            }
        }
        func line(_ points: [(CGFloat, CGFloat)], control: (CGFloat, CGFloat)? = nil) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: points[0].0, y: points[0].1))
            if let control {
                p.addQuadCurve(to: CGPoint(x: points[1].0, y: points[1].1), control: CGPoint(x: control.0, y: control.1))
            } else {
                p.addLine(to: CGPoint(x: points[1].0, y: points[1].1))
            }
            return p
        }
        let smile = line([(92, 166), (112, 166)], control: (102, 176))

        switch pose {
        case .idle, .wave:
            eyes(150)
            g.stroke(smile, with: .color(Self.eye), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        case .cheer:
            for x: CGFloat in [77, 115] {
                g.stroke(line([(x, 151), (x + 12, 151)], control: (x + 6, 144)), with: .color(Self.eye), style: lid)
            }
            var mouth = line([(93, 164), (111, 164)], control: (102, 182))
            mouth.closeSubpath()
            g.fill(mouth, with: .color(Self.mouthFill))
            g.stroke(mouth, with: .color(Self.eye), lineWidth: 2.6)
        case .think:
            eyes(146, dx: 3)
            g.stroke(line([(94, 170), (109, 168)]), with: .color(Self.eye), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        case .sleep:
            for x: CGFloat in [77, 115] {
                g.stroke(line([(x, 150), (x + 12, 150)], control: (x + 6, 155)), with: .color(Self.eye), style: lid)
            }
            g.fill(Path(ellipseIn: CGRect(x: 98, y: 167, width: 8, height: 6)), with: .color(Self.mouthFill))
        case .oops:
            eyes(152, ry: 6.5)
            g.stroke(line([(73, 139), (91, 143)]), with: .color(Self.eye), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            g.stroke(line([(131, 139), (113, 143)]), with: .color(Self.eye), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            g.stroke(line([(93, 173), (111, 173)], control: (102, 165)), with: .color(Self.eye), style: StrokeStyle(lineWidth: 3, lineCap: .round))
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
                       at: CGPoint(x: 152 + 22 * p, y: 72 - 50 * p))
            }
        case .cheer:
            for (i, spot) in [(18.0, 60.0, 20.0), (172.0, 40.0, 16.0), (184.0, 120.0, 12.0)].enumerated() {
                var c = g
                c.opacity = 0.2 + 0.8 * abs(sin(t * 2.2 + Double(i)))
                c.draw(Text("✦").font(.system(size: spot.2)).foregroundColor(Color(hex: 0xE3A04A)), at: CGPoint(x: spot.0, y: spot.1))
            }
        case .oops:
            let p = (t / 2).truncatingRemainder(dividingBy: 1)
            let fall = p < 0.3 ? 0.0 : (p - 0.3) / 0.7 * 40
            var c = g
            c.opacity = p < 0.3 ? 1.0 : 1 - (p - 0.3) / 0.7
            c.translateBy(x: 0, y: fall)
            let sweat = Self.sweatPath
            c.fill(sweat, with: .color(Color(hex: 0x9CC4E4)))
            c.stroke(sweat, with: .color(Color(hex: 0x4A7A9C)), lineWidth: 2)
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
        c.stroke(arm, with: .color(Self.outline), style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
        let mitten = Path(ellipseIn: CGRect(x: hand.0 - 9, y: hand.1 - 9, width: 18, height: 18))
        c.fill(mitten, with: .color(Self.skin))
        c.stroke(mitten, with: .color(Self.outline), lineWidth: 2.6)
        c.stroke(arm, with: .color(Self.skin), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
    }

    nonisolated private static let dropPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 112, y: 54))
        p.addQuadCurve(to: CGPoint(x: 124, y: 56), control: CGPoint(x: 118, y: 42))
        p.addCurve(to: CGPoint(x: 162, y: 158), control1: CGPoint(x: 138, y: 82), control2: CGPoint(x: 162, y: 116))
        p.addArc(center: CGPoint(x: 100, y: 158), radius: 62, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: 112, y: 54), control1: CGPoint(x: 38, y: 112), control2: CGPoint(x: 74, y: 72))
        p.closeSubpath()
        return p
    }()

    nonisolated private static let sweatPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 152, y: 96))
        p.addCurve(to: CGPoint(x: 160, y: 112), control1: CGPoint(x: 156, y: 104), control2: CGPoint(x: 160, y: 108))
        p.addArc(center: CGPoint(x: 152, y: 112), radius: 8, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: 152, y: 96), control1: CGPoint(x: 144, y: 108), control2: CGPoint(x: 148, y: 104))
        p.closeSubpath()
        return p
    }()
}
