import SwiftUI

private struct SKPullOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Calm, mascot-led pull-to-refresh used in place of the system spinner. One refresh runs
/// at a time, one soft haptic fires the moment the pull crosses the trigger distance (not on
/// every frame), and Reduce Motion keeps the mascot still while progress is still visible.
///
/// Built on plain `ScrollView` offset tracking rather than `UIScrollView` introspection, so
/// it needs a device pass to confirm gesture feel (tracked in the release design plan).
private struct SKMascotRefreshable: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let action: () async -> Void

    @State private var pull: CGFloat = 0
    @State private var isRefreshing = false
    @State private var armed = false
    @State private var bob = false

    private let triggerDistance: CGFloat = 76
    private let coordinateSpace = "skMascotRefresh"

    func body(content: Content) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    Color.clear.preference(key: SKPullOffsetKey.self,
                                            value: proxy.frame(in: .named(coordinateSpace)).minY)
                }
                .frame(height: 0)

                indicator
                    .frame(height: max(0, min(pull, triggerDistance * 1.3)))
                    .frame(maxWidth: .infinity)
                    .clipped()

                content
            }
        }
        .coordinateSpace(name: coordinateSpace)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in triggerIfNeeded() }
        )
        .onPreferenceChange(SKPullOffsetKey.self) { value in
            guard !isRefreshing else { return }
            let d = max(0, value)
            pull = d
            if d >= triggerDistance, !armed {
                armed = true
                Haptics.selection()
            } else if d < triggerDistance * 0.6 {
                armed = false
            }
        }
    }

    private func triggerIfNeeded() {
        guard !isRefreshing, armed, pull >= triggerDistance else { return }
        isRefreshing = true
        withAnimation(reduceMotion ? nil : SKAnimation.emil(0.3)) { pull = triggerDistance }
        Task {
            let start = Date()
            await action()
            let remaining = 0.35 - Date().timeIntervalSince(start)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            withAnimation(reduceMotion ? nil : SKAnimation.emil(0.35)) { pull = 0 }
            isRefreshing = false
            armed = false
        }
    }

    @ViewBuilder
    private var indicator: some View {
        SKMascot(size: 38)
            .scaleEffect(0.7 + min(pull / triggerDistance, 1) * 0.3)
            .rotationEffect(.degrees(isRefreshing && !reduceMotion && bob ? 8 : (isRefreshing && !reduceMotion ? -8 : 0)))
            .opacity(pull > 4 || isRefreshing ? 1 : 0)
            .onChange(of: isRefreshing) { _, refreshing in
                guard refreshing, !reduceMotion else { bob = false; return }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { bob = true }
            }
    }
}

extension View {
    /// A calm mascot-led pull-to-refresh, used in place of `.refreshable` on primary lists.
    /// Wraps `content` in its own `ScrollView` — don't nest this inside another `ScrollView`.
    func skMascotRefreshable(action: @escaping () async -> Void) -> some View {
        modifier(SKMascotRefreshable(action: action))
    }
}
