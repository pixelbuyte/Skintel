import Foundation

/// The editable vector rig in `Resources/MascotRig.json`: paths, colors, pivots and
/// proportions on a 420 × 510 design space. Foundation only, so it can be checked anywhere.
struct MascotRig: Decodable, Sendable {
    let canvas: [Double]
    let outlineWidth: Double
    let colors: [String: String]
    let opacity: [String: Double]
    let strokeWidths: [String: Double]
    let paths: [String: String]
    let ellipses: [String: [Double]]
    let pivots: [String: [Double]]
    /// Shoulder shift `[dx, dy]` for a fully raised arm. Optional; missing means no shift.
    let armRaise: [String: [Double]]?
    let bodyGradient: [Double]
    let bottleTilt: Double
    let scanLine: [Double]
    let scanTravel: Double
    let sparkleOrbit: [Double]
    let sleepZStart: [Double]

    static func decode(_ data: Data) throws -> MascotRig {
        try JSONDecoder().decode(MascotRig.self, from: data)
    }

    var width: Double { canvas.first ?? 420 }
    var height: Double { canvas.count > 1 ? canvas[1] : 510 }
}

/// One drawing command from an SVG path string (absolute coordinates only).
enum MascotPathCommand: Equatable, Sendable {
    case move(x: Double, y: Double)
    case line(x: Double, y: Double)
    case quad(cx: Double, cy: Double, x: Double, y: Double)
    case cubic(c1x: Double, c1y: Double, c2x: Double, c2y: Double, x: Double, y: Double)
    case close
}

enum MascotPathError: Error, Equatable {
    case unsupportedCommand(Character)
    case missingNumbers(Character)
    case numberBeforeCommand
}

/// Reads the subset of SVG path data the rig uses: `M`, `L`, `Q`, `C` and `Z`, absolute,
/// separated by spaces or commas.
enum MascotPathParser {
    static func parse(_ data: String) throws -> [MascotPathCommand] {
        var commands: [MascotPathCommand] = []
        var op: Character?
        var numbers: [Double] = []

        func flush() throws {
            guard let op else {
                if !numbers.isEmpty { throw MascotPathError.numberBeforeCommand }
                return
            }
            let arity: Int
            switch op {
            case "M", "L": arity = 2
            case "Q": arity = 4
            case "C": arity = 6
            case "Z": arity = 0
            default: throw MascotPathError.unsupportedCommand(op)
            }
            if arity == 0 {
                guard numbers.isEmpty else { throw MascotPathError.missingNumbers(op) }
                commands.append(.close)
                return
            }
            guard !numbers.isEmpty, numbers.count % arity == 0 else { throw MascotPathError.missingNumbers(op) }
            // Repeated coordinate groups after one letter continue that command (after M, as lines).
            var index = 0
            while index < numbers.count {
                let v = Array(numbers[index..<(index + arity)])
                switch op {
                case "M": commands.append(index == 0 ? .move(x: v[0], y: v[1]) : .line(x: v[0], y: v[1]))
                case "L": commands.append(.line(x: v[0], y: v[1]))
                case "Q": commands.append(.quad(cx: v[0], cy: v[1], x: v[2], y: v[3]))
                default: commands.append(.cubic(c1x: v[0], c1y: v[1], c2x: v[2], c2y: v[3], x: v[4], y: v[5]))
                }
                index += arity
            }
        }

        var token = ""
        func endNumber() throws {
            guard !token.isEmpty else { return }
            guard let value = Double(token) else { throw MascotPathError.missingNumbers(op ?? "?") }
            numbers.append(value)
            token = ""
        }

        for character in data {
            if character.isLetter {
                guard "MLQCZ".contains(character) else { throw MascotPathError.unsupportedCommand(character) }
                try endNumber()
                try flush()
                op = character
                numbers = []
            } else if character == "-" {
                try endNumber()
                token = "-"
            } else if character.isNumber || character == "." {
                token.append(character)
            } else {
                try endNumber()
            }
        }
        try endNumber()
        try flush()
        return commands
    }
}

/// The rig with every path parsed once, ready to draw.
struct MascotArt: Sendable {
    let rig: MascotRig
    let shapes: [String: [MascotPathCommand]]

    init(rig: MascotRig) throws {
        self.rig = rig
        var shapes: [String: [MascotPathCommand]] = [:]
        for (name, data) in rig.paths { shapes[name] = try MascotPathParser.parse(data) }
        self.shapes = shapes
    }

    /// Every part the renderer draws. A rig edited in JSON must keep these names.
    static let requiredPaths = [
        "body", "shade", "shine", "leftFoot", "rightFoot", "leftArm", "rightArm", "smile",
        "thinkingMouth", "happyLeft", "happyRight", "bottle", "serum", "glassShine", "cap", "bulb",
        "pipette", "labelDrop", "hug", "cradle", "scanFrame", "sleepZ",
    ]
    static let requiredEllipses = [
        "shadow", "leftEye", "rightEye", "leftBlush", "rightBlush", "sleepMouth",
        "thought1", "thought2", "thought3",
    ]
    static let requiredPivots = ["body", "leftFoot", "rightFoot", "leftArm", "rightArm", "bottle"]

    /// Names the renderer needs that the rig doesn't define. Empty for a complete rig.
    var missingParts: [String] {
        Self.requiredPaths.filter { shapes[$0] == nil }
            + Self.requiredEllipses.filter { (rig.ellipses[$0]?.count ?? 0) < 4 }
            + Self.requiredPivots.filter { (rig.pivots[$0]?.count ?? 0) < 2 }
    }

    func ellipse(_ name: String) -> (cx: Double, cy: Double, rx: Double, ry: Double) {
        guard let e = rig.ellipses[name], e.count >= 4 else { return (0, 0, 0, 0) }
        return (e[0], e[1], e[2], e[3])
    }

    func pivot(_ name: String) -> (x: Double, y: Double) {
        guard let p = rig.pivots[name], p.count >= 2 else { return (rig.width / 2, rig.height / 2) }
        return (p[0], p[1])
    }

    /// Shoulder shift for arm `name` when raised by `amount` (0…1).
    func raise(_ name: String, by amount: Double) -> (x: Double, y: Double) {
        guard amount > 0, let r = rig.armRaise?[name], r.count >= 2 else { return (0, 0) }
        return (r[0] * amount, r[1] * amount)
    }

    func opacity(_ name: String, _ fallback: Double = 1) -> Double { rig.opacity[name] ?? fallback }
    func stroke(_ name: String) -> Double { rig.strokeWidths[name] ?? rig.outlineWidth }

    /// `#RRGGBB` → 0…1 components. Unknown names fall back to the outline ink.
    func rgb(_ name: String) -> (red: Double, green: Double, blue: Double) {
        let hex = rig.colors[name] ?? rig.colors["ink"] ?? "#492C34"
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }
}
