import type { ProductWithIngredients } from './types';

const PREVIEW_KEY = 'skintel_preview';

export function isPreview(): boolean {
  if (!import.meta.env.DEV) return false;
  if (typeof window === 'undefined') return false;
  const params = new URLSearchParams(window.location.search);
  if (params.has('preview')) {
    try {
      window.sessionStorage.setItem(PREVIEW_KEY, '1');
    } catch {}
    return true;
  }
  try {
    return window.sessionStorage.getItem(PREVIEW_KEY) === '1';
  } catch {
    return false;
  }
}

export function exitPreview() {
  try {
    window.sessionStorage.removeItem(PREVIEW_KEY);
  } catch {}
}

const now = new Date();
function daysAgo(n: number): string {
  return new Date(now.getTime() - n * 86400_000).toISOString();
}

function ing(product_id: string, list: string[]): ProductWithIngredients['product_ingredients'] {
  return list.map((raw, i) => ({
    id: `${product_id}-ing-${i}`,
    product_id,
    user_id: 'preview-user',
    position: i,
    inci_raw: raw,
    inci_normalized: raw.toLowerCase().replace(/\s+/g, ''),
  }));
}

export const PREVIEW_PRODUCTS: ProductWithIngredients[] = [
  {
    id: 'pv-1',
    user_id: 'preview-user',
    brand: 'CeraVe',
    product_name: 'Hydrating Cleanser',
    category: 'cleanser',
    outcome: 'good',
    notes: 'Gentle, no flare. Repurchased.',
    created_at: daysAgo(1),
    updated_at: daysAgo(1),
    product_ingredients: ing('pv-1', [
      'Aqua', 'Glycerin', 'Ceramide NP', 'Ceramide AP', 'Niacinamide', 'Hyaluronic Acid',
    ]),
  },
  {
    id: 'pv-2',
    user_id: 'preview-user',
    brand: 'Drunk Elephant',
    product_name: 'B-Hydra Intensive Hydration',
    category: 'serum',
    outcome: 'bad',
    notes: 'Cheek + jawline flare within 48h.',
    created_at: daysAgo(3),
    updated_at: daysAgo(3),
    product_ingredients: ing('pv-2', [
      'Aqua', 'Glycerin', 'Niacinamide', 'Bisabolol', 'Coconut Alkanes', 'Linalool', 'Fragrance',
    ]),
  },
  {
    id: 'pv-3',
    user_id: 'preview-user',
    brand: 'The Ordinary',
    product_name: 'Niacinamide 10% + Zinc 1%',
    category: 'serum',
    outcome: 'good',
    notes: 'No issues, calmed redness.',
    created_at: daysAgo(5),
    updated_at: daysAgo(5),
    product_ingredients: ing('pv-3', [
      'Aqua', 'Niacinamide', 'Pentylene Glycol', 'Zinc PCA', 'Tamarindus Indica Seed Gum',
    ]),
  },
  {
    id: 'pv-4',
    user_id: 'preview-user',
    brand: 'Glow Recipe',
    product_name: 'Watermelon Glow Toner',
    category: 'toner',
    outcome: 'bad',
    notes: 'Tiny bumps day 2. Bisabolol again?',
    created_at: daysAgo(7),
    updated_at: daysAgo(7),
    product_ingredients: ing('pv-4', [
      'Aqua', 'Glycerin', 'Bisabolol', 'Coconut Alkanes', 'Linalool', 'Limonene', 'Citronellol',
    ]),
  },
  {
    id: 'pv-5',
    user_id: 'preview-user',
    brand: 'Paula\'s Choice',
    product_name: '2% BHA Liquid',
    category: 'exfoliant',
    outcome: 'good',
    notes: 'Holy grail. Smooth skin.',
    created_at: daysAgo(10),
    updated_at: daysAgo(10),
    product_ingredients: ing('pv-5', [
      'Aqua', 'Methylpropanediol', 'Butylene Glycol', 'Salicylic Acid', 'Polysorbate 20', 'Camellia Oleifera Leaf Extract',
    ]),
  },
  {
    id: 'pv-6',
    user_id: 'preview-user',
    brand: 'La Roche-Posay',
    product_name: 'Toleriane Double Repair',
    category: 'moisturizer',
    outcome: 'good',
    notes: 'Daily driver.',
    created_at: daysAgo(14),
    updated_at: daysAgo(14),
    product_ingredients: ing('pv-6', [
      'Aqua', 'Glycerin', 'Niacinamide', 'Ceramide NP', 'Panthenol', 'Shea Butter',
    ]),
  },
  {
    id: 'pv-7',
    user_id: 'preview-user',
    brand: 'Sunday Riley',
    product_name: 'Good Genes Lactic Acid',
    category: 'treatment',
    outcome: 'unsure',
    notes: 'Glow boost but slight redness.',
    created_at: daysAgo(18),
    updated_at: daysAgo(18),
    product_ingredients: ing('pv-7', [
      'Aqua', 'Lactic Acid', 'Glycerin', 'Aloe Barbadensis Leaf Extract', 'Linalool', 'Limonene',
    ]),
  },
  {
    id: 'pv-8',
    user_id: 'preview-user',
    brand: 'Fenty Skin',
    product_name: 'Hydra Vizor SPF 30',
    category: 'sunscreen',
    outcome: 'good',
    notes: 'No white cast, no breakouts.',
    created_at: daysAgo(22),
    updated_at: daysAgo(22),
    product_ingredients: ing('pv-8', [
      'Aqua', 'Niacinamide', 'Glycerin', 'Zinc Oxide', 'Titanium Dioxide', 'Ceramide NP',
    ]),
  },
  {
    id: 'pv-9',
    user_id: 'preview-user',
    brand: 'Tatcha',
    product_name: 'Dewy Skin Cream',
    category: 'moisturizer',
    outcome: 'bad',
    notes: 'Heavy + fragrance flare.',
    created_at: daysAgo(28),
    updated_at: daysAgo(28),
    product_ingredients: ing('pv-9', [
      'Aqua', 'Glycerin', 'Squalane', 'Bisabolol', 'Limonene', 'Linalool', 'Geraniol', 'Fragrance',
    ]),
  },
  {
    id: 'pv-10',
    user_id: 'preview-user',
    brand: 'Stratia',
    product_name: 'Liquid Gold',
    category: 'moisturizer',
    outcome: 'good',
    notes: 'Barrier saver.',
    created_at: daysAgo(35),
    updated_at: daysAgo(35),
    product_ingredients: ing('pv-10', [
      'Aqua', 'Squalane', 'Ceramide NP', 'Ceramide AP', 'Cholesterol', 'Niacinamide',
    ]),
  },
];
