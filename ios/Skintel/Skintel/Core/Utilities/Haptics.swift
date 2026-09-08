import UIKit

/// Sparse, deliberate haptics: scan hit, save, selection, error. Nothing on scroll.
/// Respects the Settings toggle (design §17 "Haptics").
@MainActor
enum Haptics {
    static let preferenceKey = "prefs.haptics"

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true
    }

    static func tap() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func selection() { guard enabled else { return }; UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
