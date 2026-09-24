import SwiftUI
import MascotRig
#if canImport(UIKit)
import UIKit
#endif

/// The droplet walking on a sliding floor: the pull-to-refresh indicator.
public struct MascotRefreshIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            SkintelMascot(.walk, size: 42)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                // The droplet faces left, so the floor slides right under it.
                let step = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.6) / 0.6
                HStack(spacing: 8) {
                    ForEach(0..<10, id: \.self) { _ in
                        Capsule().frame(width: 5, height: 2)
                    }
                }
                .offset(x: reduceMotion ? 0 : CGFloat(step) * 13)
                .frame(width: 96, height: 4)
                .clipped()
            }
            .foregroundStyle(MascotPalette.outline.opacity(0.25))
        }
        .frame(height: 50)
        .accessibilityElement()
        .accessibilityLabel("Refreshing")
    }
}

extension View {
    /// Pull to refresh with the walking droplet where the system spinner would be.
    /// Pair with `MascotRefresh.hideSystemSpinner()` at launch.
    public func mascotRefreshable(_ action: @escaping @Sendable () async -> Void) -> some View {
        modifier(MascotRefreshModifier(action: action))
    }
}

struct MascotRefreshModifier: ViewModifier {
    let action: @Sendable () async -> Void
    @State private var refreshing = false

    func body(content: Content) -> some View {
        content
            .refreshable { await run() }
            .overlay(alignment: .top) {
                if refreshing {
                    MascotRefreshIndicator()
                        .padding(.top, 6)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: refreshing)
    }

    private func run() async {
        refreshing = true
        await action()
        refreshing = false
    }
}

#if canImport(UIKit)
public enum MascotRefresh {
    /// Hides the system pull-to-refresh spinner app-wide, so the walking droplet from
    /// `mascotRefreshable` is the only indicator. Call once at launch.
    @MainActor public static func hideSystemSpinner() {
        UIRefreshControl.appearance().tintColor = .clear
    }
}
#endif
