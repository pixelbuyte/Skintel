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
    /// The "Face scan is here" demo, once per phone, before sign-in or onboarding.
    @AppStorage(FeatureIntroView.seenKey) private var introSeen = false
    /// Seeing the demo here counts as seeing Today's What's New for the same feature.
    @AppStorage(FaceScanWhatsNewSheet.seenKey) private var whatsNewSeen = false
    @State private var warmed = false

    private var showsIntro: Binding<Bool> {
        Binding(get: { !introSeen && (route == .signedOut || route == .onboarding) },
                set: { if !$0 { introSeen = true; whatsNewSeen = true } })
    }

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
        .sheet(isPresented: showsIntro) {
            FeatureIntroView { showsIntro.wrappedValue = false }
                .interactiveDismissDisabled()
        }
        .task { await env.session.restore() }
        // Widget links (skintel://scan|ask|shelf|checkin). Kept while the session is still
        // restoring so a cold launch lands where the widget pointed; signed-out users just
        // see the normal welcome flow, and onboarding isn't interrupted.
        .onOpenURL { url in
            // skintel://auth-callback belongs to the Google sign-in web session, which
            // captures it itself; never treat it as a widget link.
            if url.host()?.lowercased() == OAuthPKCE.callbackHost { return }
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
