import SwiftUI

/// The verdict ring (design §10): draws to `score` and counts the number up in step,
/// toned by the shared thresholds. Respects Reduce Motion by snapping.
struct SKScoreRing: View {
    let score: Int
    var size: CGFloat = 120
    var lineWidth: CGFloat = 11
    var caption: String = "match"
    /// A haptic when the count lands. Off where several rings reveal at once (Compare).
    var settleHaptic = false
    /// Called once when the count lands (the verdict card sends a ripple from the ring).
    var onSettle: (() -> Void)? = nil

    @State private var progress: Double = 0
    @State private var shown = 0
    /// Skinstel 3.0: a bright bead rides the arc while it sweeps, then the ring pops and glows once.
    @State private var sweeping = false
    @State private var settled = false
    @State private var halo: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tone = SKScore.tone(score).fg
        ZStack {
            Circle().stroke(SKColor.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tone, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .blur(radius: 9)
                .opacity(halo)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tone, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(SKColor.cream)
                .frame(width: lineWidth * 0.55, height: lineWidth * 0.55)
                .shadow(color: tone, radius: 6)
                .offset(y: -(size - lineWidth) / 2)
                .rotationEffect(.degrees(360 * progress))
                .opacity(sweeping ? 1 : 0)
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
        .scaleEffect(settled || reduceMotion ? 1 : 0.94)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100")
        .task(id: score) { await animate() }
    }

    private func animate() async {
        let target = Double(max(0, min(100, score))) / 100
        if reduceMotion {
            progress = target; shown = score; settled = true; return
        }
        progress = 0; shown = 0; settled = false; halo = 0
        sweeping = true
        withAnimation(SKAnimation.emil(1.1)) { progress = target }
        let steps = max(1, score)
        let step = 1.0 / Double(steps)
        for i in 1...steps {
            try? await Task.sleep(for: .milliseconds(1000 * step))
            if Task.isCancelled { return }
            withAnimation(.linear(duration: 0.05)) { shown = i }
        }
        withAnimation(.easeOut(duration: 0.25)) { sweeping = false }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { settled = true }
        withAnimation(.easeOut(duration: 0.18)) { halo = 0.55 }
        if settleHaptic { Haptics.medium() }
        onSettle?()
        try? await Task.sleep(for: .milliseconds(220))
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.9)) { halo = 0 }
    }
}

/// Thin progress bar (routine 2/5, founding seats).
struct SKProgressBar: View {
    let fraction: Double
    var tone: SKTone = .neutral
    var height: CGFloat = 8

    /// Skinstel 3.0: the fill draws in from the left the first time the bar appears.
    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shownFraction = drawn || reduceMotion ? fraction : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(SKColor.line)
                Capsule()
                    .fill(tone == .neutral ? AnyShapeStyle(SKColor.primary) : AnyShapeStyle(tone.fg))
                    .frame(width: shownFraction <= 0 ? 0 : max(height, geo.size.width * min(1, shownFraction)))
            }
        }
        .frame(height: height)
        .animation(SKAnimation.emil(0.6), value: fraction)
        .onAppear {
            guard !drawn, !reduceMotion else { return }
            withAnimation(SKAnimation.emil(0.9).delay(0.15)) { drawn = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}
