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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Users who tap "Maybe later" on the last onboarding step shouldn't be re-asked
    /// every launch on this device; the server flag is still the durable truth.
    @AppStorage("onboarding.skipped") private var onboardingSkipped = false
    @State private var warmed = false

    private var route: AppRoute {
        AppRoute.resolve(env.session.state, onboardingSkippedLocally: onboardingSkipped)
    }

    var body: some View {
        ZStack {
            SKColor.bg.ignoresSafeArea()
            switch route {
            case .launching:
                SplashView().transition(.opacity)
            case .signedOut:
                AuthFlow().transition(arrival)
            case .onboarding:
                OnboardingFlow().transition(arrival)
            case .main:
                MainTabView().transition(arrival)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: route)
        .task { await env.session.restore() }
        .onChange(of: route, initial: true) { _, new in
            switch new {
            case .main, .onboarding:
                if !warmed { warmed = true; Task { await env.warmUp() } }
            case .signedOut:
                warmed = false
                onboardingSkipped = false
                env.resetAfterSignOut()
            case .launching:
                break
            }
        }
    }

    private var arrival: AnyTransition {
        reduceMotion ? .identity : .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 12)),
            removal: .opacity
        )
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            SKColor.bg.ignoresSafeArea()
            SKAppMark(size: 84)
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
