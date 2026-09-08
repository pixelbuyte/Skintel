import SwiftUI

/// The verdict ring (design §10): draws to `score` and counts the number up in step,
/// toned by the shared thresholds. Respects Reduce Motion by snapping.
struct SKScoreRing: View {
    let score: Int
    var size: CGFloat = 120
    var lineWidth: CGFloat = 11
    var caption: String = "match"

    @State private var progress: Double = 0
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(SKColor.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(SKScore.tone(score).fg, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(shown)")
                    .font(SKFont.serif(size * 0.37, relativeTo: .largeTitle))
                    .foregroundStyle(SKColor.ink)
                    .contentTransition(.numericText())
                Text(caption)
                    .font(SKFont.mono(10, relativeTo: .caption2))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(SKColor.muted)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100")
        .task(id: score) { await animate() }
    }

    private func animate() async {
        let target = Double(max(0, min(100, score))) / 100
        if reduceMotion {
            progress = target; shown = score; return
        }
        progress = 0; shown = 0
        withAnimation(SKAnimation.emil(1.1)) { progress = target }
        let steps = max(1, score)
        let step = 1.0 / Double(steps)
        for i in 1...steps {
            try? await Task.sleep(for: .milliseconds(1000 * step))
            if Task.isCancelled { return }
            withAnimation(.linear(duration: 0.05)) { shown = i }
        }
    }
}

/// Thin progress bar (routine 2/5, founding seats).
struct SKProgressBar: View {
    let fraction: Double
    var tone: SKTone = .neutral
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(SKColor.line)
                Capsule()
                    .fill(tone == .neutral ? AnyShapeStyle(SKColor.primary) : AnyShapeStyle(tone.fg))
                    .frame(width: max(height, geo.size.width * max(0, min(1, fraction))))
            }
        }
        .frame(height: height)
        .animation(SKAnimation.emil(0.6), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}
