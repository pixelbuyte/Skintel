import Foundation
import Observation
import StoreKit
import SkintelCore

/// StoreKit 2. The App Store is the payment rail; the backend (`/api/apple-verify`) is
/// the entitlement authority — a purchase only counts once the server has verified the
/// signed transaction and written the `subscriptions` row. The app never grants Pro on
/// its own say-so.
@MainActor
@Observable
final class SubscriptionService {
    enum ProductID: String, CaseIterable {
        case proMonthly = "com.skintel.app.pro.monthly"
        case proYearly = "com.skintel.app.pro.yearly"
        case founding = "com.skintel.app.founding"

        var tier: Tier { self == .founding ? .founding : .pro }
    }

    enum Phase: Equatable {
        case idle
        case loadingProducts
        case ready
        case purchasing(String)
        case verifying
        case restoring
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var products: [Product] = []
    private(set) var lastMessage: String?

    private let api: SkintelAPI
    private let store: SubscriptionStore
    private let session: SessionManager
    private let analytics: any Analytics
    private var updatesTask: Task<Void, Never>?

    init(api: SkintelAPI, store: SubscriptionStore, session: SessionManager, analytics: any Analytics) {
        self.api = api
        self.store = store
        self.session = session
        self.analytics = analytics
    }

    func product(_ id: ProductID) -> Product? { products.first { $0.id == id.rawValue } }

    // MARK: Products

    func loadProducts() async {
        if products.isEmpty { phase = .loadingProducts }
        do {
            let fetched = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            products = fetched.sorted { a, b in
                (ProductID.allCases.firstIndex { $0.rawValue == a.id } ?? 0) < (ProductID.allCases.firstIndex { $0.rawValue == b.id } ?? 0)
            }
            phase = fetched.isEmpty ? .failed("Plans aren't available right now. Check your connection and try again.") : .ready
        } catch {
            phase = .failed("Couldn't load plans from the App Store.")
        }
    }

    /// Start observing transactions that finish outside a purchase call (renewals,
    /// Ask-to-Buy approvals, purchases on another device).
    func startObserving() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let tx) = update {
                    await self.report(tx)
                    await tx.finish()
                }
            }
        }
    }

    // MARK: Purchase

    func purchase(_ id: ProductID) async {
        guard let product = product(id) else { phase = .failed("That plan isn't available."); return }
        guard let uid = session.user?.id else { phase = .failed(APIError.unauthenticated.userMessage); return }
        phase = .purchasing(id.rawValue)
        lastMessage = nil
        analytics.track(.purchaseStarted(productID: id.rawValue))
        do {
            var options: Set<Product.PurchaseOption> = []
            // The Supabase user id is a UUID; carrying it in the transaction lets the server
            // bind the purchase to this account and lets notifications find the row.
            if let token = UUID(uuidString: uid) { options.insert(.appAccountToken(token)) }
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let tx):
                    phase = .verifying
                    await report(tx)
                    await tx.finish()
                case .unverified(_, let error):
                    phase = .failed("The App Store receipt couldn't be verified: \(error.localizedDescription)")
                    Haptics.error()
                }
            case .userCancelled:
                phase = .ready
            case .pending:
                phase = .ready
                lastMessage = "Waiting for approval — your plan activates once it's confirmed."
            @unknown default:
                phase = .ready
            }
        } catch {
            phase = .failed(error.localizedDescription)
            Haptics.error()
        }
    }

    /// Sends the signed transaction to the backend, which verifies it with Apple's root
    /// certificate and writes the subscription row that the whole app reads.
    private func report(_ tx: Transaction) async {
        do {
            let sub = try await api.verifyAppleTransaction(signedTransaction: tx.jwsRepresentation)
            store.apply(sub)
            analytics.track(.purchaseCompleted(productID: tx.productID))
            phase = .ready
            lastMessage = nil
            Haptics.success()
        } catch let e as APIError {
            // The purchase is real and finished; the row will be reconciled on the next
            // restore or launch. Say so instead of pretending it failed.
            phase = .failed("Purchased, but Skintel couldn't confirm it yet (\(e.userMessage)). Tap Restore in a moment.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: Restore / refresh

    /// Re-syncs with the App Store and reports every current entitlement to the backend.
    func restore() async {
        phase = .restoring
        lastMessage = nil
        do { try await AppStore.sync() } catch { /* sync is best-effort; entitlements below still work */ }
        var reported = 0
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let tx) = entitlement, ProductID(rawValue: tx.productID) != nil {
                await report(tx)
                reported += 1
            }
        }
        await store.load()
        analytics.track(.restoreCompleted)
        phase = .ready
        lastMessage = reported == 0 ? "No App Store purchases found for this Apple ID." : nil
        if reported == 0 { Haptics.warning() }
    }

    /// Cheap check at launch: if the App Store says we own something the row doesn't
    /// reflect, report it. Runs silently.
    func reconcileSilently() async {
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let tx) = entitlement, ProductID(rawValue: tx.productID) != nil else { continue }
            if !store.entitlement.isPro || store.subscription?.appleOriginalTransactionID != String(tx.originalID) {
                await report(tx)
            }
        }
    }

    // MARK: Display helpers

    func priceText(_ id: ProductID) -> String? { product(id)?.displayPrice }

    func periodText(_ id: ProductID) -> String {
        switch id {
        case .proMonthly: "/month"
        case .proYearly: "/year"
        case .founding: "once"
        }
    }
}
