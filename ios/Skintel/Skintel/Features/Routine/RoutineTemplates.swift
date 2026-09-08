import Foundation
import SkintelCore

/// Ported from Routine.tsx TEMPLATES: category tags auto-filled from the shelf.
struct RoutineTemplate: Identifiable, Sendable {
    let id: String
    let name: String
    let blurb: String
    let am: [String]
    let pm: [String]

    static let all: [RoutineTemplate] = [
        .init(id: "beginner", name: "Beginner Barrier Repair", blurb: "Gentle 3-step. Cleanser → moisturizer → SPF.",
              am: ["cleanser", "moisturizer", "sunscreen"], pm: ["cleanser", "moisturizer"]),
        .init(id: "antiaging", name: "Anti-Aging Stack", blurb: "Vitamin C AM, retinol PM, peptide layering.",
              am: ["cleanser", "serum", "moisturizer", "sunscreen"], pm: ["cleanser", "toner", "serum", "moisturizer"]),
        .init(id: "acne", name: "Acne-Prone Minimal", blurb: "Fewer actives, more barrier. BHA only PM.",
              am: ["cleanser", "moisturizer", "sunscreen"], pm: ["cleanser", "exfoliant", "moisturizer"]),
        .init(id: "sensitive", name: "Reactive / Sensitive", blurb: "Strip actives. Cream cleanser, ceramides, mineral SPF.",
              am: ["cleanser", "moisturizer", "sunscreen"], pm: ["cleanser", "moisturizer"]),
        .init(id: "glow", name: "Glass Skin Glow", blurb: "Hydration heavy. Niacinamide, HA, occlusive PM.",
              am: ["cleanser", "toner", "serum", "moisturizer", "sunscreen"], pm: ["cleanser", "toner", "serum", "moisturizer"]),
    ]

    /// First shelf product per tag whose category (or name) mentions it; tags with no match are skipped.
    func fill(_ tags: [String], from products: [ProductWithIngredients]) -> [String] {
        var used = Set<String>()
        return tags.compactMap { tag in
            let t = tag.lowercased()
            let match = products.first { p in
                !used.contains(p.id) &&
                ((p.product.category ?? "").lowercased().contains(t) || p.product.productName.lowercased().contains(t))
            }
            if let match { used.insert(match.id) }
            return match?.id
        }
    }
}
