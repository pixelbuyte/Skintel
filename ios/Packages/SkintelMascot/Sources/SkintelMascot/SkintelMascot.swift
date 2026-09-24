import SwiftUI
@_exported import MascotRig

/// Skintel's terracotta droplet, animated natively: separate legs, arms, eyes and body,
/// driven by `MascotRig`. No network, video or GIF.
///
/// The animation only runs while it can be seen: it pauses when the view leaves the screen
/// or scrolls out of its scroll view, while the app is in the background, and holds a still
/// frame when Reduce Motion is on.
public struct SkintelMascot: View {
    private let action: MascotAction
    private let mood: MascotMood
    private let size: CGFloat
    private let animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false
    @State private var isInViewport = true
    @State private var start = Date.now

    /// - Parameters:
    ///   - size: Height in points; the width follows the drawing (0.96 × height).
    ///   - animated: `false` always shows the still frame, as Reduce Motion does.
    public init(_ action: MascotAction = .idle, mood: MascotMood = .happy, size: CGFloat = 120, animated: Bool = true) {
        self.action = action
        self.mood = mood
        self.size = size
        self.animated = animated
    }

    private var moves: Bool { animated && !reduceMotion }
    private var paused: Bool { !moves || scenePhase != .active || !isOnScreen || !isInViewport }

    public var body: some View {
        let scale = size / MascotGeometry.canvas.height
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { context in
            let pose = moves
                ? MascotRig.pose(for: action, at: context.date.timeIntervalSince(start))
                : MascotRig.still(for: action)
            MascotFigure(action: action, mood: mood, pose: pose)
                .scaleEffect(scale)
                .frame(width: MascotGeometry.canvas.width * scale, height: size)
        }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .onGeometryChange(for: Bool.self) { proxy in
            guard let viewport = proxy.bounds(of: .scrollView) else { return true }
            return viewport.intersects(CGRect(origin: .zero, size: proxy.size))
        } action: { visible in
            isInViewport = visible
        }
        .accessibilityHidden(true)
    }
}

#Preview("Actions") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(MascotAction.allCases) { action in
                VStack {
                    SkintelMascot(action, size: 140)
                    Text(action.title).font(.caption)
                }
            }
            SkintelMascot(.idle, mood: .worried, size: 140)
        }
        .padding()
    }
}
