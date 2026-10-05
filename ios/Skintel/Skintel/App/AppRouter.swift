import SwiftUI
import SkintelCore

/// Launch/session routing derived from `SessionManager` + the onboarding flag in
/// `user_metadata`. The splash stays up until the Keychain has been read, so there is
/// never a sign-in screen flashing before Home.
enum AppRoute: Equatable {
    case launching
    case signedOut
    case onboarding
    case main

    static func resolve(_ state: SessionManager.State, onboardingSkippedLocally: Bool) -> AppRoute {
        switch state {
        case .restoring: .launching
        case .signedOut: .signedOut
        case .signedIn(let s):
            (s.user.onboardingComplete || onboardingSkippedLocally) ? .main : .onboarding
        }
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    /// Users who tap "Skip for now" after a profile-save failure on the last onboarding
    /// step shouldn't be stuck re-attempting it every launch on this device; the server
    /// flag (`onboardingComplete`) is still the durable truth once the save succeeds.
    @AppStorage("onboarding.skipped") private var onboardingSkipped = false
    /// Onboarding just finished: the Skintel+ offer shows once before the app opens.
    @AppStorage(OnboardingOfferView.pendingKey) private var offerPending = false
    @State private var warmed = false

    private var route: AppRoute {
        AppRoute.resolve(env.session.state, onboardingSkippedLocally: onboardingSkipped)
    }

    var body: some View {
        ZStack {
            switch route {
            case .launching:
                SplashView().transition(.opacity)
            case .signedOut:
                AuthFlow().transition(.opacity)
            case .onboarding:
                OnboardingFlow().transition(.opacity)
            case .main:
                if offerPending {
                    OnboardingOfferView {
                        withAnimation(SKAnimation.ios(0.35)) { offerPending = false }
                    }
                    .transition(.opacity)
                } else {
                    MainTabView().transition(.opacity)
                }
            }
        }
        .animation(SKAnimation.ios(0.35), value: route)
        .task { await env.session.restore() }
        // Widget links (skintel://scan|ask|shelf|checkin). Kept while the session is still
        // restoring so a cold launch lands where the widget pointed; signed-out users just
        // see the normal welcome flow, and onboarding isn't interrupted.
        .onOpenURL { url in
            guard let link = SkintelDeepLink(url: url) else { return }
            switch route {
            case .launching, .main: env.pendingDeepLink = link
            case .signedOut, .onboarding: env.pendingDeepLink = nil
            }
        }
        .onChange(of: route, initial: true) { _, new in
            switch new {
            case .main:
                if !warmed { warmed = true; Task { await env.warmUp() } }
            case .onboarding:
                env.pendingDeepLink = nil
                if !warmed { warmed = true; Task { await env.warmUp() } }
            case .signedOut:
                warmed = false
                onboardingSkipped = false
                offerPending = false
                env.resetAfterSignOut()
            case .launching:
                break
            }
        }
    }
}

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            SKColor.bg.ignoresSafeArea()
            VStack(spacing: SKSpace.lg) {
                Spacer()
                VStack(spacing: SKSpace.md) {
                    SKAppMark(size: 84)
                    Text("Skintel").font(SKFont.serif(34, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink)
                    Capsule().fill(SKColor.primary.opacity(0.4)).frame(width: 28, height: 2)
                }
                .opacity(shown ? 1 : 0)
                Spacer()
                Text("Know what touches your skin.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    .padding(.bottom, SKSpace.xxl)
                    .opacity(shown ? 1 : 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Skintel. Know what touches your skin.")
        }
        .onAppear {
            if reduceMotion { shown = true }
            else { withAnimation(SKAnimation.emil(0.7)) { shown = true } }
        }
    }
}

/// Shown instead of the app when Info.plist lacks the client configuration.
struct ConfigErrorView: View {
    let error: Error
    var body: some View {
        ZStack {
            SKColor.bg.ignoresSafeArea()
            VStack(spacing: SKSpace.lg) {
                SKAppMark(size: 64)
                Text("Skintel isn't configured").font(SKFont.section).foregroundStyle(SKColor.ink)
                Text(error.localizedDescription)
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            .padding(SKSpace.xxl)
        }
    }
}
