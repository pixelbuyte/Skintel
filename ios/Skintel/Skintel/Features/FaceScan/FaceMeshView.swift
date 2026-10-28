import SwiftUI
import SkintelCore

private typealias MeshShade = SKMeshShade

/// A Canvas port of the canvas face renderer: painter-sorted flat shading, back-face culling, zone
/// heat from a Gaussian falloff around landmarks, an additive glow and label leaders.
/// Drag turns it; it sways slowly on its own unless Reduce Motion is on.
struct FaceMeshView: View {
    enum Mode: Sendable { case result, scan }
    /// `.dark` for the black hero; `.light` for cream screens (pale face, ink labels).
    enum Palette: Sendable { case dark, light }

    var mode: Mode = .result
    var levels = FaceZoneLevels(levels: [:])
    var labels: [FaceMeshLabel] = []
    /// Fraction of the shorter side the face's half-height takes.
    var zoom: CGFloat = 0.38
    /// The yaw the face eases towards, in radians (the sweep turns it per angle).
    var targetYaw: Double = 0
    var palette: Palette = .dark

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragYaw: Double = 0
    @State private var dragStartYaw: Double = 0
    @State private var dragReleasedAt: Date?
    @State private var isDragging = false
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion && !isDragging)) { timeline in
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
                    dragYaw = max(-1.1, min(1.1, dragStartYaw + Double(value.translation.width) * 0.012))
                    dragReleasedAt = nil
                }
                .onEnded { value in
                    isDragging = false
                    dragReleasedAt = value.time
                }
        )
        .accessibilityElement()
        .accessibilityLabel(mode == .scan ? "Your face, being scanned" : "3D map of your face with zones highlighted")
        .accessibilityAddTraits(.isImage)
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
        let t = now.timeIntervalSince(start)
        let still = reduceMotion
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
            X[i] = ox + x1 * scale * k
            Y[i] = oy - y2 * scale * k
            var h = 0.0
            for zl in zoneLevels {
                let v = zl.level * Double(zl.weights[i])
                if v > h { h = v }
            }
            H[i] = h
        }

        var tris: [Int] = []
        tris.reserveCapacity(F.count / 3)
        var k = 0
        while k + 2 < F.count {
            let a = F[k], b = F[k + 1], c = F[k + 2]
            let cross = (X[b] - X[a]) * (Y[c] - Y[a]) - (Y[b] - Y[a]) * (X[c] - X[a])
            if cross < 0 { tris.append(k) }
            k += 3
        }
        tris.sort { (RZ[F[$0]] + RZ[F[$0 + 1]] + RZ[F[$0 + 2]]) < (RZ[F[$1]] + RZ[F[$1 + 1]] + RZ[F[$1 + 2]]) }

        let L = MeshShade.light
        let light = palette == .light
        let low = light ? MeshShade.lightLow : MeshShade.darkLow
        let high = light ? MeshShade.lightHigh : MeshShade.darkHigh
        let edgeColor = light ? SKColor.clayTileFg : SKColor.bg
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
            var rgb = lerp(low, high, diff)
            if mode == .scan && !light { rgb *= 0.8 }
            rgb = lerp(rgb, lerp(MeshShade.warmLow, MeshShade.warmHigh, diff), heat)
            var edge = 0.07 + heat * 0.22
            if scanning {
                let my = (Double(P[a * 3 + 1]) + Double(P[b * 3 + 1]) + Double(P[c * 3 + 1])) / 3
                let d = abs(my - scanY)
                if d < 0.12 {
                    let f = 1 - d / 0.12
                    rgb = lerp(rgb, light ? MeshShade.warmHigh : MeshShade.scanLight, f * 0.55)
                    edge += f * 0.35
                }
            }
            var path = Path()
            path.move(to: CGPoint(x: X[a], y: Y[a]))
            path.addLine(to: CGPoint(x: X[b], y: Y[b]))
            path.addLine(to: CGPoint(x: X[c], y: Y[c]))
            path.closeSubpath()
            context.fill(path, with: .color(Color(.sRGB, red: rgb.x / 255, green: rgb.y / 255, blue: rgb.z / 255, opacity: 1)))
            context.stroke(path, with: .color(edgeColor.opacity(light ? edge * 1.4 : edge)), lineWidth: 0.6)
        }

        if mode == .result {
            var glow = context
            glow.blendMode = light ? .normal : .plusLighter
            for zone in FaceZone.allCases {
                let l = Double(levels.level(zone)) / 2
                guard l > 0, let i = FaceMeshData.anchors[zone], RZ[i] >= -0.05 else { continue }
                let rad = scale * (zone == .forehead ? 0.55 : 0.36)
                let centre = CGPoint(x: X[i], y: Y[i])
                let gradient = Gradient(colors: [SKColor.primary.opacity((light ? 0.26 : 0.32) * l), SKColor.primary.opacity(0)])
                glow.fill(Path(ellipseIn: CGRect(x: X[i] - rad, y: Y[i] - rad, width: rad * 2, height: rad * 2)),
                          with: .radialGradient(gradient, center: centre, startRadius: 0, endRadius: rad))
            }
        }

        if mode == .scan {
            var i = 0
            while i < n {
                if RZ[i] >= 0.05 {
                    let tw = still ? 0.6 : 0.35 + 0.65 * abs(sin(t * 2.2 + Double(i) * 1.7))
                    context.fill(Path(CGRect(x: X[i] - 0.7, y: Y[i] - 0.7, width: 1.4, height: 1.4)),
                                 with: .color((light ? SKColor.primary : SKColor.bg).opacity(0.55 * tw)))
                }
                i += 2
            }
            if scanning {
                let sy = oy - scanY * scale
                let band = CGRect(x: ox - scale * 1.05, y: sy - 18, width: scale * 2.1, height: 36)
                let gradient = Gradient(stops: [
                    .init(color: SKColor.primary.opacity(0), location: 0),
                    .init(color: SKColor.primary.opacity(0.5), location: 0.5),
                    .init(color: SKColor.primary.opacity(0), location: 1),
                ])
                context.fill(Path(band), with: .linearGradient(gradient, startPoint: CGPoint(x: ox, y: sy - 18),
                                                                endPoint: CGPoint(x: ox, y: sy + 18)))
            }
        }

        guard mode == .result else { return }
        for label in labels {
            guard let i = FaceMeshData.anchors[label.zone] else { continue }
            let ax = X[i], ay = Y[i]
            let leading = label.side == .leading
            let lx = leading ? 16.0 : cw - 16
            let ly = ch * Double(label.y)
            let ex = leading ? min(ax - 14, lx + 96) : max(ax + 14, lx - 96)
            var leader = Path()
            leader.move(to: CGPoint(x: ax, y: ay))
            leader.addLine(to: CGPoint(x: ex, y: ly))
            leader.addLine(to: CGPoint(x: leading ? lx + 82 : lx - 82, y: ly))
            let ink = light ? SKColor.ink : SKColor.bg
            context.stroke(leader, with: .color(ink.opacity(light ? 0.3 : 0.45)), lineWidth: 0.8)
            context.fill(Path(ellipseIn: CGRect(x: ax - 2.6, y: ay - 2.6, width: 5.2, height: 5.2)),
                         with: .color(light ? SKColor.primary : SKColor.bg))
            let anchor: UnitPoint = leading ? .leading : .trailing
            context.draw(Text(label.title).font(SKFont.label).foregroundStyle(ink.opacity(0.92)),
                         at: CGPoint(x: lx, y: ly - 9), anchor: anchor)
            context.draw(Text(label.value).font(SKFont.label)
                            .foregroundStyle(label.hot ? (light ? SKColor.primary : FaceScanColor.hot) : (light ? SKColor.muted : SKColor.bg.opacity(0.62))),
                         at: CGPoint(x: lx, y: ly + 7), anchor: anchor)
        }
    }

    private func lerp(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ f: Double) -> SIMD3<Double> {
        a + (b - a) * f
    }
}

/// The two face scan colours the canvas uses that are not app tokens, derived from them.
enum FaceScanColor {
    /// The warm label colour on the dark hero (light clay reads on black; primary is too dark).
    static let hot = SKColor.clayTileBg
    /// The third ring (a lighter primary on the cream card).
    static let ringThree = SKColor.primary.opacity(0.6)
}
