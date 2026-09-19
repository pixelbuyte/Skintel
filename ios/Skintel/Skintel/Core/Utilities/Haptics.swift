import UIKit
import SkintelCore

/// Sparse, deliberate haptics: scan hit, save, selection, error. Nothing on scroll.
/// Respects the Settings toggle (design §17 "Haptics") and its Gentle/Medium/Full
/// strength, which defaults to Gentle.
///
/// Three things make this feel deliberate rather than merely quieter:
///
/// 1. The generators are cached and `prepare()`d. A freshly allocated generator leaves
///    the Taptic Engine cold, so the first beat lands up to ~100ms late — *after* the
///    animation has settled. That lag is what reads as "sudden".
/// 2. `.soft` with an explicit `impactOccurred(intensity:)` is a longer, rounder
///    envelope than `.light`/`.medium` at full whack.
/// 3. A 60ms re-entry guard collapses a hammered button into a rhythm instead of a
///    pile-up of overlapping two-beat sequences.
///
/// `UINotificationFeedbackGenerator` is deliberately absent: its patterns are
/// fixed-amplitude, so no user setting could ever soften them.
@MainActor
enum Haptics {
    static let preferenceKey = "prefs.haptics"
    static let strengthKey = "prefs.haptics.strength"

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true
    }

    static var strength: HapticStrength {
        HapticStrength(rawValue: UserDefaults.standard.string(forKey: strengthKey) ?? "") ?? .gentle
    }

    // MainActor-isolated globals: legal under Swift 6 strict concurrency because the
    // enum itself is `@MainActor`. Do NOT copy the `nonisolated(unsafe)` spelling used by
    // `DateFormatting`/`ISO8601` — those enums are not actor-isolated and the two
    // situations are opposites.
    private static let softGen = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidGen = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGen = UISelectionFeedbackGenerator()
    private static var lastFire = Date.distantPast

    /// Warms the Taptic Engine once at launch, from `MainTabView`.
    static func prepare() {
        guard enabled else { return }
        softGen.prepare()
        rigidGen.prepare()
        selectionGen.prepare()
    }

    // MARK: The six names every existing call site uses

    static func tap() {
        guard allow() else { return }
        fire(.tap)
    }

    static func medium() {
        guard allow() else { return }
        fire(.press)
    }

    static func selection() {
        guard allow() else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    /// A rising "ta-dum" instead of the system's hard double-thump.
    static func success() {
        guard allow() else { return }
        fire(.successA)
        // Inherits `Haptics`' MainActor isolation, so no hop and no `@Sendable`
        // gymnastics. Calls `fire` directly so the guard cannot swallow the second beat.
        Task {
            try? await Task.sleep(for: .milliseconds(HapticProfile.successGapMilliseconds))
            fire(.successB)
        }
    }

    static func warning() {
        guard allow() else { return }
        fire(.warning)
    }

    /// A falling double-tap instead of the system's triple buzz.
    static func error() {
        guard allow() else { return }
        fire(.errorA, rigid: true)
        Task {
            try? await Task.sleep(for: .milliseconds(HapticProfile.errorGapMilliseconds))
            fire(.errorB)
        }
    }

    // MARK: Added by the pull-to-refresh and Settings work

    /// The refresh landing beat — the softest thing in the app.
    static func refreshDone() {
        guard allow() else { return }
        fire(.refreshDone)
    }

    /// Fires the `.press` envelope at an explicitly passed strength so the Settings
    /// segmented control lets her feel the difference while choosing.
    static func preview(_ strength: HapticStrength) {
        guard allow() else { return }
        fire(.press, strength: strength)
    }

    // MARK: Plumbing

    /// 60ms re-entry guard. The bare `Date()` is correct here — this is not an
    /// injected-clock function, matching the `JournalStore.streak` /
    /// `RoutineStore.rollDayIfNeeded()` precedent.
    private static func allow() -> Bool {
        guard enabled else { return false }
        let now = Date()
        guard now.timeIntervalSince(lastFire) > 0.06 else { return false }
        lastFire = now
        return true
    }

    private static func fire(_ event: HapticEvent, rigid: Bool = false, strength: HapticStrength? = nil) {
        let resolved = strength ?? Haptics.strength
        let generator = rigid ? rigidGen : softGen
        generator.impactOccurred(intensity: CGFloat(HapticProfile.intensity(event, strength: resolved)))
        generator.prepare()
    }
}
