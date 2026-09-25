import Foundation
import Testing
import SkintelCore
@testable import Skintel

// Widget plumbing shared by the app and the SkintelWidgets extension.

@Test func deepLinksRoundTripThroughTheirURLs() {
    for link in SkintelDeepLink.allCases {
        #expect(link.url.absoluteString == "skintel://\(link.rawValue)")
        #expect(SkintelDeepLink(url: link.url) == link)
    }
    #expect(SkintelDeepLink(url: URL(string: "SKINTEL://Scan")!) == .scan)
    #expect(SkintelDeepLink(url: URL(string: "skintel://unknown")!) == nil)
    #expect(SkintelDeepLink(url: URL(string: "https://scan")!) == nil)
}

@Test func shelfSnapshotStoreWritesOnlyChangesAndClears() throws {
    let suite = "skintel-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    #expect(ShelfSnapshotStore.read(from: defaults) == nil)
    let snapshot = ShelfWidgetSnapshot(count: 5, names: ["a", "b", "c", "d"])
    #expect(snapshot.names == ["a", "b", "c"])
    #expect(ShelfSnapshotStore.write(snapshot, to: defaults))
    #expect(!ShelfSnapshotStore.write(snapshot, to: defaults))   // unchanged → no reload
    #expect(ShelfSnapshotStore.read(from: defaults) == snapshot)
    #expect(ShelfSnapshotStore.clear(in: defaults))
    #expect(!ShelfSnapshotStore.clear(in: defaults))
    #expect(ShelfSnapshotStore.read(from: defaults) == nil)
    #expect(!ShelfSnapshotStore.write(snapshot, to: nil))
}

@MainActor
@Test func shelfWidgetSnapshotCarriesOnlyCountAndFirstNames() {
    let products = (1...4).map { i in
        ProductWithIngredients(
            product: Product(id: "p\(i)", userID: "u", brand: "Brand", productName: "Product \(i)",
                             category: nil, outcome: .good, notes: "private note",
                             createdAt: "2026-01-0\(i)", updatedAt: "2026-01-0\(i)"),
            ingredients: [])
    }
    let snapshot = ShelfWidgetSync.snapshot(of: products)
    #expect(snapshot == ShelfWidgetSnapshot(count: 4, names: ["Product 1", "Product 2", "Product 3"]))
    #expect(ShelfWidgetSync.snapshot(of: []) == ShelfWidgetSnapshot(count: 0, names: []))
}
