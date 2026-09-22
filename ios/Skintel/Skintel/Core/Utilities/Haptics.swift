import UIKit

/// One soft pulse for deliberate actions. Coalescing prevents a scan/save sequence
/// from stacking several vibrations. Navigation and scrolling stay quiet.
/// Respects the Settings toggle (design §17 "Haptics").
@MainActor
enum Haptics {
    static let preferenceKey = "prefs.haptics"

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true
    }

    private static let generator = UIImpactFeedbackGenerator(style: .soft)
    private static var lastFeedback: TimeInterval = -.infinity

    private static func pulse(_ intensity: CGFloat) {
        guard enabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFeedback >= 0.2 else { return }
        lastFeedback = now
        generator.impactOccurred(intensity: intensity)
    }

    static func tap() { pulse(0.25) }
    static func medium() { pulse(0.4) }
    static func selection() { pulse(0.2) }
    static func success() { pulse(0.35) }
    static func warning() { pulse(0.3) }
    static func error() { pulse(0.3) }
}
