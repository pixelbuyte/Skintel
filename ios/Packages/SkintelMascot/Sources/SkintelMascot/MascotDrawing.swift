import SwiftUI
import MascotRig

/// Colours sampled from the original character art.
enum MascotPalette {
    static let skin = Color(red: 211 / 255, green: 114 / 255, blue: 95 / 255)
    static let skinLight = Color(red: 217 / 255, green: 122 / 255, blue: 102 / 255)
    static let skinShade = Color(red: 160 / 255, green: 76 / 255, blue: 65 / 255)
    static let outline = Color(red: 68 / 255, green: 39 / 255, blue: 44 / 255)
    static let eye = Color(red: 68 / 255, green: 38 / 255, blue: 50 / 255)
    static let shine = Color(red: 232 / 255, green: 165 / 255, blue: 150 / 255)
    static let blush = Color(red: 196 / 255, green: 93 / 255, blue: 76 / 255)
    static let mouth = Color(red: 122 / 255, green: 46 / 255, blue: 40 / 255)
    static let glass = Color(red: 244 / 255, green: 220 / 255, blue: 216 / 255)
    static let tube = Color(red: 201 / 255, green: 169 / 255, blue: 164 / 255)
    static let cap = Color(red: 184 / 255, green: 87 / 255, blue: 74 / 255)
    static let bulb = Color(red: 196 / 255, green: 96 / 255, blue: 79 / 255)
    static let gold = Color(red: 224 / 255, green: 178 / 255, blue: 74 / 255)
    static let scanner = Color(red: 231 / 255, green: 228 / 255, blue: 221 / 255)
    static let laser = Color(red: 224 / 255, green: 64 / 255, blue: 64 / 255)
    static let sparkle = Color(red: 227 / 255, green: 160 / 255, blue: 74 / 255)
    static let floor = Color(red: 60 / 255, green: 30 / 255, blue: 30 / 255)
}

/// Paths for each body part, built once from `MascotGeometry` (design space, 240 × 250).
enum MascotPaths {
    private typealias G = MascotGeometry

    static let body: Path = {
        var p = Path()
        p.move(to: G.bodyStart)
        for s in G.bodySegments {
            p.addCurve(to: s.end, control1: s.control1, control2: s.control2)
        }
        p.closeSubpath()
        return p
    }()

    static func leg(_ leg: MascotGeometry.Leg) -> Path {
        let toe = leg.left - leg.toe
        var p = Path()
        p.move(to: CGPoint(x: leg.left, y: leg.top))
        p.addLine(to: CGPoint(x: leg.right, y: leg.top))
        p.addLine(to: CGPoint(x: leg.right, y: leg.bottom - 5))
        p.addQuadCurve(to: CGPoint(x: leg.right - 5, y: leg.bottom), control: CGPoint(x: leg.right, y: leg.bottom))
        p.addLine(to: CGPoint(x: toe + 3, y: leg.bottom))
        p.addQuadCurve(to: CGPoint(x: toe, y: leg.bottom - 3), control: CGPoint(x: toe, y: leg.bottom))
        p.addQuadCurve(to: CGPoint(x: leg.left, y: leg.bottom - 9), control: CGPoint(x: toe, y: leg.bottom - 7))
        p.closeSubpath()
        return p
    }

    static func arm(_ arm: MascotGeometry.Arm) -> Path {
        var p = Path()
        p.move(to: arm.shoulder)
        p.addQuadCurve(to: arm.hand, control: arm.control)
        return p
    }

    static func hand(_ arm: MascotGeometry.Arm) -> Path {
        let r = G.handRadius
        return Path(ellipseIn: CGRect(x: arm.hand.x - r, y: arm.hand.y - r, width: r * 2, height: r * 2))
    }

    static let shine: Path = {
        var p = Path()
        p.move(to: G.shineTop)
        p.addQuadCurve(to: G.shineBottom, control: G.shineOuter)
        p.addQuadCurve(to: G.shineTop, control: G.shineInner)
        p.closeSubpath()
        return p
    }()

    static let smile = curve(G.mouthLeft, G.mouthRight, G.smileControl)
    static let frown = curve(CGPoint(x: 94, y: 155), CGPoint(x: 114, y: 155), G.frownControl)
    static let happyEyes: Path = {
        var p = curve(CGPoint(x: 76, y: 138), CGPoint(x: 89, y: 138), CGPoint(x: 82.4, y: 131))
        p.addPath(curve(CGPoint(x: 123, y: 144), CGPoint(x: 136, y: 144), CGPoint(x: 129.7, y: 137)))
        return p
    }()
    static let openMouth: Path = {
        var p = curve(CGPoint(x: 94, y: 146), CGPoint(x: 114, y: 146), CGPoint(x: 104, y: 166))
        p.closeSubpath()
        return p
    }()
    static let worriedBrows: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 73, y: 127))
        p.addLine(to: CGPoint(x: 90, y: 123))
        p.move(to: CGPoint(x: 138, y: 131))
        p.addLine(to: CGPoint(x: 121, y: 127))
        return p
    }()

    static let dropperTube: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 56, y: 130))
        p.addLine(to: CGPoint(x: 56, y: 158))
        return p
    }()

    /// The little gold drop printed on the bottle, like the original art.
    static let labelDrop: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 56, y: 158))
        p.addCurve(to: CGPoint(x: 61, y: 169), control1: CGPoint(x: 59, y: 163), control2: CGPoint(x: 61, y: 166))
        p.addArc(center: CGPoint(x: 56, y: 169), radius: 5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: 56, y: 158), control1: CGPoint(x: 51, y: 166), control2: CGPoint(x: 53, y: 163))
        p.closeSubpath()
        return p
    }()

    /// A four-point sparkle filling a square of `size` around `center`.
    static func sparkle(_ center: CGPoint, _ size: CGFloat) -> Path {
        let r = size / 2, w = size * 0.12
        var p = Path()
        p.move(to: CGPoint(x: center.x, y: center.y - r))
        p.addLine(to: CGPoint(x: center.x + w, y: center.y - w))
        p.addLine(to: CGPoint(x: center.x + r, y: center.y))
        p.addLine(to: CGPoint(x: center.x + w, y: center.y + w))
        p.addLine(to: CGPoint(x: center.x, y: center.y + r))
        p.addLine(to: CGPoint(x: center.x - w, y: center.y + w))
        p.addLine(to: CGPoint(x: center.x - r, y: center.y))
        p.addLine(to: CGPoint(x: center.x - w, y: center.y - w))
        p.closeSubpath()
        return p
    }

    private static func curve(_ a: CGPoint, _ b: CGPoint, _ control: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: b, control: control)
        return p
    }
}

/// A design-space path drawn inside whatever frame it gets (the figure is always 240 × 250).
struct DesignShape: Shape {
    private let design: Path

    init(_ design: Path) {
        self.design = design
    }

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / MascotGeometry.canvas.width
        let sy = rect.height / MascotGeometry.canvas.height
        return design.applying(CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: rect.minX, ty: rect.minY))
    }
}

extension CGPoint {
    /// This design-space point as an anchor inside the 240 × 250 figure.
    var anchor: UnitPoint {
        UnitPoint(x: x / MascotGeometry.canvas.width, y: y / MascotGeometry.canvas.height)
    }
}
