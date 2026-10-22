import Foundation
import Observation
import SkintelCore

/// The user's shelf. Single source for every screen that lists, counts or correlates
/// products, so Home, Culprits, Routine and the scanner all agree.
@MainActor
@Observable
final class ProductStore {
    private(set) var state: Loadable<[ProductWithIngredients]> = .idle
    private let db: PostgRESTClient
    private let cacheURL: URL

    init(db: PostgRESTClient, directory: URL? = nil) {
        self.db = db
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Skintel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheURL = dir.appendingPathComponent("shelf.v1.json")
    }

    /// The last shelf saved on this device, shown at launch so Today doesn't sit on a
    /// skeleton while the network fetch runs; `load()` replaces it moments later.
    func restoreCache(userID: String) {
        guard state.value == nil,
              let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode(CachedShelf.self, from: data),
              cached.userID == userID else { return }
        state = .loaded(cached.products)
    }

    var products: [ProductWithIngredients] { state.value ?? [] }
    var isLoaded: Bool { state.value != nil }

    func product(id: String) -> ProductWithIngredients? {
        products.first { $0.id == id }
    }

    /// Home's four numbers — the same product-outcome counts `Dashboard.tsx` shows.
    var counts: (total: Int, good: Int, unsure: Int, bad: Int) {
        let p = products
        return (p.count,
                p.filter { $0.product.outcome == .good }.count,
                p.filter { $0.product.outcome == .unsure }.count,
                p.filter { $0.product.outcome == .bad }.count)
    }

    /// Local co-occurrence culprits, recomputed from the current shelf.
    var culprits: Correlate.Result { Correlate.run(products) }

    var badProductCount: Int { products.filter { $0.product.outcome == .bad }.count }

    func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            let list = try await db.products()
            state = .loaded(list)
            ShelfWidgetSync.publish(list)
            persist(list)
        }
        catch let e as APIError {
            // Keep stale data visible on a transient failure; only show the error state cold.
            if state.value == nil { state = .failed(e) }
        } catch { if state.value == nil { state = .failed(.network(error.localizedDescription)) } }
    }

    @discardableResult
    func add(userID: String, brand: String?, name: String, category: String?, outcome: Outcome,
             notes: String?, ingredients: [INCI.ParsedIngredient]) async throws -> Product {
        let input = PostgRESTClient.ProductInput(userID: userID, brand: blank(brand), productName: name,
                                                 category: blank(category), outcome: outcome, notes: blank(notes))
        let created = try await db.addProduct(input, ingredients: ingredients)
        await load()
        return created
    }

    func update(id: String, userID: String, patch: PostgRESTClient.ProductPatch,
                ingredients: [INCI.ParsedIngredient]?) async throws {
        try await db.updateProduct(id: id, userID: userID, patch: patch, ingredients: ingredients)
        await load()
    }

    func delete(id: String) async throws {
        try await db.deleteProduct(id: id)
        if var list = state.value {
            list.removeAll { $0.id == id }
            state = .loaded(list)
            ShelfWidgetSync.publish(list)
            persist(list)
        }
    }

    /// Sign-out: also wipes the Shelf widget's snapshot.
    func reset() {
        state = .idle
        ShelfWidgetSync.clear()
        try? FileManager.default.removeItem(at: cacheURL)
    }

    private struct CachedShelf: Codable {
        var userID: String
        var products: [ProductWithIngredients]
    }

    private func persist(_ list: [ProductWithIngredients]) {
        // An empty shelf has no owner to check against, so it isn't worth caching.
        guard let owner = list.first?.product.userID,
              let data = try? JSONEncoder().encode(CachedShelf(userID: owner, products: list)) else {
            try? FileManager.default.removeItem(at: cacheURL)
            return
        }
        try? data.write(to: cacheURL, options: [.atomic, .completeFileProtection])
    }

    private func blank(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
}

/// Product categories offered by the web's add/edit forms.
enum ProductCategory: String, CaseIterable, Identifiable, Sendable {
    case cleanser = "Cleanser"
    case toner = "Toner"
    case serum = "Serum"
    case treatment = "Treatment"
    case moisturizer = "Moisturizer"
    case sunscreen = "Sunscreen"
    case mask = "Mask"
    case eye = "Eye"
    case body = "Body"
    case makeup = "Makeup"
    case hair = "Hair"
    case other = "Other"

    var id: String { rawValue }
}
