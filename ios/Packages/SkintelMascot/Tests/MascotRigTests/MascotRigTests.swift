import Foundation
import Testing
@testable import MascotRig

private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-6) -> Bool { abs(a - b) <= tolerance }

private func samePose(_ a: MascotPose, _ b: MascotPose) -> Bool {
    close(a.lift, b.lift) && close(a.squash, b.squash) && close(a.tilt, b.tilt)
        && a.leftArm.style == b.leftArm.style && close(a.leftArm.angle, b.leftArm.angle)
        && a.rightArm.style == b.rightArm.style && close(a.rightArm.angle, b.rightArm.angle)
        && close(a.leftLeg.lift, b.leftLeg.lift) && close(a.leftLeg.stride, b.leftLeg.stride)
        && close(a.rightLeg.lift, b.rightLeg.lift) && close(a.rightLeg.stride, b.rightLeg.stride)
        && close(a.effect, b.effect)
}

@Test(arguments: MascotAction.allCases)
func loopsSeamlessly(_ action: MascotAction) {
    // Idle-based actions breathe on the idle period, so check over a common multiple.
    let loop = action.period * MascotAction.idle.period * 10
    for t in stride(from: 0.05, to: 3.0, by: 0.37) {
        #expect(samePose(MascotRig.pose(for: action, at: t), MascotRig.pose(for: action, at: t + loop)))
    }
}

@Test func walkingFeetAlternate() {
    let period = MascotAction.walk.period
    let first = MascotRig.pose(for: .walk, at: period * 0.75)
    #expect(first.leftLeg.lift > 6 && first.rightLeg.lift == 0)
    let second = MascotRig.pose(for: .walk, at: period * 0.25)
    #expect(second.rightLeg.lift > 6 && second.leftLeg.lift == 0)
}

@Test func walkingFootLiftsOnlyWhileSwingingForward() {
    let period = MascotAction.walk.period
    for i in 0..<40 {
        let t = period * Double(i) / 40
        let now = MascotRig.pose(for: .walk, at: t)
        let next = MascotRig.pose(for: .walk, at: t + period / 400)
        // Forward is to the left (stride decreasing).
        if now.leftLeg.lift > 0.5 { #expect(next.leftLeg.stride < now.leftLeg.stride) }
        if now.rightLeg.lift > 0.5 { #expect(next.rightLeg.stride < now.rightLeg.stride) }
    }
}

@Test func celebrationJumpsAndLands() {
    let period = MascotAction.celebrate.period
    let peak = MascotRig.pose(for: .celebrate, at: period * 0.31)
    #expect(peak.lift > MascotRig.jumpHeight * 0.95)
    let landing = MascotRig.pose(for: .celebrate, at: period * 0.8)
    #expect(landing.lift == 0 && landing.squash > 0)
    #expect(peak.leftArm.style == .up && peak.rightArm.style == .up)
}

@Test func blinksBrieflyEachCycle() {
    #expect(MascotRig.eyesOpen(at: 1) == 1)
    #expect(MascotRig.eyesOpen(at: MascotRig.blinkEvery - 0.05) < 0.5)
    #expect(MascotRig.eyesOpen(at: MascotRig.blinkEvery + 1) == 1)
    #expect(MascotRig.eyesOpen(at: -0.05) < 0.5)
}

@Test func actionsUseTheirProps() {
    let scan = MascotRig.pose(for: .scan, at: 0.4)
    #expect(scan.leftArm.style == .holdProduct && scan.rightArm.style == .holdScanner)
    let wave = MascotRig.pose(for: .wave, at: 0.4)
    #expect(wave.rightArm.style == .up && wave.leftArm.style == .down)
    #expect(MascotRig.pose(for: .idle, at: 0.4).rightArm.style == .down)
}

@Test(arguments: MascotAction.allCases)
func stillFramesStandOnTheFloorWithEyesOpen(_ action: MascotAction) {
    let still = MascotRig.still(for: action)
    #expect(still.lift == 0 && still.tilt == 0 && still.eyesOpen == 1)
    #expect(still.leftLeg.lift == 0 && still.rightLeg.lift == 0)
}

@Test func negativeTimesStayInRange() {
    for t in [-0.001, -1.3, -99.9] {
        let f = MascotRig.fraction(t)
        #expect(f >= 0 && f < 1)
    }
}

@Test func drawingFitsTheCanvas() {
    let points = [MascotGeometry.bodyStart] + MascotGeometry.bodySegments.flatMap { [$0.control1, $0.control2, $0.end] }
    for p in points {
        #expect(p.x >= 0 && p.x <= MascotGeometry.canvas.width)
        #expect(p.y >= 0 && p.y <= MascotGeometry.canvas.height)
    }
    #expect(MascotGeometry.bodySegments.last?.end == MascotGeometry.bodyStart)
    #expect(MascotGeometry.leftLeg.bottom <= MascotGeometry.canvas.height)
    #expect(MascotGeometry.rightLeg.bottom <= MascotGeometry.canvas.height)
}
