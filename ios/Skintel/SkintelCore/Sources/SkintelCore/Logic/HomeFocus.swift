import Foundation

/// The one thing Home asks her to do next, and the copy for it.
///
/// Home's job is the next sixty seconds, not a census of the shelf. This picks the single
/// nudge worth showing under the routine and hands back finished sentences, so the counts
/// she reads are covered by tests rather than assembled in a view.
///
/// Every nudge here must have somewhere to go that Home can actually reach. Anything whose
/// only home is another tab is deliberately absent — a card that cannot be acted on is the
/// four-counters problem wearing a different hat.
public enum HomeFocus {
    public struct Nudge: Sendable, Hashable, Identifiable {
        public enum Kind: String, Sendable, Hashable {
            /// Nothing on the shelf at all.
            case firstProduct
            /// Exactly one product: patterns need a second.
            case secondProduct
            /// Products sitting on "Unsure", which the pattern engines cannot use.
            case markOutcomes
            /// Shelf is usable but there is no routine to track against it.
            case buildRoutine
            /// Nothing needs her.
            case allSet
        }

        public var kind: Kind
        public var headline: String
        public var detail: String
        /// Set for `.markOutcomes`: the product to open when she taps through.
        public var productID: String?

        public var id: String { kind.rawValue }

        public init(kind: Kind, headline: String, detail: String, productID: String? = nil) {
            self.kind = kind
            self.headline = headline
            self.detail = detail
            self.productID = productID
        }
    }

    /// A shelf needs this many decided products before Skintel can say anything about
    /// what they share — the same floor `Correlate` works to.
    public static let patternFloor = 2

    /// - Parameters:
    ///   - productCount: everything on the shelf, decided or not.
    ///   - unsureProductIDs: products still marked "Unsure", oldest first.
    ///   - decidedCount: products marked either "Worked" or "Broke out".
    ///   - routineTotal: steps in the current slot.
    public static func nudge(productCount: Int,
                             unsureProductIDs: [String],
                             decidedCount: Int,
                             routineTotal: Int) -> Nudge {
        if productCount == 0 {
            return Nudge(kind: .firstProduct,
                         headline: "Start with one product",
                         detail: "Add what you used this morning and tell Skintel how your skin took it.")
        }

        if productCount == 1 {
            return Nudge(kind: .secondProduct,
                         headline: "One product on your shelf",
                         detail: "Add a second and Skintel can start finding what they share.")
        }

        // Unsure products are dead weight: they cost her a slot and tell the engines
        // nothing. Worth clearing before anything else, and more so while the shelf still
        // has too few decided products to find a pattern at all.
        if let first = unsureProductIDs.first {
            let n = unsureProductIDs.count
            let detail = decidedCount < patternFloor
                ? "Say how each one went and Skintel can start finding what they share."
                : "Skintel leaves these out until you say how they went."
            return Nudge(kind: .markOutcomes,
                         headline: n == 1 ? "1 product still unsure" : "\(n) products still unsure",
                         detail: detail,
                         productID: first)
        }

        if routineTotal == 0 {
            return Nudge(kind: .buildRoutine,
                         headline: "No routine yet",
                         detail: "Build one from your shelf and Skintel can track what you actually use.")
        }

        return Nudge(kind: .allSet,
                     headline: "Nothing needs you",
                     detail: "Your shelf is up to date. Skintel keeps watching as you log.")
    }
}
