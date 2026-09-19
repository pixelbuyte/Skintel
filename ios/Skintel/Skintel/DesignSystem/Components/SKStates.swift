import SwiftUI
import SkintelCore

/// One loading/loaded/failed shape for every async screen, so no view invents its own.
enum Loadable<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(APIError)

    var value: Value? { if case .loaded(let v) = self { return v }; return nil }
    var isLoading: Bool { if case .loading = self { return true }; return false }
    var error: APIError? { if case .failed(let e) = self { return e }; return nil }
}

struct SKLoadingView: View {
    var message: String? = nil
    var body: some View {
        VStack(spacing: SKSpace.md) {
            ProgressView().tint(SKColor.primary)
            if let message {
                Text(message).font(SKFont.secondary).foregroundStyle(SKColor.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(message ?? "Loading")
    }
}

/// Skeleton row used while lists load (keeps layout stable, no spinner jump).
struct SKSkeleton: View {
    var height: CGFloat = 72
    @State private var phase = false
    var body: some View {
        RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
            .fill(SKColor.neutralChip)
            .frame(height: height)
            .opacity(phase ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: phase)
            .onAppear { phase = true }
            .accessibilityHidden(true)
    }
}

struct SKEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: SKSpace.md) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(SKColor.primary)
                .frame(width: 64, height: 64)
                .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text(title).font(SKFont.section).foregroundStyle(SKColor.ink).multilineTextAlignment(.center)
            Text(message).font(SKFont.secondary).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
            if let actionTitle, let action {
                SKButton(title: actionTitle, fullWidth: false, action: action).padding(.top, SKSpace.sm)
            }
        }
        .padding(SKSpace.xxl)
        .frame(maxWidth: .infinity)
    }
}

struct SKErrorState: View {
    let error: APIError
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: SKSpace.md) {
            // The mascot speaks for Skintel's own state, so the red alarm tile is gone:
            // this matches `SKEmptyState`'s blush-tile rhythm and takes red out of the
            // state entirely. Offline naps; everything else looks worried.
            SKMascot(mood: error == .offline ? .sleeping : .worried, size: 52)
                .frame(width: 76, height: 76)
                .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(error == .offline ? "You're offline" : "That didn't go through")
                .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
            Text(error.userMessage).font(SKFont.secondary).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
            if let retry, error.isRetryable {
                SKButton(title: "Try again", kind: .secondary, fullWidth: false, action: retry)
            }
        }
        .padding(SKSpace.xxl)
        .frame(maxWidth: .infinity)
    }
}

/// Inline error under a form or inside a sheet.
struct SKInlineError: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: SKSpace.sm) {
            // Renders the mascot's small form (body + two round cream eyes), static.
            // The surrounding `.foregroundStyle(SKColor.badFg)` does not reach it — the
            // mascot fills explicitly, and terracotta on `badBg` is on-palette.
            SKMascot(mood: .worried, size: 20, animated: false)
            Text(message).font(SKFont.secondary)
        }
        .foregroundStyle(SKColor.badFg)
        .padding(SKSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKColor.badBg, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
        .accessibilityLabel("Error: \(message)")
    }
}

struct SKOfflineBanner: View {
    var body: some View {
        HStack(spacing: SKSpace.sm) {
            Image(systemName: "wifi.slash")
            Text("Offline — showing what's saved on this phone.")
        }
        .font(SKFont.caption)
        .foregroundStyle(SKColor.cautionFg)
        .padding(.horizontal, SKSpace.md)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(SKColor.cautionBg)
    }
}

// MARK: - Pull to refresh

/// Pull-to-refresh with the mascot instead of the system wheel, and one true sentence
/// computed on this phone as the payoff.
///
/// SwiftUI's own `.refreshable` stays underneath, so the gesture, the VoiceOver
/// "Refresh" action and the async lifecycle stay system-correct on iOS 17. The band is
/// an `.overlay`, not a `safeAreaInset`, so nothing in the page shifts.
///
/// The system indicator is suppressed with `.tint(.clear)` scoped to this modifier;
/// each screen re-applies `.tint(SKColor.primary)` on its inner content container so
/// nothing else inherits clear.
struct SKPetRefresh: ViewModifier {
    let action: @Sendable () async -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var phase: Phase = .idle
    @State private var line = ""

    enum Phase: Hashable, Sendable { case idle, looking, landed }

    /// Held for at least this long even when the refresh returns from a warm cache in
    /// 80ms — a 200ms flash reads as a glitch, not as work.
    private static let lookingFloor: Double = 0.7
    /// How long the payoff line stays up after the refresh has already finished.
    private static let landedHold = 1_100

    func body(content: Content) -> some View {
        content
            .refreshable { await run() }
            .overlay(alignment: .top) { band }
            .tint(.clear)
    }

    @ViewBuilder
    private var band: some View {
        if phase != .idle {
            HStack(spacing: SKSpace.sm) {
                SKMascot(mood: phase == .landed ? .happy : .searching, size: 30)
                if phase == .landed, !line.isEmpty {
                    Text(line)
                        .font(SKFont.secondary)
                        .foregroundStyle(SKColor.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, SKSpace.sm)
            .padding(.trailing, phase == .landed ? SKSpace.lg : SKSpace.sm)
            .padding(.vertical, SKSpace.sm)
            .background(SKColor.cream, in: Capsule())
            .overlay(Capsule().stroke(SKColor.line, lineWidth: 1))
            .skSoftShadow()
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.sm)
            .tint(SKColor.primary)
            // The looking band is transient decoration; only the payoff line is read out.
            .accessibilityHidden(phase != .landed)
            .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .top)))
            .task(id: phase) { await settle() }
        }
    }

    /// Everything that mutates state lives here, explicitly on the main actor, because
    /// `.refreshable`'s action is `@Sendable` and is not statically MainActor-isolated.
    /// The closure above stays exactly `await run()`.
    @MainActor
    private func run() async {
        let started = Date()
        withAnimation(SKAnimation.emil(0.35)) { phase = .looking }

        await action()

        let remaining = Self.lookingFloor - Date().timeIntervalSince(started)
        if remaining > 0 {
            try? await Task.sleep(for: .milliseconds(Int((remaining * 1000).rounded())))
        }
        guard !Task.isCancelled else {
            withAnimation(SKAnimation.ios(0.3)) { phase = .idle }
            return
        }

        // Never reports success or failure — it reports what is on the phone, which is
        // still true even when the refresh itself failed.
        line = checkInLine()
        Haptics.refreshDone()
        withAnimation(SKAnimation.emil(0.4)) { phase = .landed }
    }

    @MainActor
    private func settle() async {
        guard phase == .landed else { return }
        try? await Task.sleep(for: .milliseconds(Self.landedHold))
        guard !Task.isCancelled else { return }
        withAnimation(SKAnimation.ios(0.3)) { phase = .idle }
    }

    @MainActor
    private func checkInLine() -> String {
        let progress = env.routine.progress(for: RoutineStore.currentSlot())
        return CheckIn.line(productCount: env.products.products.count,
                            badProductCount: env.products.badProductCount,
                            topTrigger: env.products.culprits.all.first,
                            journalStreak: env.journal.streak,
                            routineDone: progress.done,
                            routineTotal: progress.total,
                            lastScanAt: env.scans.recent.first?.scannedAt,
                            now: Date())
    }
}

extension View {
    /// Drop-in replacement for `.refreshable { … }` on Home, Journal and the Shelf.
    func skPetRefresh(action: @escaping @Sendable () async -> Void) -> some View {
        modifier(SKPetRefresh(action: action))
    }
}
