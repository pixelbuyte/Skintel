import Foundation

/// What the droplet is doing.
public enum MascotAction: String, CaseIterable, Identifiable, Sendable {
    case idle, walk, wave, scan, celebrate

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .idle: "Idle"
        case .walk: "Walk"
        case .wave: "Wave"
        case .scan: "Scan"
        case .celebrate: "Celebrate"
        }
    }

    /// Seconds for one loop of the action's motion.
    public var period: Double {
        switch self {
        case .idle: 2.8
        case .walk: 0.9
        case .wave: 1.0
        case .scan: 1.6
        case .celebrate: 1.1
        }
    }
}

/// How the face reads, independent of the action.
public enum MascotMood: String, CaseIterable, Sendable {
    case happy, worried
}

public enum ArmStyle: Sendable, Equatable {
    case down, up, holdProduct, holdScanner
}

public struct ArmPose: Sendable, Equatable {
    public var style: ArmStyle
    /// Degrees around the arm's pivot; positive turns clockwise on screen.
    public var angle: Double

    public init(_ style: ArmStyle, angle: Double = 0) {
        self.style = style
        self.angle = angle
    }
}

public struct LegPose: Sendable, Equatable {
    /// How far the foot is off the floor, in design units.
    public var lift: Double = 0
    /// Horizontal step, in design units; negative is forward (the droplet faces left).
    public var stride: Double = 0

    public init(lift: Double = 0, stride: Double = 0) {
        self.lift = lift
        self.stride = stride
    }
}

/// Every moving part at one instant, in design units (see `MascotGeometry`).
public struct MascotPose: Sendable, Equatable {
    /// Body height above the floor.
    public var lift: Double = 0
    /// Squash and stretch around the feet: > 0 wider and shorter, < 0 taller and narrower.
    public var squash: Double = 0
    /// Lean in degrees around the feet.
    public var tilt: Double = 0
    public var leftArm = ArmPose(.down)
    public var rightArm = ArmPose(.down)
    public var leftLeg = LegPose()
    public var rightLeg = LegPose()
    /// 1 open, near 0 mid-blink.
    public var eyesOpen: Double = 1
    /// 0..<1 progress of the action's effect (scan sweep, sparkle twinkle).
    public var effect: Double = 0

    public init() {}
}

/// Turns an action and a time into a pose. Pure and deterministic, so the same time
/// always draws the same frame and any loop can be tested.
public enum MascotRig {
    /// Seconds between blinks, and how long the eyes stay shut.
    public static let blinkEvery = 3.6
    public static let blinkLength = 0.16
    /// Peak jump height while celebrating.
    public static let jumpHeight = 34.0

    public static func pose(for action: MascotAction, at time: Double) -> MascotPose {
        var pose = MascotPose()
        let phase = fraction(time / action.period)
        let angle = 2 * Double.pi * phase

        switch action {
        case .idle:
            breathe(&pose, at: time)
            pose.leftArm.angle = 3 * sin(2 * .pi * time / MascotAction.idle.period)
            pose.rightArm.angle = -pose.leftArm.angle

        case .walk:
            // Each foot lifts while it swings forward (to the left); arms swing against the legs.
            pose.leftLeg = LegPose(lift: max(0, -sin(angle)) * 7, stride: -cos(angle) * 5)
            pose.rightLeg = LegPose(lift: max(0, sin(angle)) * 7, stride: cos(angle) * 5)
            pose.lift = abs(sin(angle)) * 3
            pose.tilt = 2.5 * sin(angle)
            pose.leftArm.angle = -14 * cos(angle)
            pose.rightArm.angle = 14 * cos(angle)

        case .wave:
            breathe(&pose, at: time)
            pose.tilt = -2
            pose.rightArm = ArmPose(.up, angle: 6 + 20 * sin(angle))

        case .scan:
            breathe(&pose, at: time)
            pose.tilt = sin(angle)
            pose.leftArm = ArmPose(.holdProduct)
            pose.rightArm = ArmPose(.holdScanner, angle: 2 * sin(angle))
            pose.effect = phase

        case .celebrate:
            let airborne = 0.62
            if phase < airborne {
                let up = sin(.pi * phase / airborne)
                pose.lift = jumpHeight * up
                pose.squash = -0.06 * up
                pose.leftLeg.lift = 4 * up
                pose.rightLeg.lift = 4 * up
            } else {
                pose.squash = 0.1 * sin(.pi * (phase - airborne) / (1 - airborne))
            }
            let swing = 10 + 12 * sin(angle)
            pose.leftArm = ArmPose(.up, angle: -swing)
            pose.rightArm = ArmPose(.up, angle: swing)
            pose.effect = phase
        }

        pose.eyesOpen = eyesOpen(at: time)
        return pose
    }

    /// One held frame per action for Reduce Motion and paused states: recognisable, no motion.
    public static func still(for action: MascotAction) -> MascotPose {
        var pose = MascotPose()
        switch action {
        case .idle:
            break
        case .walk:
            pose.leftLeg.stride = -3
            pose.rightLeg.stride = 3
        case .wave:
            pose.rightArm = ArmPose(.up, angle: 16)
        case .scan:
            pose.leftArm = ArmPose(.holdProduct)
            pose.rightArm = ArmPose(.holdScanner)
            pose.effect = 0.5
        case .celebrate:
            pose.leftArm = ArmPose(.up, angle: -18)
            pose.rightArm = ArmPose(.up, angle: 18)
            pose.effect = 0.25
        }
        return pose
    }

    public static func eyesOpen(at time: Double) -> Double {
        let t = fraction(time / blinkEvery) * blinkEvery
        return t >= blinkEvery - blinkLength ? 0.1 : 1
    }

    /// Slow breath: a little taller on the way in, settling on the way out.
    private static func breathe(_ pose: inout MascotPose, at time: Double) {
        let b = sin(2 * .pi * time / MascotAction.idle.period)
        pose.squash = -0.02 * b
        pose.lift = 1.5 * max(0, b)
    }

    /// The fractional part in 0..<1, also for negative times.
    static func fraction(_ x: Double) -> Double {
        let f = x - x.rounded(.down)
        return f >= 1 ? 0 : f
    }
}
