import CoreMotion
import SwiftUI

// MARK: - Skinstel 3.0: holographic tilt

/// The phone's attitude, shared by every holographic card on screen. Motion updates run
/// only while at least one card is visible. Device motion needs no permission prompt.
@MainActor
@Observable
final class SKTilt {
    static let shared = SKTilt()

    private(set) var pitch: Double = 0
    private(set) var roll: Double = 0
    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var users = 0

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let p = motion.attitude.pitch
            let r = motion.attitude.roll
            MainActor.assumeIsolated {
                self?.pitch = p
                self?.roll = r
            }
        }
    }

    func stop() {
        users = max(0, users - 1)
        if users == 0 { manager.stopDeviceMotionUpdates() }
    }
}

/// A card that leans with the phone: a few degrees of 3D tilt, a light band that slides
/// across it, and a faint warm iridescence that turns with the tilt. Off under Reduce Motion.
private struct SKHolo: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sheen: [Color] = [
        Color(hex: 0xFFD9C7), Color(hex: 0xF4C27A), Color(hex: 0xE8A3B0), Color(hex: 0xC9B6E8), Color(hex: 0xFFD9C7),
    ]

    func body(content: Content) -> some View {
        let tilt = SKTilt.shared
        // Roll leans left/right; pitch is centred on the usual ~40° reading angle.
        let x = reduceMotion ? 0 : max(-1, min(1, tilt.roll / 0.6))
        let y = reduceMotion ? 0 : max(-1, min(1, (tilt.pitch - 0.7) / 0.6))
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .overlay {
                GeometryReader { g in
                    ZStack {
                        AngularGradient(colors: Self.sheen, center: .center, angle: .degrees(x * 60 + y * 30))
                            .opacity(0.28)
                            .blendMode(.overlay)
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.34), .white.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: g.size.width * 0.55)
                            .rotationEffect(.degrees(18))
                            .offset(x: g.size.width * (0.5 * x - 0.1 * y))
                            .blendMode(.screen)
                    }
                    .frame(width: g.size.width, height: g.size.height)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .rotation3DEffect(.degrees(-y * 6), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(x * 8), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: x)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: y)
            .onAppear { if !reduceMotion { tilt.start() } }
            .onDisappear { if !reduceMotion { tilt.stop() } }
    }
}

extension View {
    /// Holographic finish: leans with the phone, with a sliding light band and warm iridescence.
    func skHolo(cornerRadius: CGFloat = 18) -> some View { modifier(SKHolo(cornerRadius: cornerRadius)) }

    /// iOS 18 zoom: mark this as where a pushed screen zooms out of (no-op on iOS 17).
    @ViewBuilder
    func skZoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// iOS 18 zoom: this pushed screen grows out of its source and shrinks back into it.
    @ViewBuilder
    func skZoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
