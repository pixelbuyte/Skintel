import Foundation

/// How hard Skintel is allowed to buzz. Stored in `UserDefaults` under
/// `Haptics.strengthKey` and bound straight to `@AppStorage`, which is why the raw
/// value is a `String` — `@AppStorage` only accepts `RawRepresentable` where
/// `RawValue == String` or `Int`.
public enum HapticStrength: String, Codable, Sendable, CaseIterable, Identifiable {
    case gentle
    case medium
    case full

    public var id: String { rawValue }

    /// User-facing name for the Settings segmented control.
    public var label: String {
        switch self {
        case .gentle: "Gentle"
        case .medium: "Medium"
        case .full: "Full"
        }
    }

    /// Multiplier applied to every event's base intensity.
    public var scale: Double {
        switch self {
        case .gentle: 0.55
        case .medium: 0.78
        case .full: 1.00
        }
    }
}

/// Every beat the app is allowed to play. Two-beat gestures (`success`, `error`) are
/// spelled as two events so each beat gets its own amplitude and the shape survives
/// being scaled down to `.gentle`.
public enum HapticEvent: String, Sendable, CaseIterable {
    case tap
    case press
    case successA
    case successB
    case warning
    case errorA
    case errorB
    case refreshDone

    /// Amplitude at `HapticStrength.full`, before the floor is applied.
    /// Nothing here exceeds 0.62 — that ceiling is the whole point of the rewrite.
    public var base: Double {
        switch self {
        case .tap: 0.45
        case .press: 0.55
        case .successA: 0.45
        case .successB: 0.62
        case .warning: 0.58
        case .errorA: 0.58
        case .errorB: 0.38
        case .refreshDone: 0.30
        }
    }
}

/// Pure amplitude maths, kept out of the app target so it can actually be tested on
/// Linux. The app-side `Haptics` enum owns the UIKit generators; this owns the numbers.
public enum HapticProfile {
    /// Below this the Taptic Engine produces something indistinguishable from nothing,
    /// so a quiet event degrades into a missing event. Live, not decorative:
    /// `refreshDone` at `.gentle` is 0.165 and gets clamped up to this.
    public static let floor: Double = 0.18

    /// Gap between the two beats of `success()` — a rising "ta-dum".
    public static let successGapMilliseconds: Int = 90

    /// Gap between the two beats of `error()` — a falling double-tap.
    public static let errorGapMilliseconds: Int = 110

    /// Amplitude to hand `UIImpactFeedbackGenerator.impactOccurred(intensity:)`.
    public static func intensity(_ event: HapticEvent, strength: HapticStrength) -> Double {
        min(1.0, max(floor, event.base * strength.scale))
    }
}
