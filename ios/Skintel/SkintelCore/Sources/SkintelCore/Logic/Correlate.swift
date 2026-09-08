import Foundation

/// Exact port of src/lib/correlate.ts — co-occurrence, not temporal. An ingredient is a
/// culprit when it appears in at least two products the user marked `bad`; it is
/// downgraded to `medium` risk if it also appears in any `good` product.
public enum Correlate {
    public struct Result: Sendable {
        public var high: [Culprit]
        public var medium: [Culprit]
        public var all: [Culprit] { high + medium }
        /// Keyed by `inci_normalized`, the shape `categorizeIngredients` and `/api/scan-ai` consume.
        public var byNormalized: [String: Culprit] {
            Dictionary(uniqueKeysWithValues: all.map { ($0.normalized, $0) })
        }
    }

    private struct Bucket {
        var rawName: String
        var productIDs = Set<String>()
        var productNames: [String] = []   // insertion order, like a JS Set
    }

    public static func run(_ products: [ProductWithIngredients]) -> Result {
        var bad: [String: Bucket] = [:]
        var good: [String: Bucket] = [:]
        var badOrder: [String] = []       // preserve Map insertion order before sorting

        for p in products {
            switch p.product.outcome {
            case .bad:
                for i in p.ingredients {
                    if bad[i.inciNormalized] == nil {
                        bad[i.inciNormalized] = Bucket(rawName: i.inciRaw)
                        badOrder.append(i.inciNormalized)
                    }
                    bad[i.inciNormalized]!.productIDs.insert(p.product.id)
                    if !bad[i.inciNormalized]!.productNames.contains(p.product.productName) {
                        bad[i.inciNormalized]!.productNames.append(p.product.productName)
                    }
                }
            case .good:
                for i in p.ingredients {
                    if good[i.inciNormalized] == nil { good[i.inciNormalized] = Bucket(rawName: i.inciRaw) }
                    good[i.inciNormalized]!.productIDs.insert(p.product.id)
                    if !good[i.inciNormalized]!.productNames.contains(p.product.productName) {
                        good[i.inciNormalized]!.productNames.append(p.product.productName)
                    }
                }
            case .unsure:
                continue
            }
        }

        var high: [Culprit] = []
        var medium: [Culprit] = []
        for key in badOrder {
            let b = bad[key]!
            if b.productIDs.count < 2 { continue }
            let g = good[key]
            let goodCount = g?.productIDs.count ?? 0
            let c = Culprit(
                name: b.rawName,
                normalized: key,
                badCount: b.productIDs.count,
                goodCount: goodCount,
                badProducts: b.productNames,
                goodProducts: g?.productNames ?? [],
                risk: goodCount > 0 ? .medium : .high
            )
            if c.risk == .high { high.append(c) } else { medium.append(c) }
        }

        let order: (Culprit, Culprit) -> Bool = { a, b in
            if a.badCount != b.badCount { return a.badCount > b.badCount }
            return a.normalized.compare(b.normalized) == .orderedAscending
        }
        high.sort(by: order)
        medium.sort(by: order)
        return Result(high: high, medium: medium)
    }
}
