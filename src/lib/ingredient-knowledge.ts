/**
 * Static skincare ingredient knowledge — drives the "Good for your skin" bucket
 * + verdict surface. Curated, not exhaustive. ~80 INCI entries.
 *
 * Categories:
 *  - hydrator  : humectants / hyaluronic family
 *  - barrier   : ceramides, fatty alcohols, lipids
 *  - emollient : neutral skin-feel oils
 *  - occlusive : seals moisture in
 *  - active    : evidence-backed bioactives (retinoids, AHA/BHA, niacinamide…)
 *  - spf       : UV filters
 *  - peptide   : signaling peptides
 *  - antioxidant
 *  - soothing
 *  - filler    : neutral, not flagged
 *  - preservative
 *  - fragrance : flagged as common irritant
 */
export type IngredientCategory =
  | 'hydrator'
  | 'barrier'
  | 'emollient'
  | 'occlusive'
  | 'active'
  | 'spf'
  | 'peptide'
  | 'antioxidant'
  | 'soothing'
  | 'filler'
  | 'preservative'
  | 'fragrance';

export type IngredientInfo = {
  name: string;
  category: IngredientCategory;
  benefit: string;
};

const RAW: IngredientInfo[] = [
  // Hydrators
  { name: 'Glycerin', category: 'hydrator', benefit: 'Pulls water into skin' },
  { name: 'Hyaluronic Acid', category: 'hydrator', benefit: 'Deep hydration' },
  { name: 'Sodium Hyaluronate', category: 'hydrator', benefit: 'Lightweight hydration' },
  { name: 'Sodium PCA', category: 'hydrator', benefit: 'Natural moisture factor' },
  { name: 'Panthenol', category: 'hydrator', benefit: 'Hydrates + heals' },
  { name: 'Propanediol', category: 'hydrator', benefit: 'Hydrates, lightweight' },
  { name: 'Betaine', category: 'hydrator', benefit: 'Gentle hydrator' },
  { name: 'Urea', category: 'hydrator', benefit: 'Hydrates + softens' },
  { name: 'Trehalose', category: 'hydrator', benefit: 'Locks moisture' },
  { name: 'Glycereth-26', category: 'hydrator', benefit: 'Hydrates, soft feel' },

  // Barrier
  { name: 'Ceramide NP', category: 'barrier', benefit: 'Repairs skin barrier' },
  { name: 'Ceramide AP', category: 'barrier', benefit: 'Repairs skin barrier' },
  { name: 'Ceramide EOP', category: 'barrier', benefit: 'Locks barrier' },
  { name: 'Ceramide NS', category: 'barrier', benefit: 'Barrier support' },
  { name: 'Cholesterol', category: 'barrier', benefit: 'Barrier lipid' },
  { name: 'Phytosphingosine', category: 'barrier', benefit: 'Barrier support' },
  { name: 'Cetyl Alcohol', category: 'barrier', benefit: 'Softens, supports barrier' },
  { name: 'Cetearyl Alcohol', category: 'barrier', benefit: 'Softens, supports barrier' },
  { name: 'Stearyl Alcohol', category: 'barrier', benefit: 'Skin-softening fatty alcohol' },
  { name: 'Behenyl Alcohol', category: 'barrier', benefit: 'Barrier lipid' },

  // Emollients
  { name: 'Squalane', category: 'emollient', benefit: 'Lightweight skin-mimic oil' },
  { name: 'Jojoba Oil', category: 'emollient', benefit: 'Sebum-mimic, non-greasy' },
  { name: 'Caprylic/Capric Triglyceride', category: 'emollient', benefit: 'Light, non-comedogenic' },
  { name: 'Isopropyl Myristate', category: 'emollient', benefit: 'Smooths skin' },
  { name: 'Dimethicone', category: 'emollient', benefit: 'Silky finish, smooths' },
  { name: 'Cyclopentasiloxane', category: 'emollient', benefit: 'Silky, fast-absorbing' },
  { name: 'Sunflower Seed Oil', category: 'emollient', benefit: 'Soothing emollient' },
  { name: 'Helianthus Annuus Seed Oil', category: 'emollient', benefit: 'Soothing emollient' },
  { name: 'Argan Oil', category: 'emollient', benefit: 'Nourishing oil' },

  // Occlusives
  { name: 'Petrolatum', category: 'occlusive', benefit: 'Seals moisture' },
  { name: 'Shea Butter', category: 'occlusive', benefit: 'Rich emollient seal' },
  { name: 'Butyrospermum Parkii Butter', category: 'occlusive', benefit: 'Rich emollient seal' },
  { name: 'Beeswax', category: 'occlusive', benefit: 'Locks moisture in' },
  { name: 'Lanolin', category: 'occlusive', benefit: 'Heavy occlusive' },

  // Actives
  { name: 'Niacinamide', category: 'active', benefit: 'Calms redness, evens tone' },
  { name: 'Retinol', category: 'active', benefit: 'Boosts cell turnover' },
  { name: 'Retinal', category: 'active', benefit: 'Stronger retinoid' },
  { name: 'Retinyl Palmitate', category: 'active', benefit: 'Gentle retinoid' },
  { name: 'Bakuchiol', category: 'active', benefit: 'Plant-based retinoid alt' },
  { name: 'Salicylic Acid', category: 'active', benefit: 'Unclogs pores (BHA)' },
  { name: 'Glycolic Acid', category: 'active', benefit: 'Exfoliates surface (AHA)' },
  { name: 'Lactic Acid', category: 'active', benefit: 'Gentle AHA exfoliant' },
  { name: 'Mandelic Acid', category: 'active', benefit: 'Gentle AHA, sensitive-safe' },
  { name: 'Azelaic Acid', category: 'active', benefit: 'Calms, evens tone' },
  { name: 'Ascorbic Acid', category: 'active', benefit: 'Vitamin C — brightens' },
  { name: 'Sodium Ascorbyl Phosphate', category: 'active', benefit: 'Stable vit C' },
  { name: 'Tetrahexyldecyl Ascorbate', category: 'active', benefit: 'Oil-soluble vit C' },
  { name: 'Tranexamic Acid', category: 'active', benefit: 'Fades dark spots' },
  { name: 'Alpha Arbutin', category: 'active', benefit: 'Brightens dark spots' },

  // SPF
  { name: 'Zinc Oxide', category: 'spf', benefit: 'Mineral broad-spectrum SPF' },
  { name: 'Titanium Dioxide', category: 'spf', benefit: 'Mineral SPF' },
  { name: 'Avobenzone', category: 'spf', benefit: 'UVA filter' },
  { name: 'Octinoxate', category: 'spf', benefit: 'UVB filter' },
  { name: 'Octocrylene', category: 'spf', benefit: 'UVB filter, stabilizer' },
  { name: 'Tinosorb S', category: 'spf', benefit: 'Broad-spectrum filter' },
  { name: 'Tinosorb M', category: 'spf', benefit: 'Broad-spectrum filter' },
  { name: 'Uvinul A Plus', category: 'spf', benefit: 'UVA filter' },

  // Peptides
  { name: 'Palmitoyl Pentapeptide-4', category: 'peptide', benefit: 'Signals collagen' },
  { name: 'Palmitoyl Tripeptide-1', category: 'peptide', benefit: 'Firms skin' },
  { name: 'Acetyl Hexapeptide-8', category: 'peptide', benefit: 'Relaxes fine lines' },
  { name: 'Copper Tripeptide-1', category: 'peptide', benefit: 'Repair signal' },
  { name: 'Matrixyl', category: 'peptide', benefit: 'Collagen support' },

  // Antioxidants
  { name: 'Tocopherol', category: 'antioxidant', benefit: 'Vitamin E — antioxidant' },
  { name: 'Tocopheryl Acetate', category: 'antioxidant', benefit: 'Stable vit E' },
  { name: 'Ferulic Acid', category: 'antioxidant', benefit: 'Boosts vit C stability' },
  { name: 'Resveratrol', category: 'antioxidant', benefit: 'Antioxidant' },
  { name: 'Green Tea Extract', category: 'antioxidant', benefit: 'Calms, antioxidant' },
  { name: 'Camellia Sinensis Leaf Extract', category: 'antioxidant', benefit: 'Green tea antioxidant' },
  { name: 'Astaxanthin', category: 'antioxidant', benefit: 'Powerful antioxidant' },

  // Soothing
  { name: 'Centella Asiatica Extract', category: 'soothing', benefit: 'Calms irritation' },
  { name: 'Madecassoside', category: 'soothing', benefit: 'Calms, heals' },
  { name: 'Allantoin', category: 'soothing', benefit: 'Soothes, heals' },
  { name: 'Bisabolol', category: 'soothing', benefit: 'Calms redness' },
  { name: 'Aloe Barbadensis Leaf Juice', category: 'soothing', benefit: 'Soothes + hydrates' },
  { name: 'Beta-Glucan', category: 'soothing', benefit: 'Soothes + hydrates' },
  { name: 'Colloidal Oatmeal', category: 'soothing', benefit: 'Soothes itch + redness' },

  // Fillers (neutral)
  { name: 'Water', category: 'filler', benefit: 'Solvent base' },
  { name: 'Aqua', category: 'filler', benefit: 'Solvent base' },
  { name: 'Pentylene Glycol', category: 'filler', benefit: 'Hydrating solvent' },
  { name: 'Butylene Glycol', category: 'filler', benefit: 'Hydrating solvent' },
  { name: 'Disodium EDTA', category: 'filler', benefit: 'Stabilizer' },
  { name: 'Xanthan Gum', category: 'filler', benefit: 'Thickener' },
  { name: 'Carbomer', category: 'filler', benefit: 'Thickener' },
  { name: 'Citric Acid', category: 'filler', benefit: 'pH adjuster' },
  { name: 'Sodium Hydroxide', category: 'filler', benefit: 'pH adjuster' },
  { name: 'Sodium Citrate', category: 'filler', benefit: 'pH buffer' },

  // Preservatives (neutral)
  { name: 'Phenoxyethanol', category: 'preservative', benefit: 'Preservative' },
  { name: 'Ethylhexylglycerin', category: 'preservative', benefit: 'Preservative booster' },
  { name: 'Sodium Benzoate', category: 'preservative', benefit: 'Preservative' },
  { name: 'Potassium Sorbate', category: 'preservative', benefit: 'Preservative' },
  { name: 'Benzyl Alcohol', category: 'preservative', benefit: 'Preservative' },
];

function normalize(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

const MAP: Map<string, IngredientInfo> = new Map(RAW.map((i) => [normalize(i.name), i]));

// Fragrance markers handled separately — flagged as common irritant in verdict copy.
const FRAGRANCE_TOKENS = new Set([
  'fragrance',
  'parfum',
  'perfume',
  'linalool',
  'limonene',
  'citronellol',
  'geraniol',
  'citral',
  'eugenol',
  'cinnamal',
]);

export const POSITIVE_CATEGORIES: ReadonlySet<IngredientCategory> = new Set([
  'hydrator',
  'barrier',
  'active',
  'spf',
  'peptide',
  'antioxidant',
  'soothing',
]);

export function lookupIngredient(rawName: string): IngredientInfo | null {
  const key = normalize(rawName);
  return MAP.get(key) ?? null;
}

export function isFragrance(rawName: string): boolean {
  const key = normalize(rawName);
  return FRAGRANCE_TOKENS.has(key);
}

export type Culprit = { name: string; risk: 'high' | 'medium'; badCount: number };

export type BucketRow = {
  raw: string;
  info?: IngredientInfo;
  culprit?: Culprit;
  isFragrance?: boolean;
};

export type Buckets = {
  watchOut: BucketRow[];
  good: BucketRow[];
  rest: BucketRow[];
};

export function categorizeIngredients(
  parsed: { raw: string; normalized: string }[],
  culpritByNorm: Map<string, Culprit>
): Buckets {
  const watchOut: BucketRow[] = [];
  const good: BucketRow[] = [];
  const rest: BucketRow[] = [];

  for (const i of parsed) {
    const culprit = culpritByNorm.get(i.normalized);
    if (culprit) {
      watchOut.push({ raw: i.raw, culprit });
      continue;
    }
    const info = lookupIngredient(i.raw);
    if (info && POSITIVE_CATEGORIES.has(info.category)) {
      good.push({ raw: i.raw, info });
      continue;
    }
    rest.push({ raw: i.raw, info: info ?? undefined, isFragrance: isFragrance(i.raw) });
  }

  return { watchOut, good, rest };
}

export type Verdict = {
  tone: 'good' | 'caution' | 'bad';
  headline: string;
  body: string;
};

export function generateVerdict(buckets: Buckets): Verdict {
  const w = buckets.watchOut.length;
  if (w === 0) {
    const benefits = buckets.good.length;
    return {
      tone: 'good',
      headline: '✓ Safe for your skin',
      body:
        benefits > 0
          ? `No personal triggers found. Contains ${benefits} ingredient${benefits === 1 ? '' : 's'} known to help.`
          : 'No personal triggers found in this product.',
    };
  }
  if (w <= 1) {
    return {
      tone: 'caution',
      headline: `⚠ Caution — ${w} of your triggers`,
      body: `One ingredient you've reacted to before. Patch test before regular use.`,
    };
  }
  return {
    tone: 'bad',
    headline: `✗ ${w} of your triggers found`,
    body: `This product contains multiple ingredients linked to your past breakouts.`,
  };
}
