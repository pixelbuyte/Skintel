import Foundation

/// Exact port of src/lib/ingredient-knowledge.ts — the curated table that drives the
/// "good for your skin" bucket and the local (non-AI) verdict copy.
///
/// Note the table uses its **own** normaliser (strip everything non-alphanumeric),
/// which differs from `INCI.normalize`. Both are kept as-is so lookups match the web.
public enum IngredientKnowledge {
    public enum Category: String, Sendable, Codable, CaseIterable {
        case hydrator, barrier, emollient, occlusive, active, spf, peptide,
             antioxidant, soothing, filler, preservative, fragrance

        /// Chip label shown in the product INCI list (design §11).
        public var label: String {
            switch self {
            case .hydrator: "Hydrator"
            case .barrier: "Barrier"
            case .emollient: "Emollient"
            case .occlusive: "Occlusive"
            case .active: "Active"
            case .spf: "SPF"
            case .peptide: "Peptide"
            case .antioxidant: "Antioxidant"
            case .soothing: "Soothing"
            case .filler: "Filler"
            case .preservative: "Preservative"
            case .fragrance: "Fragrance"
            }
        }
    }

    public struct Info: Sendable, Hashable {
        public let name: String
        public let category: Category
        public let benefit: String
    }

    public static let positiveCategories: Set<Category> = [
        .hydrator, .barrier, .active, .spf, .peptide, .antioxidant, .soothing,
    ]

    static let fragranceTokens: Set<String> = [
        "fragrance", "parfum", "perfume", "linalool", "limonene",
        "citronellol", "geraniol", "citral", "eugenol", "cinnamal",
    ]

    /// lowercase → non-alphanumerics to a single space → trim → collapse
    public static func normalizeKey(_ name: String) -> String {
        var s = name.lowercased()
        s = s.replacing(/[^a-z0-9]+/, with: " ")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacing(/\s+/, with: " ")
        return s
    }

    public static func lookup(_ rawName: String) -> Info? {
        map[normalizeKey(rawName)]
    }

    public static func isFragrance(_ rawName: String) -> Bool {
        fragranceTokens.contains(normalizeKey(rawName))
    }

    // MARK: - Buckets + local verdict

    public struct CulpritMatch: Sendable, Hashable {
        public var name: String
        public var risk: Culprit.Risk
        public var badCount: Int
        public init(name: String, risk: Culprit.Risk, badCount: Int) {
            self.name = name; self.risk = risk; self.badCount = badCount
        }
        public init(_ c: Culprit) { self.init(name: c.name, risk: c.risk, badCount: c.badCount) }
    }

    public struct BucketRow: Sendable, Hashable, Identifiable {
        public var raw: String
        public var info: Info?
        public var culprit: CulpritMatch?
        public var isFragrance: Bool
        public var id: String { raw }
    }

    public struct Buckets: Sendable, Hashable {
        public var watchOut: [BucketRow]
        public var good: [BucketRow]
        public var rest: [BucketRow]
    }

    public static func categorize(_ parsed: [INCI.ParsedIngredient],
                                  culpritsByNormalized: [String: Culprit]) -> Buckets {
        var watchOut: [BucketRow] = []
        var good: [BucketRow] = []
        var rest: [BucketRow] = []
        for i in parsed {
            if let c = culpritsByNormalized[i.normalized] {
                watchOut.append(BucketRow(raw: i.raw, info: nil, culprit: CulpritMatch(c), isFragrance: false))
                continue
            }
            let info = lookup(i.raw)
            if let info, positiveCategories.contains(info.category) {
                good.append(BucketRow(raw: i.raw, info: info, culprit: nil, isFragrance: false))
                continue
            }
            rest.append(BucketRow(raw: i.raw, info: info, culprit: nil, isFragrance: isFragrance(i.raw)))
        }
        return Buckets(watchOut: watchOut, good: good, rest: rest)
    }

    public struct LocalVerdict: Sendable, Hashable {
        public enum Tone: String, Sendable { case good, caution, bad }
        public var tone: Tone
        public var headline: String
        public var body: String
    }

    public static func verdict(_ b: Buckets) -> LocalVerdict {
        let w = b.watchOut.count
        if w == 0 {
            let benefits = b.good.count
            return LocalVerdict(
                tone: .good,
                headline: "✓ Safe for your skin",
                body: benefits > 0
                    ? "No personal triggers found. Contains \(benefits) ingredient\(benefits == 1 ? "" : "s") known to help."
                    : "No personal triggers found in this product."
            )
        }
        if w <= 1 {
            return LocalVerdict(
                tone: .caution,
                headline: "⚠ Caution. \(w) of your triggers",
                body: "One ingredient you've reacted to before. Patch test before regular use."
            )
        }
        return LocalVerdict(
            tone: .bad,
            headline: "✗ \(w) of your triggers found",
            body: "This product contains multiple ingredients linked to your past breakouts."
        )
    }

    // MARK: - Table

    private static let map: [String: Info] = Dictionary(
        raw.map { (normalizeKey($0.name), $0) },
        uniquingKeysWith: { first, _ in first }
    )

    static let raw: [Info] = [
        // Hydrators
        .init(name: "Glycerin", category: .hydrator, benefit: "Pulls water into skin"),
        .init(name: "Hyaluronic Acid", category: .hydrator, benefit: "Deep hydration"),
        .init(name: "Sodium Hyaluronate", category: .hydrator, benefit: "Lightweight hydration"),
        .init(name: "Sodium PCA", category: .hydrator, benefit: "Natural moisture factor"),
        .init(name: "Panthenol", category: .hydrator, benefit: "Hydrates + heals"),
        .init(name: "Propanediol", category: .hydrator, benefit: "Hydrates, lightweight"),
        .init(name: "Betaine", category: .hydrator, benefit: "Gentle hydrator"),
        .init(name: "Urea", category: .hydrator, benefit: "Hydrates + softens"),
        .init(name: "Trehalose", category: .hydrator, benefit: "Locks moisture"),
        .init(name: "Glycereth-26", category: .hydrator, benefit: "Hydrates, soft feel"),
        // Barrier
        .init(name: "Ceramide NP", category: .barrier, benefit: "Repairs skin barrier"),
        .init(name: "Ceramide AP", category: .barrier, benefit: "Repairs skin barrier"),
        .init(name: "Ceramide EOP", category: .barrier, benefit: "Locks barrier"),
        .init(name: "Ceramide NS", category: .barrier, benefit: "Barrier support"),
        .init(name: "Cholesterol", category: .barrier, benefit: "Barrier lipid"),
        .init(name: "Phytosphingosine", category: .barrier, benefit: "Barrier support"),
        .init(name: "Cetyl Alcohol", category: .barrier, benefit: "Softens, supports barrier"),
        .init(name: "Cetearyl Alcohol", category: .barrier, benefit: "Softens, supports barrier"),
        .init(name: "Stearyl Alcohol", category: .barrier, benefit: "Skin-softening fatty alcohol"),
        .init(name: "Behenyl Alcohol", category: .barrier, benefit: "Barrier lipid"),
        // Emollients
        .init(name: "Squalane", category: .emollient, benefit: "Lightweight skin-mimic oil"),
        .init(name: "Jojoba Oil", category: .emollient, benefit: "Sebum-mimic, non-greasy"),
        .init(name: "Caprylic/Capric Triglyceride", category: .emollient, benefit: "Light, non-comedogenic"),
        .init(name: "Isopropyl Myristate", category: .emollient, benefit: "Smooths skin"),
        .init(name: "Dimethicone", category: .emollient, benefit: "Silky finish, smooths"),
        .init(name: "Cyclopentasiloxane", category: .emollient, benefit: "Silky, fast-absorbing"),
        .init(name: "Sunflower Seed Oil", category: .emollient, benefit: "Soothing emollient"),
        .init(name: "Helianthus Annuus Seed Oil", category: .emollient, benefit: "Soothing emollient"),
        .init(name: "Argan Oil", category: .emollient, benefit: "Nourishing oil"),
        // Occlusives
        .init(name: "Petrolatum", category: .occlusive, benefit: "Seals moisture"),
        .init(name: "Shea Butter", category: .occlusive, benefit: "Rich emollient seal"),
        .init(name: "Butyrospermum Parkii Butter", category: .occlusive, benefit: "Rich emollient seal"),
        .init(name: "Beeswax", category: .occlusive, benefit: "Locks moisture in"),
        .init(name: "Lanolin", category: .occlusive, benefit: "Heavy occlusive"),
        // Actives
        .init(name: "Niacinamide", category: .active, benefit: "Calms redness, evens tone"),
        .init(name: "Retinol", category: .active, benefit: "Boosts cell turnover"),
        .init(name: "Retinal", category: .active, benefit: "Stronger retinoid"),
        .init(name: "Retinyl Palmitate", category: .active, benefit: "Gentle retinoid"),
        .init(name: "Bakuchiol", category: .active, benefit: "Plant-based retinoid alt"),
        .init(name: "Salicylic Acid", category: .active, benefit: "Unclogs pores (BHA)"),
        .init(name: "Glycolic Acid", category: .active, benefit: "Exfoliates surface (AHA)"),
        .init(name: "Lactic Acid", category: .active, benefit: "Gentle AHA exfoliant"),
        .init(name: "Mandelic Acid", category: .active, benefit: "Gentle AHA, sensitive-safe"),
        .init(name: "Azelaic Acid", category: .active, benefit: "Calms, evens tone"),
        .init(name: "Ascorbic Acid", category: .active, benefit: "Vitamin C, brightens"),
        .init(name: "Sodium Ascorbyl Phosphate", category: .active, benefit: "Stable vit C"),
        .init(name: "Tetrahexyldecyl Ascorbate", category: .active, benefit: "Oil-soluble vit C"),
        .init(name: "Tranexamic Acid", category: .active, benefit: "Fades dark spots"),
        .init(name: "Alpha Arbutin", category: .active, benefit: "Brightens dark spots"),
        // SPF
        .init(name: "Zinc Oxide", category: .spf, benefit: "Mineral broad-spectrum SPF"),
        .init(name: "Titanium Dioxide", category: .spf, benefit: "Mineral SPF"),
        .init(name: "Avobenzone", category: .spf, benefit: "UVA filter"),
        .init(name: "Octinoxate", category: .spf, benefit: "UVB filter"),
        .init(name: "Octocrylene", category: .spf, benefit: "UVB filter, stabilizer"),
        .init(name: "Tinosorb S", category: .spf, benefit: "Broad-spectrum filter"),
        .init(name: "Tinosorb M", category: .spf, benefit: "Broad-spectrum filter"),
        .init(name: "Uvinul A Plus", category: .spf, benefit: "UVA filter"),
        // Peptides
        .init(name: "Palmitoyl Pentapeptide-4", category: .peptide, benefit: "Signals collagen"),
        .init(name: "Palmitoyl Tripeptide-1", category: .peptide, benefit: "Firms skin"),
        .init(name: "Acetyl Hexapeptide-8", category: .peptide, benefit: "Relaxes fine lines"),
        .init(name: "Copper Tripeptide-1", category: .peptide, benefit: "Repair signal"),
        .init(name: "Matrixyl", category: .peptide, benefit: "Collagen support"),
        // Antioxidants
        .init(name: "Tocopherol", category: .antioxidant, benefit: "Vitamin E, antioxidant"),
        .init(name: "Tocopheryl Acetate", category: .antioxidant, benefit: "Stable vit E"),
        .init(name: "Ferulic Acid", category: .antioxidant, benefit: "Boosts vit C stability"),
        .init(name: "Resveratrol", category: .antioxidant, benefit: "Antioxidant"),
        .init(name: "Green Tea Extract", category: .antioxidant, benefit: "Calms, antioxidant"),
        .init(name: "Camellia Sinensis Leaf Extract", category: .antioxidant, benefit: "Green tea antioxidant"),
        .init(name: "Astaxanthin", category: .antioxidant, benefit: "Powerful antioxidant"),
        // Soothing
        .init(name: "Centella Asiatica Extract", category: .soothing, benefit: "Calms irritation"),
        .init(name: "Madecassoside", category: .soothing, benefit: "Calms, heals"),
        .init(name: "Allantoin", category: .soothing, benefit: "Soothes, heals"),
        .init(name: "Bisabolol", category: .soothing, benefit: "Calms redness"),
        .init(name: "Aloe Barbadensis Leaf Juice", category: .soothing, benefit: "Soothes + hydrates"),
        .init(name: "Beta-Glucan", category: .soothing, benefit: "Soothes + hydrates"),
        .init(name: "Colloidal Oatmeal", category: .soothing, benefit: "Soothes itch + redness"),
        // Fillers (neutral)
        .init(name: "Water", category: .filler, benefit: "Solvent base"),
        .init(name: "Aqua", category: .filler, benefit: "Solvent base"),
        .init(name: "Pentylene Glycol", category: .filler, benefit: "Hydrating solvent"),
        .init(name: "Butylene Glycol", category: .filler, benefit: "Hydrating solvent"),
        .init(name: "Disodium EDTA", category: .filler, benefit: "Stabilizer"),
        .init(name: "Xanthan Gum", category: .filler, benefit: "Thickener"),
        .init(name: "Carbomer", category: .filler, benefit: "Thickener"),
        .init(name: "Citric Acid", category: .filler, benefit: "pH adjuster"),
        .init(name: "Sodium Hydroxide", category: .filler, benefit: "pH adjuster"),
        .init(name: "Sodium Citrate", category: .filler, benefit: "pH buffer"),
        // Preservatives (neutral)
        .init(name: "Phenoxyethanol", category: .preservative, benefit: "Preservative"),
        .init(name: "Ethylhexylglycerin", category: .preservative, benefit: "Preservative booster"),
        .init(name: "Sodium Benzoate", category: .preservative, benefit: "Preservative"),
        .init(name: "Potassium Sorbate", category: .preservative, benefit: "Preservative"),
        .init(name: "Benzyl Alcohol", category: .preservative, benefit: "Preservative"),
    ]
}
