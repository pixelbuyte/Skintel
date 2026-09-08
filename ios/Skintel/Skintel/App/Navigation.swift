import Foundation
import SkintelCore

/// Push destinations shared by the tab stacks.
enum AppDestination: Hashable {
    case products
    case productDetail(id: String)
    case productForm(ProductFormMode)
    case verdict(scanID: String)
    case culprits
    case routine
    case recommend
    case settings
}

enum ProductFormMode: Hashable {
    case add(prefill: ScanCandidate?)
    case edit(productID: String)
}

/// What the scanner (barcode / paste / photo / link / search) resolved, before analysis.
struct ScanCandidate: Hashable, Sendable {
    var brand: String?
    var productName: String?
    var inci: String
    var upc: String?
    var source: String

    var displayName: String {
        productName?.isEmpty == false ? productName! : (brand ?? "Unknown product")
    }

    var parsed: [INCI.ParsedIngredient] { INCI.parse(inci) }
}
