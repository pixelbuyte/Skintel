import SwiftUI
import SkintelCore

private typealias MeshShade = SKMeshShade

/// A Canvas port of the canvas face renderer: painter-sorted flat shading, back-face culling, zone
/// heat from a Gaussian falloff around landmarks, a soft clay glow and label tags. Shaded like
/// porcelain for the light screens it sits on (ink wireframe, rose and clay heat), and mirrored
/// like a selfie: the person's right cheek is on the screen's right.
///
/// `.result` and `.scan` sway slowly on their own unless Reduce Motion is on, and drag turns them.
/// `.thumb` is a still map for small cards elsewhere (Today, You, Insights): no sway, no drag, no
/// labels, the zone glow on. Every mode keeps `FaceMeshView(mode:levels:labels:zoom:)`.
struct FaceMeshView: View {
    enum Mode: Sendable { case result, scan, thumb }

    var mode: Mode = .result
    var levels = FaceZoneLevels(levels: [:])
    var labels: [FaceMeshLabel] = []
    /// Fraction of the shorter side the face's half-height takes.
    var zoom: CGFloat = 0.38
    /// The yaw the face eases towards, in radians: positive is a turn to the person's own left
    /// (the sweep turns it per angle).
    var targetYaw: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragYaw: Double = 0
    @State private var dragStartYaw: Double = 0
    @State private var dragReleasedAt: Date?
    @State private var isDragging = false
    @State private var start = Date()

    /// Selfie convention: the model is drawn flipped left to right. Yaw keeps its meaning, so a
    /// turn to the person's left moves the nose to the screen's left, as in a mirror (and as in
    /// the sweep's mirrored camera).
    private static let mirror: Double = -1

    private var still: Bool { reduceMotion || mode == .thumb }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still && !isDragging)) { timeline in
            Canvas { context, size in
                guard let mesh = FaceMeshData.shared else { return }
                draw(mesh: mesh, in: &context, size: size, now: timeline.date)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartYaw = currentDragYaw(at: value.time)
                    }
                    // Mirrored: a drag to the right turns the face towards the screen's right.
                    let turn = Self.mirror * Double(value.translation.width) * 0.012
                    dragYaw = max(-1.1, min(1.1, dragStartYaw + turn))
                    dragReleasedAt = nil
                }
                .onEnded { value in
                    isDragging = false
                    dragReleasedAt = value.time
                }
        )
        // A thumbnail is a picture inside someone else's button: taps go through to it.
        .allowsHitTesting(mode != .thumb)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isImage)
    }

    private var accessibilityText: String {
        switch mode {
        case .scan: "Your face, being scanned"
        case .result: "3D map of your face, mirrored like a selfie, with zones highlighted"
        case .thumb: "3D map of your face"
        }
    }

    /// The drag offset, easing back to centre after release (the canvas decays it 4% a frame at 60 fps).
    private func currentDragYaw(at now: Date) -> Double {
        guard let released = dragReleasedAt, !reduceMotion else { return dragYaw }
        let dt = max(0, now.timeIntervalSince(released))
        return dragYaw * exp(-2.45 * dt)
    }

    private func draw(mesh: FaceMeshData, in context: inout GraphicsContext, size: CGSize, now: Date) {
        let cw = Double(size.width), ch = Double(size.height)
        guard cw > 0, ch > 0 else { return }
        let shade = Porcelain(context.environment)
        let t = now.timeIntervalSince(start)
        let still = self.still
        let swing = mode == .scan ? 0.1 : 0.4
        let yaw = targetYaw + (still ? 0 : sin(t * 0.5) * swing) + currentDragYaw(at: now)
        let pitch = -0.1 + (still ? 0 : sin(t * 0.37) * 0.04)
        let cyw = cos(yaw), syw = sin(yaw), cp = cos(pitch), sp = sin(pitch)
        let scale = min(cw, ch) * Double(zoom)
        let ox = cw / 2, oy = ch / 2 + ch * 0.01
        let n = mesh.vertexCount
        let P = mesh.positions
        let F = mesh.faces

        var RX = [Double](repeating: 0, count: n), RY = RX, RZ = RX, X = RX, Y = RX, H = RX
        let zoneLevels: [(weights: [Float], level: Double)] = FaceZone.allCases.compactMap { zone in
            let l = Double(levels.level(zone)) / 2
            guard l > 0, let w = mesh.weights[zone] else { return nil }
            return (w, l)
        }
        for i in 0..<n {
            let x = Double(P[i * 3]), y = Double(P[i * 3 + 1]), z = Double(P[i * 3 + 2])
            let x1 = x * cyw + z * syw, z1 = -x * syw + z * cyw
            let y2 = y * cp - z1 * sp, z2 = y * sp + z1 * cp
            RX[i] = x1; RY[i] = y2; RZ[i] = z2
            let k = 4.2 / (4.2 - z2)
            X[i] = ox + Self.mirror * x1 * scale * k
            Y[i] = oy - y2 * scale * k
            var h = 0.0
            for zl in zoneLevels {
                let v = zl.level * Double(zl.weights[i])
                if v > h { h = v }
            }
            H[i] = h
        }

        // Front faces wind one way on screen; mirroring X flips that way, so the sign follows it.
        var tris: [Int] = []
        tris.reserveCapacity(F.count / 3)
        var k = 0
        while k + 2 < F.count {
            let a = F[k], b = F[k + 1], c = F[k + 2]
            let cross = (X[b] - X[a]) * (Y[c] - Y[a]) - (Y[b] - Y[a]) * (X[c] - X[a])
            if cross * Self.mirror < 0 { tris.append(k) }
            k += 3
        }
        tris.sort { (RZ[F[$0]] + RZ[F[$0 + 1]] + RZ[F[$0 + 2]]) < (RZ[F[$1]] + RZ[F[$1 + 1]] + RZ[F[$1 + 2]]) }

        // The light stays at the screen's upper left once the picture is mirrored.
        let L = SIMD3<Double>(MeshShade.light.x * Self.mirror, MeshShade.light.y, MeshShade.light.z)
        let scanY = 1.15 - (t * 0.42).truncatingRemainder(dividingBy: 1) * 2.5
        let scanning = mode == .scan && !still

        for k in tris {
            let a = F[k], b = F[k + 1], c = F[k + 2]
            let ux = RX[b] - RX[a], uy = RY[b] - RY[a], uz = RZ[b] - RZ[a]
            let vx = RX[c] - RX[a], vy = RY[c] - RY[a], vz = RZ[c] - RZ[a]
            let nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx
            let nl = max((nx * nx + ny * ny + nz * nz).squareRoot(), 1e-9)
            let diff = max(0, (nx * L.x + ny * L.y + nz * L.z) / nl)
            let heat = min(1, ((H[a] + H[b] + H[c]) / 3) * 1.15)
            var rgb = lerp(shade.shade, shade.lit, diff)
            rgb = lerp(rgb, lerp(shade.warmShade, shade.warmLit, diff), heat)
            var edge = 0.05 + heat * 0.08
            if scanning {
                let my = (Double(P[a * 3 + 1]) + Double(P[b * 3 + 1]) + Double(P[c * 3 + 1])) / 3
                let d = abs(my - scanY)
                if d < 0.12 {
                    let f = 1 - d / 0.12
                    rgb = lerp(rgb, shade.warmLit, f * 0.5)
                    edge += f * 0.2
                }
            }
            var path = Path()
            path.move(to: CGPoint(x: X[a], y: Y[a]))
            path.addLine(to: CGPoint(x: X[b], y: Y[b]))
            path.addLine(to: CGPoint(x: X[c], y: Y[c]))
            path.closeSubpath()
            context.fill(path, with: .color(Color(.sRGB, red: rgb.x, green: rgb.y, blue: rgb.z, opacity: 1)))
            context.stroke(path, with: .color(SKColor.ink.opacity(edge)), lineWidth: 0.5)
        }

        if mode != .scan {
            for zone in FaceZone.allCases {
                let l = Double(levels.level(zone)) / 2
                guard l > 0, let i = FaceMeshData.anchors[zone], RZ[i] >= -0.05 else { continue }
                let rad = scale * (zone == .forehead ? 0.55 : 0.36)
                let centre = CGPoint(x: X[i], y: Y[i])
                let gradient = Gradient(colors: [SKColor.primary.opacity(0.18 * l), SKColor.primary.opacity(0)])
                context.fill(Path(ellipseIn: CGRect(x: X[i] - rad, y: Y[i] - rad, width: rad * 2, height: rad * 2)),
                             with: .radialGradient(gradient, center: centre, startRadius: 0, endRadius: rad))
            }
        }

        if mode == .scan {
            var i = 0
            while i < n {
                if RZ[i] >= 0.05 {
                    let tw = still ? 0.6 : 0.35 + 0.65 * abs(sin(t * 2.2 + Double(i) * 1.7))
                    context.fill(Path(CGRect(x: X[i] - 0.7, y: Y[i] - 0.7, width: 1.4, height: 1.4)),
                                 with: .color(SKColor.ink.opacity(0.3 * tw)))
                }
                i += 2
            }
            if scanning {
                let sy = oy - scanY * scale
                let band = CGRect(x: ox - scale * 1.05, y: sy - 18, width: scale * 2.1, height: 36)
                let gradient = Gradient(stops: [
                    .init(color: SKColor.primary.opacity(0), location: 0),
                    .init(color: SKColor.primary.opacity(0.3), location: 0.5),
                    .init(color: SKColor.primary.opacity(0), location: 1),
                ])
                context.fill(Path(band), with: .linearGradient(gradient, startPoint: CGPoint(x: ox, y: sy - 18),
                                                                endPoint: CGPoint(x: ox, y: sy + 18)))
            }
        }

        guard mode == .result else { return }
        for label in labels {
            guard let i = FaceMeshData.anchors[label.zone] else { continue }
            FaceMapLabels.draw(label, at: CGPoint(x: X[i], y: Y[i]), in: &context, size: size)
        }
    }

    private func lerp(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ f: Double) -> SIMD3<Double> {
        a + (b - a) * f
    }
}

/// The porcelain ramps, from the colour tokens (sRGB 0...1, resolved once a frame): a lit face is
/// near cream, a shaded one warm sand, and zone heat runs from rose (lit) to clay (in shade).
@MainActor
private struct Porcelain {
    let lit: SIMD3<Double>
    let shade: SIMD3<Double>
    let warmLit: SIMD3<Double>
    let warmShade: SIMD3<Double>

    init(_ environment: EnvironmentValues) {
        func rgb(_ color: Color) -> SIMD3<Double> {
            let c = color.resolve(in: environment)
            return SIMD3<Double>(Double(c.red), Double(c.green), Double(c.blue))
        }
        let cream = rgb(SKColor.cream), sand = rgb(SKColor.clayTileBg), ink = rgb(SKColor.ink)
        let rose = rgb(SKColor.rose), clay = rgb(SKColor.primary)
        lit = cream + (sand - cream) * 0.18
        shade = sand + (ink - sand) * 0.22
        warmLit = rose
        warmShade = clay + (rose - clay) * 0.2
    }
}

/// A zone's tag beside the map: a leader from the zone to a cream tag holding the zone's name and
/// its reading ("FOREHEAD" over "FLAT MARKS · SOME", or "CLEAR"). Shared by the 3D map and the
/// photo, so the tag reads the same on porcelain and on skin.
@MainActor
enum FaceMapLabels {
    static func draw(_ label: FaceMeshLabel, at anchor: CGPoint, in context: inout GraphicsContext, size: CGSize) {
        let leading = label.side == .leading
        let title = context.resolve(Text(label.title).font(SKFont.label).foregroundStyle(SKColor.ink))
        let value = context.resolve(Text(label.value).font(SKFont.label)
            .foregroundStyle(label.hot ? FaceScanColor.hot : SKColor.clayTileFg))
        let limit = CGSize(width: size.width * 0.5, height: 60)
        let titleSize = title.measure(in: limit)
        let valueSize = value.measure(in: limit)
        let pad = SKSpace.sm - 2
        let width = max(titleSize.width, valueSize.width) + pad * 2
        let height = titleSize.height + valueSize.height + pad * 2
        let midY = size.height * label.y
        let tag = CGRect(x: leading ? SKSpace.md : size.width - SKSpace.md - width,
                         y: midY - height / 2, width: width, height: height)

        var leader = Path()
        leader.move(to: anchor)
        leader.addLine(to: CGPoint(x: leading ? tag.maxX : tag.minX, y: tag.midY))
        context.stroke(leader, with: .color(SKColor.ink.opacity(0.35)), lineWidth: 0.8)
        context.fill(Path(ellipseIn: CGRect(x: anchor.x - 2.6, y: anchor.y - 2.6, width: 5.2, height: 5.2)),
                     with: .color(SKColor.ink))

        let box = Path(roundedRect: tag, cornerRadius: SKSpace.sm)
        context.fill(box, with: .color(SKColor.cream.opacity(0.94)))
        context.stroke(box, with: .color(SKColor.line), lineWidth: 1)
        let x = leading ? tag.minX + pad : tag.maxX - pad
        let side: UnitPoint = leading ? .leading : .trailing
        context.draw(title, at: CGPoint(x: x, y: tag.minY + pad + titleSize.height / 2), anchor: side)
        context.draw(value, at: CGPoint(x: x, y: tag.maxY - pad - valueSize.height / 2), anchor: side)
    }
}

/// The face scan colours that are not app tokens, derived from them.
enum FaceScanColor {
    /// A noticeable reading on the light map: clay (5.1:1 on cream).
    static let hot = SKColor.primary
    /// The third ring (a lighter primary on the cream card).
    static let ringThree = SKColor.primary.opacity(0.6)
}

/// The face scan's light, apothecary ground: porcelain with a soft clay wash at the top and a rose
/// blush at the foot. It replaced the black scanner background on every face scan screen.
struct FaceScanBackdrop: View {
    var body: some View {
        ZStack {
            SKColor.cream
            LinearGradient(colors: [SKColor.blush, .clear], startPoint: .top, endPoint: .center)
            LinearGradient(colors: [.clear, SKColor.rose.opacity(0.35)], startPoint: .center, endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }
}
