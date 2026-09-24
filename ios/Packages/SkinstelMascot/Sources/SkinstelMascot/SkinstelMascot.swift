import Foundation
import SwiftUI

/// A lightweight vector character, animated on device. No API, GIF, video or image frames.
public enum MascotAction: String, CaseIterable, Identifiable, Sendable {
    case idle, walk, wave, scan, celebrate
    public var id: String { rawValue }
}

public struct SkinstelMascot: View {
    public let action: MascotAction
    public let isPlaying: Bool
    public let travels: Bool
    public let facingLeft: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var accumulated: TimeInterval = 0
    @State private var started: Date?

    /// Set `travels` to walk back and forth inside the view's available width.
    /// Keep the view at least 120 points high. Set `isPlaying` false in retained offscreen tabs.
    public init(action: MascotAction = .idle, isPlaying: Bool = true,
                travels: Bool = false, facingLeft: Bool = false) {
        self.action = action
        self.isPlaying = isPlaying
        self.travels = travels
        self.facingLeft = facingLeft
    }

    private var running: Bool { visible && isPlaying && !reduceMotion && scenePhase == .active }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !running)) { timeline in
            let t = reduceMotion ? 0 : accumulated + (started.map { timeline.date.timeIntervalSince($0) } ?? 0)
            Canvas { context, size in
                draw(in: &context, size: size, time: max(0, t), animate: !reduceMotion)
            }
        }
        .accessibilityHidden(true) // Host supplies real loading/error text; character is decorative.
        .allowsHitTesting(false)
        .onAppear { visible = true; synchronizeClock() }
        .onDisappear { visible = false; synchronizeClock() }
        .onChange(of: running) { _, _ in synchronizeClock() }
        .onChange(of: action) { _, _ in
            accumulated = 0
            started = running ? Date() : nil
        }
    }

    private func synchronizeClock() {
        if running {
            if started == nil { started = Date() }
        } else if let start = started {
            accumulated += Date().timeIntervalSince(start)
            started = nil
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: Double, animate: Bool) {
        let scale = min(size.width / 320, size.height / 400)
        guard scale > 0 else { return }
        let pose = MascotPose(action: action, time: time, animate: animate)
        let span = max(0, size.width - 320 * scale)
        let moving = animate && action == .walk && travels && span > 0
        // Constant travel speed; reverse direction only at the ends of the available track.
        let distance = moving ? time * 70 * scale : 0
        let phase = moving ? distance.truncatingRemainder(dividingBy: span * 2) : 0
        let returning = moving && phase > span
        let x = moving ? (returning ? span * 2 - phase : phase) : span / 2
        context.translateBy(x: x + 160 * scale, y: (size.height - 400 * scale) / 2)
        context.scaleBy(x: scale * ((returning != facingLeft) ? -1 : 1), y: scale)
        context.translateBy(x: -160, y: 0)
        // Ground stays still while the body moves.
        context.fill(Path(ellipseIn: CGRect(x: 96, y: 374, width: 138, height: 13)), with: .color(.black.opacity(0.08)))
        context.translateBy(x: 160, y: 332 + pose.bob)
        context.rotate(by: .degrees(pose.lean))
        context.scaleBy(x: 1, y: pose.breath)
        context.translateBy(x: -160, y: -332)
        for part in MascotArt.parts {
            var layer = context
            let pivot = part.pivot
            layer.translateBy(x: pivot[0], y: pivot[1])
            switch part.name {
            case "leftLeg": layer.rotate(by: .degrees(pose.leftLeg))
            case "rightLeg": layer.rotate(by: .degrees(pose.rightLeg))
            case "rightArm": layer.rotate(by: .degrees(pose.arm))
            case "leftEye", "rightEye": layer.scaleBy(x: 1, y: pose.eye)
            default: break
            }
            layer.translateBy(x: -pivot[0], y: -pivot[1])
            if !part.fill.isEmpty { layer.fill(part.path, with: .color(Color(mascotHex: part.fill))) }
            if !part.stroke.isEmpty {
                layer.stroke(part.path, with: .color(Color(mascotHex: part.stroke)),
                             style: StrokeStyle(lineWidth: part.width, lineCap: .round, lineJoin: .round))
            }
        }
        if action == .scan {
            let y = animate ? 246 + sin(time * 3) * 20 : 246
            let line = Path { p in p.move(to: CGPoint(x: 57, y: y)); p.addLine(to: CGPoint(x: 117, y: y)) }
            context.stroke(line, with: .color(Color(mascotHex: "#A35848")), lineWidth: 3)
        }
        if action == .celebrate {
            for i in 0..<5 {
                let a = Double(i) * .pi / 4 + .pi
                let r = animate ? 112 + sin(time * 4 + Double(i)) * 9 : 112
                let center = CGPoint(x: 166 + cos(a) * r, y: 165 + sin(a) * r)
                let spark = Path { p in
                    p.move(to: CGPoint(x: center.x - 4, y: center.y)); p.addLine(to: CGPoint(x: center.x + 4, y: center.y))
                    p.move(to: CGPoint(x: center.x, y: center.y - 4)); p.addLine(to: CGPoint(x: center.x, y: center.y + 4))
                }
                context.stroke(spark, with: .color(Color(mascotHex: "#BB8B3D")), lineWidth: 2)
            }
        }
    }
}

private struct MascotPose {
    var leftLeg = 0.0, rightLeg = 0.0, bob = 0.0, lean = 0.0, arm = 0.0
    var breath = 1.0, eye = 1.0
    init(action: MascotAction, time: Double, animate: Bool) {
        guard animate else { return }
        let step = sin(time * 2 * .pi / 0.8)
        let blink = time.truncatingRemainder(dividingBy: 4.2)
        if blink > 3.95 { eye = max(0.08, abs(blink - 4.075) / 0.125) }
        switch action {
        case .idle: breath = 1 + sin(time * 2) * 0.012
        case .walk:
            leftLeg = step * 24; rightLeg = -step * 24
            bob = -abs(step) * 5; lean = step * 1.2
        case .wave: arm = 110 + sin(time * 7) * 14; breath = 1 + sin(time * 2) * 0.008
        case .scan: lean = sin(time * 2) * 2; breath = 1 + sin(time * 2) * 0.008
        case .celebrate:
            bob = -abs(sin(time * 4)) * 15; arm = 100 + sin(time * 6) * 10
            leftLeg = -sin(time * 4) * 8; rightLeg = sin(time * 4) * 8
        }
    }
}

private enum MascotArt {
    static let parts: [RigPart] = {
        guard let url = Bundle.module.url(forResource: "MascotRig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parts = try? JSONDecoder().decode([RigPart].self, from: data) else {
            assertionFailure("SkinstelMascot: missing or invalid bundled MascotRig.json")
            return []
        }
        return parts
    }()
}

private struct RigPart: Decodable {
    let name: String, fill: String, stroke: String
    let width: Double
    let pivot: [Double]
    let commands: [Command]
    struct Command: Decodable { let op: String; let values: [Double] }
    var path: Path {
        Path { p in
            for c in commands {
                let v = c.values
                switch c.op {
                case "M": p.move(to: CGPoint(x: v[0], y: v[1]))
                case "L": p.addLine(to: CGPoint(x: v[0], y: v[1]))
                case "Q": p.addQuadCurve(to: CGPoint(x: v[2], y: v[3]), control: CGPoint(x: v[0], y: v[1]))
                case "C": p.addCurve(to: CGPoint(x: v[4], y: v[5]), control1: CGPoint(x: v[0], y: v[1]), control2: CGPoint(x: v[2], y: v[3]))
                case "Z": p.closeSubpath()
                default: break
                }
            }
        }
    }
}

private extension Color {
    init(mascotHex: String) {
        let hex = UInt32(mascotHex.dropFirst(), radix: 16) ?? 0
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

/// Standalone Xcode preview/playground. It has no app, auth or network dependency.
public struct MascotPlayground: View {
    @State private var action: MascotAction = .walk
    @State private var playing = true
    @State private var travel = true
    public init() {}
    public var body: some View {
        VStack(spacing: 24) {
            Text("Meet your skincare companion").font(.title2.bold())
            SkinstelMascot(action: action, isPlaying: playing, travels: travel)
                .frame(height: 280)
            Picker("Action", selection: $action) {
                ForEach(MascotAction.allCases) { action in Text(action.rawValue.capitalized).tag(action) }
            }.pickerStyle(.menu)
            Toggle("Walk across the screen", isOn: $travel)
            Button(playing ? "Pause" : "Play") { playing.toggle() }.buttonStyle(.borderedProminent)
        }
        .padding(24)
        .tint(Color(mascotHex: "#A35848"))
        .background(Color(mascotHex: "#F4EDE0"))
    }
}

#Preview { MascotPlayground() }
