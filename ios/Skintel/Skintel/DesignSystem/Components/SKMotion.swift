import SwiftUI

// MARK: - Skinstel 3.0 motion
//
// Four pieces, all off under Reduce Motion:
// - `SKBloomIntro`: the launch. A clay drop falls, lands in rings, the wordmark rises
//   letter by letter, then an iris opens from the drop onto the app.
// - `.skEntrance(_:)`: sections rise out of a soft blur, one after another, the first
//   time they appear.
// - `.skScrollDepth()`: cards lean back and soften as they leave the screen.
// - `SKAurora`: a slow warm light drifting behind the Today header.

/// The launch sequence, drawn over whatever the app shows underneath. It never takes
/// touches and is hidden from VoiceOver, so the screen below is usable the whole time.
struct SKBloomIntro: View {
    var onFinished: () -> Void

    @State private var dropY: CGFloat = -420
    @State private var squash: CGFloat = 1
    @State private var rings = false
    @State private var letters = 0
    @State private var iris: CGFloat = 0

    private static let word = Array("Skinstel")
    private static let dropTop = Color(hex: 0xC97A66)

    var body: some View {
        GeometryReader { geo in
            let reach = hypot(geo.size.width, geo.size.height) * 1.15
            ZStack {
                SKColor.bg
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(SKColor.primary.opacity(0.45), lineWidth: 1.5)
                        .frame(width: 90, height: 90)
                        .scaleEffect(rings ? 4.4 + CGFloat(i) * 1.6 : 0.2)
                        .opacity(rings ? 0 : 0.9)
                        .animation(.easeOut(duration: 1.15).delay(Double(i) * 0.12), value: rings)
                        .offset(y: 24)
                }
                DropShape()
                    .fill(LinearGradient(colors: [Self.dropTop, SKColor.primary], startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 60)
                    .scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
                    .shadow(color: SKColor.primary.opacity(0.35), radius: 14, y: 8)
                    .offset(y: dropY)
                HStack(spacing: 0) {
                    ForEach(Self.word.indices, id: \.self) { i in
                        Text(String(Self.word[i]))
                            .font(SKFont.serif(54, relativeTo: .largeTitle))
                            .foregroundStyle(SKColor.ink)
                            .opacity(i < letters ? 1 : 0)
                            .offset(y: i < letters ? 0 : 20)
                            .blur(radius: i < letters ? 0 : 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: letters)
                    }
                }
                .offset(y: 86)
            }
            .mask {
                Rectangle()
                    .overlay {
                        Circle()
                            .frame(width: reach, height: reach)
                            .scaleEffect(iris)
                            .offset(y: -10)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await play() }
    }

    private func play() async {
        // Gravity: ease in, so the drop speeds up as it falls.
        withAnimation(.timingCurve(0.55, 0, 1, 0.45, duration: 0.42)) { dropY = 0 }
        try? await Task.sleep(for: .seconds(0.42))
        Haptics.tap()
        rings = true
        withAnimation(.spring(response: 0.16, dampingFraction: 0.5)) { squash = 0.7 }
        try? await Task.sleep(for: .seconds(0.12))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { squash = 1; dropY = -30 }
        for i in 1...Self.word.count {
            try? await Task.sleep(for: .seconds(0.035))
            letters = i
        }
        try? await Task.sleep(for: .seconds(0.32))
        withAnimation(.timingCurve(0.7, 0, 0.3, 1, duration: 0.55)) { iris = 1 }
        try? await Task.sleep(for: .seconds(0.56))
        onFinished()
    }
}

/// First appearance: rise out of a soft blur, `index` steps after the first section.
private struct SKEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let settled = shown || reduceMotion
        content
            .opacity(settled ? 1 : 0)
            .offset(y: settled ? 0 : 28)
            .scaleEffect(settled ? 1 : 0.97, anchor: .top)
            .blur(radius: settled ? 0 : 10)
            .onAppear {
                guard !shown, !reduceMotion else { return }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.08 + Double(index) * 0.07)) {
                    shown = true
                }
            }
    }
}

/// Cards lean back and soften as they scroll off either edge.
private struct SKScrollDepth: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition(.interactive, axis: .vertical) { effect, phase in
                effect
                    .scaleEffect(CGFloat(1 - abs(phase.value) * 0.05))
                    .opacity(1 - abs(phase.value) * 0.35)
                    .blur(radius: CGFloat(abs(phase.value) * 2))
            }
        }
    }
}

extension View {
    /// Rise out of a soft blur the first time this appears; `index` staggers siblings.
    func skEntrance(_ index: Int) -> some View { modifier(SKEntrance(index: index)) }

    /// Lean back and soften while scrolling off screen.
    func skScrollDepth() -> some View { modifier(SKScrollDepth()) }
}

/// Slow warm light behind a header: four soft glows drifting on long, out-of-step loops.
struct SKAurora: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let glows: [(color: Color, x: Double, y: Double, r: Double, speed: Double)] = [
        (SKColor.primary, 0.18, 0.35, 0.55, 0.11),
        (Color(hex: 0xE8B9A8), 0.78, 0.25, 0.6, 0.08),
        (Color(hex: 0xE2CDA6), 0.55, 0.7, 0.5, 0.13),
        (SKColor.goodFg, 0.92, 0.75, 0.35, 0.09),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for (i, g) in Self.glows.enumerated() {
                    let phase = t * g.speed + Double(i) * 1.7
                    let center = CGPoint(x: size.width * (g.x + 0.08 * sin(phase)),
                                         y: size.height * (g.y + 0.1 * cos(phase * 1.3)))
                    let radius = size.width * g.r * (1 + 0.08 * sin(phase * 0.7))
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .radialGradient(Gradient(colors: [g.color.opacity(i == 3 ? 0.12 : 0.22), g.color.opacity(0)]),
                                                   center: center, startRadius: 0, endRadius: radius))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
