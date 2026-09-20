import Foundation
import SwiftUI
import SkintelCore

/// "What should I compare next" built entirely from the user's own shelf — no analysis
/// request. Reuses the same local co-occurrence culprits Home and Culprits already compute
/// (`Correlate.run`), so a suggestion can point at a shared personal trigger for free.
struct CompareSuggestion: Identifiable {
    let id: String
    let first: ProductWithIngredients
    let second: ProductWithIngredients
    let reason: String
}

enum CompareSuggestions {
    static func build(from products: [ProductWithIngredients], culprits: Correlate.Result, limit: Int = 3) -> [CompareSuggestion] {
        guard products.count >= 2 else { return [] }
        let triggerNames = Dictionary(uniqueKeysWithValues: culprits.byNormalized.map { ($0.key, $0.value.name) })
        var used = Set<String>()
        var suggestions: [CompareSuggestion] = []

        func pairKey(_ a: ProductWithIngredients, _ b: ProductWithIngredients) -> String {
            [a.id, b.id].sorted().joined(separator: "|")
        }
        func sharedTrigger(_ a: ProductWithIngredients, _ b: ProductWithIngredients) -> String? {
            let aKeys = Set(a.ingredients.map(\.inciNormalized))
            let bKeys = Set(b.ingredients.map(\.inciNormalized))
            for key in aKeys.intersection(bKeys) { if let name = triggerNames[key] { return name } }
            return nil
        }

        // Same category, different outcome: the actual "which one is right for me" question.
        let byCategory = Dictionary(grouping: products) { $0.product.category?.isEmpty == false ? $0.product.category! : nil }
        for (category, group) in byCategory {
            guard category != nil, group.count >= 2 else { continue }
            let sorted = group.sorted { $0.product.createdAt > $1.product.createdAt }
            outer: for i in sorted.indices {
                for j in (i + 1)..<sorted.count {
                    let a = sorted[i], b = sorted[j]
                    guard a.product.outcome != b.product.outcome else { continue }
                    let key = pairKey(a, b)
                    guard !used.contains(key) else { continue }
                    used.insert(key)
                    let reason: String
                    if let trigger = sharedTrigger(a, b) {
                        reason = "Both contain \(trigger) — one of your personal triggers."
                    } else {
                        reason = "Same category, different results on your skin."
                    }
                    suggestions.append(CompareSuggestion(id: key, first: a, second: b, reason: reason))
                    if suggestions.count >= limit { break outer }
                }
            }
            if suggestions.count >= limit { break }
        }

        // Fall back to the two most recent scans so there is always something to try.
        if suggestions.isEmpty {
            let recent = products.sorted { $0.product.createdAt > $1.product.createdAt }
            if recent.count >= 2 {
                let a = recent[0], b = recent[1]
                suggestions.append(CompareSuggestion(id: pairKey(a, b), first: a, second: b,
                                                      reason: "Your two most recent scans."))
            }
        }

        return Array(suggestions.prefix(limit))
    }
}

/// Suggested pairs shown above the manual picker when the shelf has enough history.
struct CompareSuggestionsSection: View {
    let suggestions: [CompareSuggestion]
    let onPick: (CompareSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            Text("Suggested for you").font(SKFont.section).foregroundStyle(SKColor.ink)
            ForEach(suggestions) { s in
                Button { onPick(s) } label: {
                    SKCard(padding: SKSpace.md) {
                        HStack(alignment: .top, spacing: SKSpace.md) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(s.first.product.productName) vs \(s.second.product.productName)")
                                    .font(SKFont.bodyMedium).foregroundStyle(SKColor.ink).lineLimit(2)
                                Text(s.reason).font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
                        }
                    }
                }
                .buttonStyle(SKPressStyle())
            }
        }
    }
}

/// Shown in place of the picker grid when there isn't enough shelf history for a suggestion.
struct CompareEmptyPrompt: View {
    let scanCount: Int
    var body: some View {
        SKCard {
            VStack(spacing: SKSpace.md) {
                SKMascot(size: 64)
                Text(scanCount == 0 ? "Scan two products to compare them" : "One more scan unlocks a suggestion")
                    .font(SKFont.cardTitle).foregroundStyle(SKColor.ink).multilineTextAlignment(.center)
                Text("Once you've saved a couple of products, Skintel can suggest pairs worth comparing from your own shelf.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
