import Foundation
import SwiftUI
import SkintelCore

/// Ported from Routine.tsx TEMPLATES: category tags auto-filled from the shelf.
///
/// `id`, `am` and `pm` are frozen — `SkintelTests/AppLogicTests.swift` asserts on them.
/// Only the user-facing `name` and `blurb` are rewritten: the audience is explicitly not
/// the person who reads "BHA only PM" or "peptide layering".
struct RoutineTemplate: Identifiable, Sendable {
    let id: String
    let name: String
    let blurb: String
    let am: [String]
    let pm: [String]

    static let all: [RoutineTemplate] = [
        .init(id: "beginner", name: "Gentle Start", blurb: "Three steps. Nothing harsh.",
              am: ["cleanser", "moisturizer", "sunscreen"], pm: ["cleanser", "moisturizer"]),
        .init(id: "antiaging", name: "Firm & Smooth", blurb: "Brightening by day, renewal at night.",
              am: ["cleanser", "serum", "moisturizer", "sunscreen"], pm: ["cleanser", "toner", "serum", "moisturizer"]),
        .init(id: "acne", name: "Calm Breakouts", blurb: "Gentler by day. One treatment at night.",
              am: ["cleanser", "moisturizer", "sunscreen"], pm: ["cleanser", "exfoliant", "moisturizer"]),
        .init(id: "sensitive", name: "Sensitive Skin", blurb: "The shortest routine. Nothing that stings.",
              am: ["cleanser", "moisturizer", "sunscreen"], pm: ["cleanser", "moisturizer"]),
        .init(id: "glow", name: "Dewy Glow", blurb: "Layered hydration, morning and night.",
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

    /// Same matching rule as `fill`, but keeps every slot so the preview can show the
    /// gaps. `fill` drops unmatched tags, so its output cannot be aligned to slots
    /// positionally — hence a sibling rather than a refactor of the apply path.
    ///
    /// Invariant, verified by eye: for any `tags` and `products`,
    /// `fill(tags, from: products)` equals this result's non-nil `productID`s in order.
    func slots(_ tags: [String], from products: [ProductWithIngredients]) -> [(tag: String, productID: String?)] {
        var used = Set<String>()
        return tags.map { tag in
            let t = tag.lowercased()
            let match = products.first { p in
                !used.contains(p.id) &&
                ((p.product.category ?? "").lowercased().contains(t) || p.product.productName.lowercased().contains(t))
            }
            if let match { used.insert(match.id) }
            return (tag, match?.id)
        }
    }
}

/// One slot of a template preview: the tag the template asked for, and the shelf product
/// that filled it — `nil` when her shelf has nothing for it.
struct TemplateSlot: Sendable, Hashable {
    let tag: String
    let productID: String?
}

/// The templates sheet's whole explanation, drawn instead of written: her own products
/// dropping into the template's slots, with the gaps she can't fill left as dashed
/// ghosts. Replaces the paragraph about how category matching works.
///
/// Takes `products` as a parameter rather than reaching for `AppEnvironment`, so this
/// file stays free of app-environment coupling.
struct TemplatePreview: View {
    let template: RoutineTemplate
    let products: [ProductWithIngredients]

    @State private var amSlots: [TemplateSlot] = []
    @State private var pmSlots: [TemplateSlot] = []
    @State private var revealed = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            // A row whose tag list is empty is omitted entirely, never rendered empty.
            if !amSlots.isEmpty { row("AM", amSlots, startIndex: 0) }
            if !pmSlots.isEmpty { row("PM", pmSlots, startIndex: amSlots.count) }
        }
        .task(id: template.id) { await reveal() }
    }

    private func row(_ label: String, _ slots: [TemplateSlot], startIndex: Int) -> some View {
        HStack(alignment: .top, spacing: SKSpace.sm) {
            Text(label)
                .font(SKFont.label)
                .foregroundStyle(SKColor.muted)
                .frame(width: 24, alignment: .leading)
            ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                tile(slot, index: startIndex + i)
            }
        }
    }

    private func tile(_ slot: TemplateSlot, index: Int) -> some View {
        let shown = index < revealed
        let product = slot.productID.flatMap { id in products.first { $0.id == id } }
        return VStack(spacing: 4) {
            if let product {
                SKProductMark(name: product.product.productName, size: 36)
            } else {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(SKColor.line, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 36, height: 36)
            }
            // `ProductCategory` raw values are the capitalised forms, so this matches
            // what she sees everywhere else in the app.
            Text(slot.tag.capitalized)
                .font(SKFont.mono(9, relativeTo: .caption2))
                .foregroundStyle(SKColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 46)
        .opacity(shown ? 1 : 0)
        .scaleEffect(shown ? 1 : 0.7)
    }

    /// One shot per template change, never `repeatForever`. The slot cache is required,
    /// not an optimisation: `revealed` re-renders this view once per tile, and
    /// recomputing the match each time would re-scan the whole shelf every frame.
    private func reveal() async {
        let am = template.slots(template.am, from: products).map { TemplateSlot(tag: $0.tag, productID: $0.productID) }
        let pm = template.slots(template.pm, from: products).map { TemplateSlot(tag: $0.tag, productID: $0.productID) }
        amSlots = am
        pmSlots = pm

        let total = am.count + pm.count
        guard total > 0 else { revealed = 0; return }
        guard !reduceMotion else { revealed = total; return }

        revealed = 0
        for i in 1...total {
            try? await Task.sleep(for: .milliseconds(90))
            if Task.isCancelled { return }
            withAnimation(SKAnimation.emil(0.42)) { revealed = i }
        }
    }
}
