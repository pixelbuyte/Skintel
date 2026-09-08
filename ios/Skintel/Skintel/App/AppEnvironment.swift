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
    let subscriptionService: SubscriptionService
    let analytics: any Analytics

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
        self.subscriptionService = SubscriptionService(api: api, store: subscription, session: session, analytics: analytics)
    }

    /// Everything a signed-in user's screens need, loaded together after sign-in.
    func warmUp() async {
        async let p: () = products.load()
        async let s: () = subscription.load()
        _ = await (p, s)
        subscriptionService.startObserving()
        await subscriptionService.reconcileSilently()
    }

    func resetAfterSignOut() {
        products.reset()
        subscription.reset()
        scans.reset()
        routine.reset()
        journal.reset()
    }
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
