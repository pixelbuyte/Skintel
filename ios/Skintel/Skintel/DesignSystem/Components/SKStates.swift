import SwiftUI
import SkintelCore
import SkinstelMascot

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
    /// Shows the mascot doing this in place of the icon tile. A `.wave` settles into `.idle`.
    var mascot: SkinstelMascotAction? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: SKSpace.md) {
            if let mascot {
                SKMascot(action: mascot, height: 132, settleAfter: mascot == .wave ? Duration.seconds(3) : nil)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(SKColor.primary)
                    .frame(width: 64, height: 64)
                    .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
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
            Image(systemName: error == .offline ? "wifi.slash" : "exclamationmark.triangle")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(SKColor.badFg)
                .frame(width: 56, height: 56)
                .background(SKColor.badBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(error == .offline ? "You're offline" : "Something went wrong")
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
            Image(systemName: "exclamationmark.circle").font(.system(size: 14, weight: .semibold))
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

/// The Skinstel mascot as a quiet, decorative companion. Hidden from VoiceOver by the
/// package, so the text next to it must say what is happening. Pass `settleAfter` for a
/// brief moment (a greeting, a celebration) that should return to `.idle` on its own.
struct SKMascot: View {
    let action: SkinstelMascotAction
    var height: CGFloat = 120
    var isPlaying = true
    var settleAfter: Duration? = nil
    @State private var settled = false

    var body: some View {
        SkinstelMascot(action: settled ? .idle : action, isPlaying: isPlaying)
            .frame(width: (height * 420 / 510).rounded(), height: height)
            .task(id: action) {
                settled = false
                guard let settleAfter else { return }
                try? await Task.sleep(for: settleAfter)
                if !Task.isCancelled { settled = true }
            }
    }
}
