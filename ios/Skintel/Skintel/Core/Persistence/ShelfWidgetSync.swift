import Foundation
import SkintelCore
import WidgetKit

/// Keeps the Shelf widget's snapshot (App Group `UserDefaults`) in step with `ProductStore`.
/// Only the count and the first products' names and outcomes are written; the widget timeline
/// is reloaded only when that snapshot actually changed.
@MainActor
enum ShelfWidgetSync {
    static func snapshot(of products: [ProductWithIngredients]) -> ShelfWidgetSnapshot {
        let shown = products.prefix(ShelfWidgetSnapshot.maxNames)
        return ShelfWidgetSnapshot(count: products.count,
                                   names: shown.map(\.product.productName),
                                   outcomes: shown.map { ShelfWidgetOutcome($0.product.outcome) })
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

extension ShelfWidgetOutcome {
    init(_ outcome: Outcome) {
        switch outcome {
        case .good: self = .good
        case .bad: self = .bad
        case .unsure: self = .unsure
        }
    }
}
