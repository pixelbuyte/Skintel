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
