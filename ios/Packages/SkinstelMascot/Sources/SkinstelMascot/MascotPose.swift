import Foundation

/// What the mascot is doing. Drive it from real app state; each action loops until the
/// host picks another one.
public enum SkinstelMascotAction: String, CaseIterable, Identifiable, Sendable {
    /// Gentle breathing and blinking.
    case idle
    /// Right arm raised, waving hello.
    case wave
    /// Alternating steps, arm swing and bounce. Pass `travels: true` to cross the frame.
    case walk
    /// Holds the serum bottle close while breathing.
    case serum
    /// Holds the bottle while a scan line and frame pass over it.
    case scan
    /// Hand to cheek, eyes up, three soft thought dots. For "working on an answer".
    case thinking
    /// Arms up, hop, happy eyes and sparkles. For a moment that really succeeded.
    case celebrate
    /// Eyes closed, small mouth, a drifting "z". For evening or rest.
    case sleep

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .idle: "Breathe"
        case .wave: "Wave"
        case .walk: "Walk"
        case .serum: "Hold serum"
        case .scan: "Scan"
        case .thinking: "Think"
        case .celebrate: "Celebrate"
        case .sleep: "Rest"
        }
    }
}

/// Every moving part for one moment of one action, in design units and degrees.
/// `reduced` gives each action's stable Reduce Motion pose (the same as time zero).
struct MascotPose: Equatable, Sendable {
    var bob = 0.0
    var lean = 0.0
    var leftLeg = 0.0
    var rightLeg = 0.0
    var leftArm = 0.0
    var rightArm = 0.0
    /// 0…1: how far each shoulder lifts out of the body for a raised arm (see `armRaise`).
    var leftArmRaise = 0.0
    var rightArmRaise = 0.0
    /// 1 = eyes open, near 0 = closed.
    var blink = 1.0
    /// Vertical stretch of the body; its width counter-scales so volume stays constant.
    var breathe = 1.0
    var lookX = 0.0
    var lookY = 0.0

    init(action: SkinstelMascotAction, time: Double, reduced: Bool) {
        let t = reduced ? 0 : max(0, time)
        let step = t * 2 * Double.pi / 0.8
        let breath = sin(t * 2.1)
        let walking = action == .walk
        let cheering = action == .celebrate

        bob = reduced ? 0 : walking ? -abs(sin(step)) * 7 : cheering ? -max(0, sin(t * 7)) * 22 : breath * 2.5
        lean = reduced ? 0 : walking ? sin(step) * 3 : cheering ? sin(t * 7) * 5 : breath * 0.8
        leftLeg = walking ? sin(step) * 18 : 0
        rightLeg = walking ? -sin(step) * 18 : 0
        leftArm = walking ? -sin(step) * 12 : cheering ? 130 + sin(t * 12) * 9 : 0
        switch action {
        case .wave: rightArm = 140 + sin(t * 12) * 16
        case .walk: rightArm = sin(step) * 12
        case .celebrate: rightArm = 145 + sin(t * 12) * 10
        case .thinking: rightArm = 42 + sin(t * 1.8) * 3
        case .idle, .serum, .scan, .sleep: rightArm = 0
        }
        leftArmRaise = cheering ? 1 : 0
        rightArmRaise = cheering || action == .wave ? 1 : 0
        let cycle = t.truncatingRemainder(dividingBy: 4.3)
        blink = action == .sleep ? 0.08 : reduced ? 1 : (cycle > 3.9 && cycle < 4.08) ? 0.1 : 1
        breathe = reduced ? 1 : 1 + breath * 0.006
        if action == .thinking {
            lookX = 4
            lookY = -5
        }
    }
}

/// Effects and travel that sit outside the body rig. Shared formulas with the browser preview.
enum MascotMotion {
    /// Holding the bottle replaces the free arms with the hugging pair.
    static func holdsBottle(_ action: SkinstelMascotAction) -> Bool {
        action == .serum || action == .scan
    }

    static func showsSparkles(_ action: SkinstelMascotAction) -> Bool {
        action == .celebrate || action == .scan
    }

    /// Scan line offset from its resting height, as a fraction (-1…1) of the rig's `scanTravel`.
    static func scanPhase(time t: Double) -> Double { sin(t * 2.8) }

    /// Sparkle `index` (0..<5) on its orbit: unit-circle position and half-length of each stroke.
    static func sparkle(_ index: Int, time t: Double) -> (cos: Double, sin: Double, size: Double) {
        let angle = Double(index) * 1.6 + t * 0.8
        return (cos(angle), sin(angle), 3 + 2 * sin(t * 4 + Double(index)))
    }

    /// Thought dot `index` (0..<3) fades in turn, rising from the head. Steady when reduced.
    static func thoughtOpacity(_ index: Int, time t: Double, reduced: Bool) -> Double {
        reduced ? 0.55 : 0.25 + 0.6 * max(0, sin(t * 3 - Double(index) * 0.9))
    }

    /// How far the "z" has floated up (0..<40) and its opacity.
    static func sleepDrift(time t: Double) -> (rise: Double, opacity: Double) {
        let rise = (t * 12).truncatingRemainder(dividingBy: 40)
        return (rise, 1 - rise / 60)
    }

    /// Horizontal offset inside a frame `span` points wider than the character, and whether
    /// to mirror. Walking with `travels` starts centered, walks at a constant speed and turns
    /// at each edge; everything else stays centered.
    static func placement(time t: Double, span: Double, scale: Double, moving: Bool,
                          facingLeft: Bool) -> (x: Double, mirrored: Bool) {
        guard moving, span > 0, scale > 0 else { return (span / 2, facingLeft) }
        let distance = t * 70 * scale + span / 2
        let phase = distance.truncatingRemainder(dividingBy: span * 2)
        let returning = phase > span
        return (returning ? span * 2 - phase : phase, returning != facingLeft)
    }
}
