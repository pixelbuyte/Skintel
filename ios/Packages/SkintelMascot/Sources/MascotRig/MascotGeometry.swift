import Foundation

/// The droplet's drawing, in a fixed 240 × 250 design space (y grows downward). The body
/// outline is traced from the original character art; everything else is placed against it.
/// Pure data, no UI framework, so it can be checked on any platform.
public enum MascotGeometry {
    public static let canvas = CGSize(width: 240, height: 250)

    /// Where the feet meet the floor: the pivot for breathing, jumping and leaning.
    public static let feet = CGPoint(x: 120, y: 240)

    public struct CubicSegment: Sendable, Equatable {
        public let control1: CGPoint
        public let control2: CGPoint
        public let end: CGPoint
    }

    /// Round belly, tip leaning right. Closed: the last segment ends at `bodyStart`.
    public static let bodyStart = CGPoint(x: 139.1, y: 40)
    public static let bodySegments: [CubicSegment] = [
        .init(control1: CGPoint(x: 141.5, y: 40), control2: CGPoint(x: 141.8, y: 43.6), end: CGPoint(x: 143, y: 47.3)),
        .init(control1: CGPoint(x: 144.2, y: 51), control2: CGPoint(x: 144.8, y: 57.1), end: CGPoint(x: 146, y: 62)),
        .init(control1: CGPoint(x: 147.2, y: 66.9), control2: CGPoint(x: 148.7, y: 71.8), end: CGPoint(x: 150.4, y: 76.7)),
        .init(control1: CGPoint(x: 152.2, y: 81.6), control2: CGPoint(x: 154.3, y: 86.5), end: CGPoint(x: 156.5, y: 91.4)),
        .init(control1: CGPoint(x: 158.7, y: 96.3), control2: CGPoint(x: 161.3, y: 101.2), end: CGPoint(x: 163.8, y: 106.1)),
        .init(control1: CGPoint(x: 166.3, y: 111), control2: CGPoint(x: 169.1, y: 115.9), end: CGPoint(x: 171.4, y: 120.8)),
        .init(control1: CGPoint(x: 173.7, y: 125.7), control2: CGPoint(x: 176, y: 130.6), end: CGPoint(x: 177.6, y: 135.5)),
        .init(control1: CGPoint(x: 179.2, y: 140.4), control2: CGPoint(x: 180.3, y: 146.5), end: CGPoint(x: 181, y: 150.2)),
        .init(control1: CGPoint(x: 181.7, y: 153.9), control2: CGPoint(x: 181.6, y: 155.1), end: CGPoint(x: 181.7, y: 157.6)),
        .init(control1: CGPoint(x: 181.8, y: 160.1), control2: CGPoint(x: 181.9, y: 161.2), end: CGPoint(x: 181.5, y: 164.9)),
        .init(control1: CGPoint(x: 181.1, y: 168.6), control2: CGPoint(x: 179.9, y: 175.9), end: CGPoint(x: 179, y: 179.6)),
        .init(control1: CGPoint(x: 178.1, y: 183.3), control2: CGPoint(x: 177.2, y: 184.4), end: CGPoint(x: 176.1, y: 186.9)),
        .init(control1: CGPoint(x: 175, y: 189.4), control2: CGPoint(x: 173.9, y: 191.9), end: CGPoint(x: 172.2, y: 194.3)),
        .init(control1: CGPoint(x: 170.5, y: 196.8), control2: CGPoint(x: 168.4, y: 199.2), end: CGPoint(x: 166, y: 201.6)),
        .init(control1: CGPoint(x: 163.6, y: 204), control2: CGPoint(x: 161.4, y: 206.6), end: CGPoint(x: 157.5, y: 209)),
        .init(control1: CGPoint(x: 153.6, y: 211.4), control2: CGPoint(x: 148.8, y: 214.5), end: CGPoint(x: 142.5, y: 216.3)),
        .init(control1: CGPoint(x: 136.2, y: 218.1), control2: CGPoint(x: 127.4, y: 219.9), end: CGPoint(x: 120, y: 220)),
        .init(control1: CGPoint(x: 112.6, y: 220.1), control2: CGPoint(x: 104.1, y: 218.6), end: CGPoint(x: 98, y: 217.1)),
        .init(control1: CGPoint(x: 91.9, y: 215.6), control2: CGPoint(x: 87, y: 212.8), end: CGPoint(x: 83.3, y: 210.9)),
        .init(control1: CGPoint(x: 79.6, y: 209.1), control2: CGPoint(x: 78.3, y: 208.4), end: CGPoint(x: 75.9, y: 206)),
        .init(control1: CGPoint(x: 73.5, y: 203.6), control2: CGPoint(x: 70.6, y: 199.9), end: CGPoint(x: 68.6, y: 196.2)),
        .init(control1: CGPoint(x: 66.6, y: 192.5), control2: CGPoint(x: 64.9, y: 188.5), end: CGPoint(x: 63.7, y: 184)),
        .init(control1: CGPoint(x: 62.5, y: 179.5), control2: CGPoint(x: 61.8, y: 174.2), end: CGPoint(x: 61.2, y: 169.3)),
        .init(control1: CGPoint(x: 60.6, y: 164.4), control2: CGPoint(x: 60.3, y: 159.3), end: CGPoint(x: 60.2, y: 154.6)),
        .init(control1: CGPoint(x: 60.1, y: 149.9), control2: CGPoint(x: 60.4, y: 145.5), end: CGPoint(x: 60.7, y: 141.1)),
        .init(control1: CGPoint(x: 61, y: 136.7), control2: CGPoint(x: 61.5, y: 131.6), end: CGPoint(x: 62.2, y: 128.2)),
        .init(control1: CGPoint(x: 62.9, y: 124.8), control2: CGPoint(x: 63.1, y: 124.5), end: CGPoint(x: 65.1, y: 120.8)),
        .init(control1: CGPoint(x: 67.1, y: 117.1), control2: CGPoint(x: 70.5, y: 111), end: CGPoint(x: 74, y: 106.1)),
        .init(control1: CGPoint(x: 77.5, y: 101.2), control2: CGPoint(x: 81.7, y: 96.3), end: CGPoint(x: 86, y: 91.4)),
        .init(control1: CGPoint(x: 90.3, y: 86.5), control2: CGPoint(x: 95.2, y: 81.6), end: CGPoint(x: 99.9, y: 76.7)),
        .init(control1: CGPoint(x: 104.6, y: 71.8), control2: CGPoint(x: 109.3, y: 66.9), end: CGPoint(x: 114.1, y: 62)),
        .init(control1: CGPoint(x: 118.9, y: 57.1), control2: CGPoint(x: 124.6, y: 51), end: CGPoint(x: 128.8, y: 47.3)),
        .init(control1: CGPoint(x: 133, y: 43.6), control2: CGPoint(x: 136.7, y: 40), end: CGPoint(x: 139.1, y: 40)),
    ]

    /// A boot-shaped leg: straight sides, rounded heel, toe pointing left.
    public struct Leg: Sendable, Equatable {
        public let left: CGFloat
        public let right: CGFloat
        public let top: CGFloat
        public let bottom: CGFloat
        public let toe: CGFloat
    }

    public static let leftLeg = Leg(left: 91, right: 106.5, top: 206, bottom: 236, toe: 3.5)
    public static let rightLeg = Leg(left: 125.5, right: 142, top: 206, bottom: 242, toe: 3)

    /// A stubby arm: a curve from the shoulder to a round mitten hand.
    public struct Arm: Sendable, Equatable {
        public let shoulder: CGPoint
        public let control: CGPoint
        public let hand: CGPoint
        /// The point the arm rotates around.
        public let pivot: CGPoint
    }

    public static let armDownLeft = Arm(shoulder: CGPoint(x: 72, y: 170), control: CGPoint(x: 62, y: 180),
                                        hand: CGPoint(x: 58, y: 192), pivot: CGPoint(x: 72, y: 170))
    public static let armDownRight = Arm(shoulder: CGPoint(x: 172, y: 176), control: CGPoint(x: 182, y: 186),
                                         hand: CGPoint(x: 184, y: 198), pivot: CGPoint(x: 172, y: 176))
    public static let armUpLeft = Arm(shoulder: CGPoint(x: 70, y: 150), control: CGPoint(x: 50, y: 132),
                                      hand: CGPoint(x: 46, y: 110), pivot: CGPoint(x: 70, y: 152))
    public static let armUpRight = Arm(shoulder: CGPoint(x: 172, y: 150), control: CGPoint(x: 192, y: 132),
                                       hand: CGPoint(x: 196, y: 110), pivot: CGPoint(x: 172, y: 152))
    /// Holds the product up on the left, like the original art.
    public static let armHoldProduct = Arm(shoulder: CGPoint(x: 70, y: 176), control: CGPoint(x: 52, y: 182),
                                           hand: CGPoint(x: 40, y: 172), pivot: CGPoint(x: 70, y: 176))
    /// Crosses the belly, scanner in hand, pointed at the product.
    public static let armHoldScanner = Arm(shoulder: CGPoint(x: 174, y: 186), control: CGPoint(x: 134, y: 212),
                                           hand: CGPoint(x: 104, y: 194), pivot: CGPoint(x: 174, y: 186))

    public static let armOutlineWidth: CGFloat = 13
    public static let armFillWidth: CGFloat = 8.6
    public static let handRadius: CGFloat = 7.5
    public static let lineWidth: CGFloat = 2.2

    // Face, three-quarter view as in the original: eyes and mouth sit left of centre.
    public static let leftEye = CGRect(x: 82.4 - 6.3, y: 136.9 - 6.8, width: 12.6, height: 13.6)
    public static let rightEye = CGRect(x: 129.7 - 6.7, y: 143.2 - 6.8, width: 13.4, height: 13.6)
    public static let mouthLeft = CGPoint(x: 93, y: 146)
    public static let mouthRight = CGPoint(x: 115, y: 146)
    public static let smileControl = CGPoint(x: 104, y: 162)
    public static let frownControl = CGPoint(x: 104, y: 146)
    public static let blush = CGRect(x: 140.8 - 11, y: 157.3 - 5.4, width: 22, height: 10.8)
    public static let shineTop = CGPoint(x: 121, y: 64)
    public static let shineBottom = CGPoint(x: 86, y: 110)
    public static let shineOuter = CGPoint(x: 109.1, y: 91.2)
    public static let shineInner = CGPoint(x: 97.9, y: 82.8)
    public static let shadow = CGRect(x: 120 - 46, y: 234, width: 92, height: 12)

    /// The dropper bottle held in the scan pose: glass, collar, bulb; tilted like the original.
    public static let productGlass = CGRect(x: 32, y: 128, width: 48, height: 62)
    public static let productCollar = CGRect(x: 45, y: 113, width: 22, height: 17)
    public static let productBulb = CGRect(x: 48, y: 93, width: 16, height: 22)
    public static let productTiltDegrees: Double = -14
    public static let productPivot = CGPoint(x: 56, y: 160)
    /// The scanner in the right hand: body and its red read window.
    public static let scannerBody = CGRect(x: 80, y: 180, width: 28, height: 15)
    public static let scannerWindow = CGRect(x: 80, y: 183, width: 5, height: 9)

    public struct Sparkle: Sendable, Equatable {
        public let center: CGPoint
        public let size: CGFloat
    }

    /// Sparkles around the jump, in design space.
    public static let sparkles: [Sparkle] = [
        Sparkle(center: CGPoint(x: 34, y: 62), size: 20), Sparkle(center: CGPoint(x: 198, y: 44), size: 16),
        Sparkle(center: CGPoint(x: 212, y: 122), size: 12), Sparkle(center: CGPoint(x: 24, y: 150), size: 12),
    ]
}
