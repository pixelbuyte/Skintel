import SwiftUI

// MARK: - Registry

/// Every one-time tip in the app, one per screen moment. They all live here so
/// Settings › Personalization › "Reset tips" can bring every one back.
///
/// Rules (see the skintel-onboarding skill): a tip explains one thing in plain words,
/// only states what the code and server actually do, and names Skintel+ where a part of
/// the screen is Skintel+. The screen decides when its state is real (`skHint(_:when:)`).
enum HintID: String, CaseIterable, Sendable {
    case today, shelf, insights, ask, compare, routine, scan, verdict

    /// Shown-once flag. Set only when the person taps "Got it", taps outside the card or
    /// skips all tips — never just because the tip appeared. Stored per install, so
    /// people who already had an account see the tips too.
    var key: String { "hint.\(rawValue).seen" }

    /// The still drop on the card (an asset in Resources/Assets.xcassets).
    var drop: String {
        switch self {
        case .today: "DropCheckIn"
        case .shelf: "DropCompare"
        case .insights: "DropInsights"
        case .ask: "DropAsk"
        case .compare: "DropCompare"
        case .routine: "DropRoutineBuilder"
        case .scan: "DropScanner"
        case .verdict: "DropIngredients"
        }
    }

    /// Ask and Today can already have the animated mascot on screen; one character per
    /// screen, so their cards skip the still drop.
    var showsDrop: Bool {
        switch self {
        case .today, .ask: false
        default: true
        }
    }

    var title: String {
        switch self {
        case .today: "This is Today"
        case .shelf: "Tag how each product went"
        case .insights: "Your week at a glance"
        case .ask: "Ask about your products"
        case .compare: "Compare side by side"
        case .routine: "Your routine, in order"
        case .scan: "Scan a product"
        case .verdict: "Reading a verdict"
        }
    }

    /// About two lines. `isPro` only changes the wording where a Skintel+ part must be named.
    func message(isPro: Bool) -> String {
        switch self {
        case .today:
            isPro
                ? "Tick off routine steps and log your skin in one tap. Tap + to scan, add a product or check in."
                : "Tick off routine steps and log your skin in one tap. Tap + to add a product or check in."
        case .shelf:
            isPro
                ? "Mark each product Worked, Unsure or Broke out. With two “Broke out” products, Triggers looks for what they share."
                : "Mark each product Worked, Unsure or Broke out. With two “Broke out” products, Triggers (Skintel+) looks for what they share."
        case .insights:
            "Built only from your routine ticks, check-ins and shelf. It gets sharper after about a week of check-ins."
        case .ask:
            "Type @ to tag up to three products from your shelf, and Skintel reads their full ingredient lists."
        case .compare:
            "Pick two products from your shelf or paste an ingredient list. Skintel scores each one and names a winner."
        case .routine:
            isPro
                ? "Tap a step to tick it off, or Reorder to drag it into place. “Check for conflicts” looks for actives that clash."
                : "Tap a step to tick it off, or Reorder to drag it into place. “Check for conflicts” (Skintel+) looks for actives that clash."
        case .scan:
            "Point at the barcode on the back. No barcode? Tap “Type it” or “Photo of ingredients”."
        case .verdict:
            "The score and label are the overall call. “Why this verdict” lists the ingredients behind it."
        }
    }

    /// True until any tip has been dismissed, so the first one also offers "Skip all tips".
    static var noneSeen: Bool {
        !allCases.contains { UserDefaults.standard.bool(forKey: $0.key) }
    }

    static func skipAll() {
        for id in allCases { UserDefaults.standard.set(true, forKey: id.key) }
    }

    /// Settings › Personalization › "Reset tips".
    static func resetAll() {
        for id in allCases { UserDefaults.standard.set(false, forKey: id.key) }
    }
}

// MARK: - Modifier

extension View {
    /// Shows `id`'s one-time tip over this screen about 0.8 s after it appears, once
    /// `condition` holds. Pass the real state the tip explains (a non-empty shelf, a live
    /// camera) and keep it false behind a Skintel+ wall. Attach it to the screen's root
    /// content (inside its NavigationStack) so the tip leaves with the screen.
    func skHint(_ id: HintID, when condition: Bool = true) -> some View {
        modifier(SKHintModifier(id: id, isEligible: condition))
    }
}

private struct SKHintModifier: ViewModifier {
    let id: HintID
    let isEligible: Bool

    @AppStorage private var seen: Bool
    @State private var isShowing = false
    @State private var offersSkipAll = false
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(id: HintID, isEligible: Bool) {
        self.id = id
        self.isEligible = isEligible
        _seen = AppStorage(wrappedValue: false, id.key)
    }

    private var shouldShow: Bool { isEligible && !seen }

    private var hintAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : SKAnimation.emil(0.45)
    }

    /// Reduce Motion: fade only, no slide.
    private var cardTransition: AnyTransition {
        reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .bottom).combined(with: .opacity)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack(alignment: .bottom) {
                    if isShowing && shouldShow {
                        SKColor.ink.opacity(0.45)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { close(skippingAll: false) }
                            .accessibilityHidden(true)
                            .transition(.opacity)
                        SKHintCard(id: id,
                                   message: id.message(isPro: env.subscription.entitlement.isPro),
                                   offersSkipAll: offersSkipAll,
                                   gotIt: { close(skippingAll: false) },
                                   skipAll: { close(skippingAll: true) })
                            .padding(.horizontal, SKSpace.lg)
                            .padding(.bottom, SKSpace.lg)
                            .transition(cardTransition)
                    }
                }
            }
            .task(id: shouldShow) {
                guard shouldShow else {
                    isShowing = false
                    return
                }
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled, shouldShow else { return }
                offersSkipAll = HintID.noneSeen
                withAnimation(hintAnimation) { isShowing = true }
            }
            // Pushed away or dismissed before "Got it": nothing is marked, and the tip comes
            // back (after the same delay) the next time the screen appears.
            .onDisappear { isShowing = false }
    }

    private func close(skippingAll: Bool) {
        withAnimation(hintAnimation) {
            isShowing = false
            if skippingAll { HintID.skipAll() } else { seen = true }
        }
    }
}

// MARK: - Card

/// Cream card near the bottom: one drop, a title, about two lines of plain words,
/// "Got it", and "Skip all tips" on the first tip. VoiceOver focus moves to the text,
/// and the card is modal until it's dismissed.
private struct SKHintCard: View {
    let id: HintID
    let message: String
    let offersSkipAll: Bool
    let gotIt: () -> Void
    let skipAll: () -> Void

    @AccessibilityFocusState private var textFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            // Drop and title on one row, the explanation full width under them so it stays
            // about two lines on a phone.
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack(alignment: .center, spacing: SKSpace.md) {
                    if id.showsDrop {
                        SKDrop(id.drop, size: 64)
                    }
                    Text(id.title)
                        .font(SKFont.section)
                        .foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(message)
                    .font(SKFont.sans(16, relativeTo: .body))
                    .foregroundStyle(SKColor.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tip. \(id.title). \(message)")
            .accessibilityFocused($textFocused)

            VStack(spacing: SKSpace.xs) {
                SKButton(title: "Got it", action: gotIt)
                if offersSkipAll {
                    Button(action: skipAll) {
                        Text("Skip all tips")
                            .font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(SKColor.muted)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(SKSpace.xl)
        .frame(maxWidth: 500)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.sheet, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.sheet, style: .continuous).stroke(SKColor.line))
        .skSoftShadow()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { gotIt() }
        .task {
            // Let the card land, then move VoiceOver to it so the tip is read out.
            try? await Task.sleep(for: .milliseconds(350))
            if !Task.isCancelled { textFocused = true }
        }
    }
}
