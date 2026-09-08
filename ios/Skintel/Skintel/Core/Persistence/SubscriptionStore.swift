import Foundation
import Observation
import SkintelCore

/// Mirrors the `subscriptions` row for the signed-in user and exposes the server-rule
/// `Entitlement`. StoreKit purchases land here via `apply(_:)` after the backend verifies
/// them, so there is exactly one place the app learns it is Pro.
@MainActor
@Observable
final class SubscriptionStore {
    private(set) var subscription: Subscription?
    private(set) var loaded = false
    private(set) var lastError: APIError?
    private(set) var foundingSeatsRemaining: Int?

    private let db: PostgRESTClient
    private let session: SessionManager

    init(db: PostgRESTClient, session: SessionManager) {
        self.db = db
        self.session = session
    }

    var entitlement: Entitlement { Entitlement(subscription) }

    func load() async {
        guard let uid = session.user?.id else { return }
        do {
            subscription = try await db.subscription(userID: uid)
            lastError = nil
        } catch let e as APIError {
            lastError = e
        } catch {
            lastError = .network(error.localizedDescription)
        }
        loaded = true
    }

    func loadFoundingSeats() async {
        foundingSeatsRemaining = try? await db.foundingSeatsRemaining()
    }

    func apply(_ s: Subscription) {
        subscription = s
        loaded = true
    }

    func reset() {
        subscription = nil
        loaded = false
        lastError = nil
    }
}
