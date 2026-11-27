import Foundation
import Observation
import SkintelCore

/// Composition root. One instance for the app's lifetime, injected via `.environment`.
/// Feature stores are created here so they share the same clients and session.
@MainActor
@Observable
final class AppEnvironment {
    let config: AppConfiguration
    let session: SessionManager
    let db: PostgRESTClient
    let api: SkintelAPI

    let products: ProductStore
    let subscription: SubscriptionStore
    let scans: ScanStore
    let routine: RoutineStore
    let journal: JournalStore
    let assistant: AssistantStore
    let subscriptionService: SubscriptionService
    let analytics: any Analytics

    /// A widget deep link waiting for the signed-in tab UI to route it (see
    /// `MainTabView`). Dropped when the user is signed out or still onboarding.
    var pendingDeepLink: SkintelDeepLink?

    /// A question waiting for Ask Skintel's composer, set when "Ask Skinstel about this scan"
    /// closes the face scan (`MainTabView`). `AssistantView` puts it in the composer, not sent,
    /// and clears it, so it is used once.
    var pendingAsk: PendingAsk?

    init(config: AppConfiguration) {
        self.config = config
        let http = HTTPClient(timeout: 20, logger: DebugLog.network)
        let session = SessionManager(auth: GoTrueClient(config: config.supabase, http: http))
        self.session = session
        self.db = PostgRESTClient(config: config.supabase, http: http, tokens: session)
        self.api = SkintelAPI(config: config.api, http: HTTPClient(timeout: 45, logger: DebugLog.network), tokens: session)
        self.analytics = LogAnalytics()
        self.products = ProductStore(db: db)
        self.subscription = SubscriptionStore(db: db, session: session)
        self.scans = ScanStore()
        self.routine = RoutineStore()
        self.journal = JournalStore(api: api)
        self.assistant = AssistantStore()
        self.subscriptionService = SubscriptionService(api: api, store: subscription, session: session, analytics: analytics)
    }

    /// Everything a signed-in user's screens need, loaded together after sign-in.
    func warmUp() async {
        // Day 1 face crops past day 14 are deleted on launch too, not only when the face scan
        // opens, so a week nobody comes back to (a free scan that never upgrades) still lets go.
        FaceScanStore.shared.expireDay1Crops(now: Date())
        // Ready before any Skintel+ wall opens, so a test build shows its chosen wall style
        // straight away. Runs alongside; nothing below waits on it.
        Task { await subscriptionService.checkBuildEnvironment() }
        // Last session's shelf first, so Today draws straight away; the fetch below refreshes it.
        if let userID = session.user?.id { products.restoreCache(userID: userID) }
        async let p: () = products.load()
        async let s: () = subscription.load()
        _ = await (p, s)
        subscriptionService.startObserving()
        await subscriptionService.reconcileSilently()
    }

    func resetAfterSignOut() {
        pendingDeepLink = nil
        pendingAsk = nil
        products.reset()
        subscription.reset()
        scans.reset()
        routine.reset()
        journal.reset()
        assistant.reset()
        FaceScanStore.shared.reset()
        FaceScanFlowView.resetPreferences()
    }
}

/// What `AssistantView` opens with when it is handed a question from elsewhere in the app.
struct PendingAsk: Equatable, Sendable {
    var question: String
    /// Put the Face scan tag in the composer with the question.
    var faceScan: Bool
}

enum DebugLog {
    /// Method + path + status only. Never headers, bodies, or tokens.
    static let network: (@Sendable (String) -> Void)? = {
        #if DEBUG
        return { line in print("[net] \(line)") }
        #else
        return nil
        #endif
    }()
}
