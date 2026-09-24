import Foundation
import SkintelCore
import WidgetKit

/// Keeps the Shelf widget's snapshot (App Group `UserDefaults`) in step with `ProductStore`.
/// Only product names and the count are written; the widget timeline is reloaded only when
/// that snapshot actually changed.
@MainActor
enum ShelfWidgetSync {
    static func snapshot(of products: [ProductWithIngredients]) -> ShelfWidgetSnapshot {
        ShelfWidgetSnapshot(count: products.count,
                            names: products.prefix(ShelfWidgetSnapshot.maxNames).map(\.product.productName))
    }

    static func publish(_ products: [ProductWithIngredients]) {
        if ShelfSnapshotStore.write(snapshot(of: products), to: ShelfSnapshotStore.sharedDefaults()) {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.Kind.shelf)
        }
    }

    /// Sign-out: the next account must never see the previous one's shelf.
    static func clear() {
        if ShelfSnapshotStore.clear(in: ShelfSnapshotStore.sharedDefaults()) {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.Kind.shelf)
        }
    }
}
