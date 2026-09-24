import SwiftUI
import MascotRig

/// Draws the droplet in one pose. Every body part is its own layer with its own transform:
/// legs step, arms swing around their shoulders, eyes blink, and the body squashes, leans
/// and lifts around the feet. Always laid out at the 240 × 250 design size.
struct MascotFigure: View {
    let action: MascotAction
    let mood: MascotMood
    let pose: MascotPose

    private typealias G = MascotGeometry

    var body: some View {
        ZStack {
            shadow
            figure
                .scaleEffect(x: 1 + pose.squash, y: 1 - pose.squash, anchor: G.feet.anchor)
                .rotationEffect(.degrees(pose.tilt), anchor: G.feet.anchor)
                .offset(y: -pose.lift)
            if action == .celebrate { sparkles }
        }
        .frame(width: G.canvas.width, height: G.canvas.height)
    }

    // MARK: Layers, back to front

    private var figure: some View {
        ZStack {
            leg(G.leftLeg, pose.leftLeg)
            leg(G.rightLeg, pose.rightLeg)
            if !holds(pose.leftArm) { arm(pose.leftArm, left: true) }
            if !holds(pose.rightArm) { arm(pose.rightArm, left: false) }
            droplet
            face
            if pose.leftArm.style == .holdProduct { product }
            if pose.rightArm.style == .holdScanner { scanner }
            if holds(pose.leftArm) { arm(pose.leftArm, left: true) }
            if holds(pose.rightArm) { arm(pose.rightArm, left: false) }
        }
    }

    private var shadow: some View {
        let airborne = min(1, pose.lift / MascotRig.jumpHeight)
        return DesignShape(Path(ellipseIn: G.shadow))
            .fill(MascotPalette.floor.opacity(0.14))
            .scaleEffect(x: 1 - 0.4 * airborne, y: 1, anchor: G.feet.anchor)
    }

    private func leg(_ geometry: MascotGeometry.Leg, _ leg: LegPose) -> some View {
        let shape = DesignShape(MascotPaths.leg(geometry))
        return ZStack {
            shape.fill(MascotPalette.skin)
            shape.stroke(MascotPalette.outline, style: StrokeStyle(lineWidth: G.lineWidth, lineJoin: .round))
        }
        .offset(x: leg.stride, y: -leg.lift)
    }

    private func holds(_ arm: ArmPose) -> Bool {
        arm.style == .holdProduct || arm.style == .holdScanner
    }

    private func geometry(_ style: ArmStyle, left: Bool) -> MascotGeometry.Arm {
        switch style {
        case .down: left ? G.armDownLeft : G.armDownRight
        case .up: left ? G.armUpLeft : G.armUpRight
        case .holdProduct: G.armHoldProduct
        case .holdScanner: G.armHoldScanner
        }
    }

    /// Outline stroke, round mitten hand, then the skin stroke over the join.
    private func arm(_ arm: ArmPose, left: Bool) -> some View {
        let g = geometry(arm.style, left: left)
        let limb = DesignShape(MascotPaths.arm(g))
        let hand = DesignShape(MascotPaths.hand(g))
        return ZStack {
            limb.stroke(MascotPalette.outline, style: StrokeStyle(lineWidth: G.armOutlineWidth, lineCap: .round, lineJoin: .round))
            hand.fill(MascotPalette.skin)
            hand.stroke(MascotPalette.outline, lineWidth: G.lineWidth)
            limb.stroke(MascotPalette.skin, style: StrokeStyle(lineWidth: G.armFillWidth, lineCap: .round, lineJoin: .round))
        }
        .rotationEffect(.degrees(arm.angle), anchor: g.pivot.anchor)
    }

    private var droplet: some View {
        let shape = DesignShape(MascotPaths.body)
        return ZStack {
            shape.fill(RadialGradient(
                stops: [
                    Gradient.Stop(color: MascotPalette.skinLight, location: 0),
                    Gradient.Stop(color: MascotPalette.skin, location: 0.62),
                    Gradient.Stop(color: MascotPalette.skinShade, location: 1),
                ],
                center: UnitPoint(x: 0.428, y: 0.462), startRadius: 0, endRadius: 144))
            shape.stroke(MascotPalette.outline, lineWidth: G.lineWidth)
            DesignShape(MascotPaths.shine).fill(MascotPalette.shine.opacity(0.9))
            DesignShape(Path(ellipseIn: G.blush)).fill(MascotPalette.blush.opacity(0.6))
        }
    }

    // MARK: Face

    @ViewBuilder
    private var face: some View {
        if action == .celebrate {
            ZStack {
                DesignShape(MascotPaths.happyEyes)
                    .stroke(MascotPalette.eye, style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                DesignShape(MascotPaths.openMouth).fill(MascotPalette.mouth)
                DesignShape(MascotPaths.openMouth).stroke(MascotPalette.eye, lineWidth: 2.4)
            }
        } else {
            ZStack {
                eye(G.leftEye)
                eye(G.rightEye)
                DesignShape(mood == .worried ? MascotPaths.frown : MascotPaths.smile)
                    .stroke(MascotPalette.eye, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                if mood == .worried {
                    DesignShape(MascotPaths.worriedBrows)
                        .stroke(MascotPalette.eye, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                }
            }
            // While scanning it glances down at the product.
            .offset(x: action == .scan ? -2 : 0, y: action == .scan ? 2 : 0)
        }
    }

    private func eye(_ rect: CGRect) -> some View {
        DesignShape(Path(ellipseIn: rect))
            .fill(MascotPalette.eye)
            .scaleEffect(x: 1, y: pose.eyesOpen, anchor: CGPoint(x: rect.midX, y: rect.midY).anchor)
    }

    // MARK: Props and effects

    /// The dropper bottle from the original art, with a red scan line sweeping its glass.
    private var product: some View {
        let glass = G.productGlass
        let sweep = 1 - abs(1 - 2 * pose.effect)
        let lineY = glass.minY + 8 + (glass.height - 16) * CGFloat(sweep)
        return ZStack {
            outlined(Path(ellipseIn: G.productBulb), MascotPalette.bulb)
            outlined(Path(roundedRect: G.productCollar, cornerRadius: 3), MascotPalette.cap)
            outlined(Path(roundedRect: glass, cornerRadius: 9), MascotPalette.glass.opacity(0.92))
            DesignShape(MascotPaths.dropperTube).stroke(MascotPalette.tube, lineWidth: 2)
            DesignShape(MascotPaths.labelDrop).fill(MascotPalette.gold)
            if action == .scan {
                DesignShape(Path(roundedRect: CGRect(x: glass.minX + 4, y: lineY - 1, width: glass.width - 8, height: 2),
                                       cornerRadius: 1))
                    .fill(MascotPalette.laser)
                    .shadow(color: MascotPalette.laser.opacity(0.8), radius: 3)
            }
        }
        .rotationEffect(.degrees(G.productTiltDegrees), anchor: G.productPivot.anchor)
    }

    private var scanner: some View {
        let flicker = 0.55 + 0.45 * abs(sin(pose.effect * .pi * 8))
        return ZStack {
            outlined(Path(roundedRect: G.scannerBody, cornerRadius: 5), MascotPalette.scanner)
            DesignShape(Path(roundedRect: G.scannerWindow, cornerRadius: 1.5))
                .fill(MascotPalette.laser.opacity(flicker))
                .shadow(color: MascotPalette.laser.opacity(0.7 * flicker), radius: 4)
        }
        .rotationEffect(.degrees(pose.rightArm.angle), anchor: G.armHoldScanner.pivot.anchor)
    }

    private var sparkles: some View {
        ZStack {
            ForEach(G.sparkles.indices, id: \.self) { i in
                let s = G.sparkles[i]
                let twinkle = 0.5 + 0.5 * sin(2 * .pi * (pose.effect + Double(i) * 0.25))
                DesignShape(MascotPaths.sparkle(s.center, s.size))
                    .fill(MascotPalette.sparkle)
                    .scaleEffect(0.6 + 0.5 * twinkle, anchor: s.center.anchor)
                    .opacity(0.25 + 0.75 * twinkle)
            }
        }
    }

    private func outlined(_ path: Path, _ fill: Color) -> some View {
        let shape = DesignShape(path)
        return ZStack {
            shape.fill(fill)
            shape.stroke(MascotPalette.outline, lineWidth: G.lineWidth)
        }
    }
}
