import SwiftUI

/// Skinstel's terracotta droplet, drawn and animated on device from the vector rig in
/// `Resources/MascotRig.json`. No images, video, network or third-party runtime.
///
/// The host owns `action` and should set it from real app state. The mascot is decorative:
/// it is hidden from VoiceOver, so keep visible text beside it that says what is happening.
///
/// The clock runs only while the view is on screen, the scene is active and `isPlaying` is
/// true; pausing holds the current pose. Reduce Motion shows each action's stable pose.
public struct SkinstelMascot: View {
    public let action: SkinstelMascotAction
    public let isPlaying: Bool
    public let travels: Bool
    public let facingLeft: Bool
    public let playbackID: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var accumulated: TimeInterval = 0
    @State private var started: Date?

    /// - Parameters:
    ///   - action: What the mascot is doing.
    ///   - isPlaying: `false` pauses on the current pose. Use it for views kept alive off screen,
    ///     such as a retained tab or an off-screen page.
    ///   - travels: With `.walk`, walks back and forth across the frame's spare width.
    ///   - facingLeft: Mirrors the character.
    ///   - playbackID: Change it to restart the current action from the beginning.
    public init(action: SkinstelMascotAction = .idle, isPlaying: Bool = true,
                travels: Bool = false, facingLeft: Bool = false, playbackID: Int = 0) {
        self.action = action
        self.isPlaying = isPlaying
        self.travels = travels
        self.facingLeft = facingLeft
        self.playbackID = playbackID
    }

    private var running: Bool { visible && isPlaying && !reduceMotion && scenePhase == .active }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !running)) { timeline in
            let still = reduceMotion
            let elapsed = started.map { max(0, timeline.date.timeIntervalSince($0)) } ?? 0
            let time = still ? 0 : accumulated + elapsed
            let currentAction = action
            let walksAcross = travels
            let mirrored = facingLeft
            Canvas { context, size in
                MascotRenderer.draw(in: &context, size: size, time: time, action: currentAction,
                                    still: still, travels: walksAcross, facingLeft: mirrored)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            visible = true
            synchronizeClock()
        }
        .onDisappear {
            visible = false
            synchronizeClock()
        }
        .onChange(of: running) { _, _ in synchronizeClock() }
        .onChange(of: action) { _, _ in restartClock() }
        .onChange(of: playbackID) { _, _ in restartClock() }
    }

    private func synchronizeClock() {
        if running {
            if started == nil { started = Date() }
        } else if let start = started {
            accumulated += Date().timeIntervalSince(start)
            started = nil
        }
    }

    private func restartClock() {
        accumulated = 0
        started = running ? Date() : nil
    }
}

/// Draws one frame of the rig into a Canvas. Stateless and nonisolated, so the Canvas
/// renderer can call it from any context.
enum MascotRenderer {
    static let art: MascotArt? = {
        guard let url = Bundle.module.url(forResource: "MascotRig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rig = try? MascotRig.decode(data),
              let art = try? MascotArt(rig: rig) else {
            assertionFailure("SkinstelMascot: Resources/MascotRig.json is missing or invalid")
            return nil
        }
        assert(art.missingParts.isEmpty, "SkinstelMascot: MascotRig.json lacks \(art.missingParts)")
        return art
    }()

    static func draw(in context: inout GraphicsContext, size: CGSize, time: Double,
                     action: SkinstelMascotAction, still: Bool, travels: Bool, facingLeft: Bool) {
        guard let art else { return }
        let rig = art.rig
        let width = Double(size.width), height = Double(size.height)
        let scale = min(width / rig.width, height / rig.height)
        guard scale > 0, scale.isFinite else { return }
        let t = still ? 0 : time
        let pose = MascotPose(action: action, time: t, reduced: still)
        let span = max(0, width - rig.width * scale)
        let placement = MascotMotion.placement(time: t, span: span, scale: scale,
                                               moving: !still && travels && action == .walk,
                                               facingLeft: facingLeft)

        context.translateBy(x: CGFloat(placement.x + rig.width * scale / 2),
                            y: CGFloat((height - rig.height * scale) / 2))
        context.scaleBy(x: CGFloat(placement.mirrored ? -scale : scale), y: CGFloat(scale))
        context.translateBy(x: CGFloat(-rig.width / 2), y: 0)

        let ink = color("ink", art)
        let skin = color("skin", art)

        // Ground shadow stays put and shrinks while the body is in the air.
        let shadow = art.ellipse("shadow")
        context.fill(ellipse(cx: shadow.cx, cy: shadow.cy, rx: shadow.rx + pose.bob * 0.65, ry: shadow.ry),
                     with: .color(color("ink", art, opacity: art.opacity("shadow", 0.1))))

        if MascotMotion.showsSparkles(action) {
            let orbit = rig.sparkleOrbit.count >= 4 ? rig.sparkleOrbit : [205, 242, 160, 151]
            let tint = color(action == .scan ? "scan" : "sparkle", art)
            for index in 0..<5 {
                let s = MascotMotion.sparkle(index, time: t)
                let x = orbit[0] + s.cos * orbit[2], y = orbit[1] + s.sin * orbit[3]
                var cross = Path()
                cross.move(to: CGPoint(x: x - s.size, y: y))
                cross.addLine(to: CGPoint(x: x + s.size, y: y))
                cross.move(to: CGPoint(x: x, y: y - s.size))
                cross.addLine(to: CGPoint(x: x, y: y + s.size))
                context.stroke(cross, with: .color(tint),
                               style: StrokeStyle(lineWidth: CGFloat(art.stroke("sparkle")), lineCap: .round))
            }
        }

        // Body rig: bob, lean and breathe around the point between the feet.
        var body = context
        let bodyPivot = art.pivot("body")
        body.translateBy(x: 0, y: CGFloat(pose.bob))
        body.translateBy(x: CGFloat(bodyPivot.x), y: CGFloat(bodyPivot.y))
        body.rotate(by: .degrees(pose.lean))
        body.scaleBy(x: CGFloat(1 / pose.breathe), y: CGFloat(pose.breathe))
        body.translateBy(x: CGFloat(-bodyPivot.x), y: CGFloat(-bodyPivot.y))

        var limb = rotated(body, pose.leftLeg, around: art.pivot("leftFoot"))
        outlined(path("leftFoot", art), fill: skin, ink: ink, width: rig.outlineWidth, in: &limb)
        limb = rotated(body, pose.rightLeg, around: art.pivot("rightFoot"))
        outlined(path("rightFoot", art), fill: skin, ink: ink, width: rig.outlineWidth, in: &limb)

        let droplet = path("body", art)
        let g = rig.bodyGradient.count >= 4 ? rig.bodyGradient : [72, 36, 353, 446]
        body.fill(droplet, with: .linearGradient(
            Gradient(stops: [
                Gradient.Stop(color: color("skinLight", art), location: 0),
                Gradient.Stop(color: skin, location: 0.7),
                Gradient.Stop(color: color("skinDeep", art), location: 1),
            ]),
            startPoint: CGPoint(x: g[0], y: g[1]), endPoint: CGPoint(x: g[2], y: g[3])))
        outlined(droplet, fill: nil, ink: ink, width: rig.outlineWidth, in: &body)
        body.fill(path("shade", art), with: .color(color("shade", art, opacity: art.opacity("shade"))))
        body.fill(path("shine", art), with: .color(color("shine", art, opacity: art.opacity("shine"))))
        let blush = color("blush", art, opacity: art.opacity("blush"))
        for name in ["leftBlush", "rightBlush"] {
            let e = art.ellipse(name)
            body.fill(ellipse(cx: e.cx, cy: e.cy, rx: e.rx, ry: e.ry), with: .color(blush))
        }

        // Face.
        let faceStroke = StrokeStyle(lineWidth: CGFloat(art.stroke("face")), lineCap: .round, lineJoin: .round)
        if action == .celebrate {
            body.stroke(path("happyLeft", art), with: .color(ink), style: faceStroke)
            body.stroke(path("happyRight", art), with: .color(ink), style: faceStroke)
        } else {
            for name in ["leftEye", "rightEye"] {
                let e = art.ellipse(name)
                body.fill(ellipse(cx: e.cx + pose.lookX, cy: e.cy + pose.lookY, rx: e.rx, ry: e.ry * pose.blink),
                          with: .color(ink))
            }
        }
        switch action {
        case .sleep:
            let m = art.ellipse("sleepMouth")
            body.fill(ellipse(cx: m.cx, cy: m.cy, rx: m.rx, ry: m.ry), with: .color(ink))
        case .thinking:
            body.stroke(path("thinkingMouth", art), with: .color(ink), style: faceStroke)
        default:
            body.stroke(path("smile", art), with: .color(ink), style: faceStroke)
        }

        // Arms, or the bottle hugged close.
        if MascotMotion.holdsBottle(action) {
            var bottle = rotated(body, rig.bottleTilt, around: art.pivot("bottle"))
            outlined(path("bottle", art), fill: color("glass", art), ink: ink, width: rig.outlineWidth, in: &bottle)
            bottle.fill(path("serum", art), with: .color(color("serum", art)))
            bottle.stroke(path("glassShine", art),
                          with: .color(color("glassShine", art, opacity: art.opacity("glassShine"))),
                          style: StrokeStyle(lineWidth: CGFloat(art.stroke("glassShine")), lineCap: .round))
            outlined(path("bulb", art), fill: skin, ink: ink, width: rig.outlineWidth, in: &bottle)
            outlined(path("cap", art), fill: color("cap", art), ink: ink, width: rig.outlineWidth, in: &bottle)
            bottle.stroke(path("pipette", art), with: .color(ink), lineWidth: CGFloat(art.stroke("pipette")))
            outlined(path("labelDrop", art), fill: color("label", art), ink: ink, width: art.stroke("label"), in: &bottle)
            outlined(path("hug", art), fill: skin, ink: ink, width: rig.outlineWidth, in: &body)
            outlined(path("cradle", art), fill: skin, ink: ink, width: rig.outlineWidth, in: &body)
        } else {
            for (name, angle, lift) in [("leftArm", pose.leftArm, pose.leftArmRaise),
                                        ("rightArm", pose.rightArm, pose.rightArmRaise)] {
                let shift = art.raise(name, by: lift)
                var arm = body
                arm.translateBy(x: CGFloat(shift.x), y: CGFloat(shift.y))
                arm = rotated(arm, angle, around: art.pivot(name))
                outlined(path(name, art), fill: skin, ink: ink, width: rig.outlineWidth, in: &arm)
            }
        }

        // Effects that stay level while the body moves.
        switch action {
        case .scan:
            let line = rig.scanLine.count >= 4 ? rig.scanLine : [52, 303, 110, 3]
            let y = line[1] + MascotMotion.scanPhase(time: t) * rig.scanTravel
            let scan = color("scan", art)
            context.fill(Path(roundedRect: CGRect(x: line[0], y: y, width: line[2], height: line[3]),
                              cornerRadius: CGFloat(line[3] / 2)),
                         with: .color(color("scan", art, opacity: art.opacity("scanLine", 0.8))))
            context.stroke(path("scanFrame", art), with: .color(scan), lineWidth: CGFloat(art.stroke("scanFrame")))
        case .thinking:
            for (index, name) in ["thought1", "thought2", "thought3"].enumerated() {
                let e = art.ellipse(name)
                let opacity = MascotMotion.thoughtOpacity(index, time: t, reduced: still)
                context.fill(ellipse(cx: e.cx, cy: e.cy, rx: e.rx, ry: e.ry), with: .color(color("ink", art, opacity: opacity)))
            }
        case .sleep:
            let start = rig.sleepZStart.count >= 2 ? rig.sleepZStart : [306, 172]
            let drift = MascotMotion.sleepDrift(time: t)
            var z = context
            z.translateBy(x: CGFloat(start[0]), y: CGFloat(start[1] - drift.rise))
            z.stroke(path("sleepZ", art), with: .color(color("sleep", art, opacity: drift.opacity)),
                     style: StrokeStyle(lineWidth: CGFloat(art.stroke("sleepZ")), lineCap: .round, lineJoin: .round))
        case .idle, .wave, .walk, .serum, .celebrate:
            break
        }
    }

    // MARK: Helpers

    private static func path(_ name: String, _ art: MascotArt) -> Path {
        var p = Path()
        for command in art.shapes[name] ?? [] {
            switch command {
            case let .move(x, y):
                p.move(to: CGPoint(x: x, y: y))
            case let .line(x, y):
                p.addLine(to: CGPoint(x: x, y: y))
            case let .quad(cx, cy, x, y):
                p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
            case let .cubic(c1x, c1y, c2x, c2y, x, y):
                p.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: c1x, y: c1y), control2: CGPoint(x: c2x, y: c2y))
            case .close:
                p.closeSubpath()
            }
        }
        return p
    }

    private static func ellipse(cx: Double, cy: Double, rx: Double, ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: max(0, rx * 2), height: max(0, ry * 2)))
    }

    private static func color(_ name: String, _ art: MascotArt, opacity: Double = 1) -> Color {
        let c = art.rgb(name)
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: opacity)
    }

    private static func rotated(_ context: GraphicsContext, _ degrees: Double,
                                around pivot: (x: Double, y: Double)) -> GraphicsContext {
        var result = context
        result.translateBy(x: CGFloat(pivot.x), y: CGFloat(pivot.y))
        result.rotate(by: .degrees(degrees))
        result.translateBy(x: CGFloat(-pivot.x), y: CGFloat(-pivot.y))
        return result
    }

    private static func outlined(_ path: Path, fill: Color?, ink: Color, width: Double,
                                 in context: inout GraphicsContext) {
        if let fill { context.fill(path, with: .color(fill)) }
        context.stroke(path, with: .color(ink),
                       style: StrokeStyle(lineWidth: CGFloat(width), lineCap: .round, lineJoin: .round))
    }
}
