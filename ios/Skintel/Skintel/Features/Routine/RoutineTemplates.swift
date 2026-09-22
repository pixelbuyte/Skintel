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
        .init(id: "beginner", name: "Daily essentials", blurb: "A simple place to start.",
              am: ["cleanser", "moisturizer", "sunscreen"], pm: ["cleanser", "moisturizer"]),
        .init(id: "antiaging", name: "Serum + care", blurb: "Room for your go-to serum.",
              am: ["cleanser", "serum", "moisturizer", "sunscreen"], pm: ["cleanser", "toner", "serum", "moisturizer"]),
        .init(id: "acne", name: "Evening reset", blurb: "An exfoliant step for evenings you choose.",
              am: ["cleanser", "moisturizer", "sunscreen"], pm: ["cleanser", "exfoliant", "moisturizer"]),
        .init(id: "sensitive", name: "Keep it gentle", blurb: "Just the basics, morning and night.",
              am: ["cleanser", "moisturizer", "sunscreen"], pm: ["cleanser", "moisturizer"]),
        .init(id: "glow", name: "Extra layers", blurb: "Make space for toner and serum.",
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
