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
    let snapshot = ShelfWidgetSnapshot(count: 6, names: ["a", "b", "c", "d", "e"],
                                       outcomes: [.good, .bad, .unsure, .good, .bad])
    #expect(snapshot.names == ["a", "b", "c", "d"])
    #expect(snapshot.outcomes == [.good, .bad, .unsure, .good])
    #expect(ShelfSnapshotStore.write(snapshot, to: defaults))
    #expect(!ShelfSnapshotStore.write(snapshot, to: defaults))   // unchanged → no reload
    #expect(ShelfSnapshotStore.read(from: defaults) == snapshot)
    #expect(ShelfSnapshotStore.clear(in: defaults))
    #expect(!ShelfSnapshotStore.clear(in: defaults))
    #expect(ShelfSnapshotStore.read(from: defaults) == nil)
    #expect(!ShelfSnapshotStore.write(snapshot, to: nil))
}

@Test func shelfSnapshotWrittenBeforeOutcomesStillDecodes() throws {
    let suite = "skintel-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    defaults.set(Data(#"{"count":2,"names":["a","b"]}"#.utf8), forKey: ShelfSnapshotStore.key)
    let snapshot = try #require(ShelfSnapshotStore.read(from: defaults))
    #expect(snapshot.count == 2)
    #expect(snapshot.names == ["a", "b"])
    #expect(snapshot.outcomes == nil)
    #expect(snapshot.outcome(at: 0) == nil)
}

@MainActor
@Test func shelfWidgetSnapshotCarriesOnlyCountFirstNamesAndOutcomes() {
    let outcomes: [Outcome] = [.good, .bad, .unsure, .good, .bad]
    let products = (1...5).map { i in
        ProductWithIngredients(
            product: Product(id: "p\(i)", userID: "u", brand: "Brand", productName: "Product \(i)",
                             category: nil, outcome: outcomes[i - 1], notes: "private note",
                             createdAt: "2026-01-0\(i)", updatedAt: "2026-01-0\(i)"),
            ingredients: [])
    }
    let snapshot = ShelfWidgetSync.snapshot(of: products)
    #expect(snapshot == ShelfWidgetSnapshot(count: 5,
                                            names: ["Product 1", "Product 2", "Product 3", "Product 4"],
                                            outcomes: [.good, .bad, .unsure, .good]))
    #expect(snapshot.outcome(at: 1) == .bad)
    #expect(snapshot.outcome(at: 4) == nil)
    #expect(ShelfWidgetSync.snapshot(of: []) == ShelfWidgetSnapshot(count: 0, names: []))
}
