import type { Culprit, ProductWithIngredients } from './types';

export function correlate(products: ProductWithIngredients[]): {
  high: Culprit[];
  medium: Culprit[];
} {
  const badMap = new Map<
    string,
    { rawName: string; productIds: Set<string>; productNames: Set<string> }
  >();
  const goodMap = new Map<
    string,
    { productIds: Set<string>; productNames: Set<string> }
  >();

  for (const p of products) {
    const ings = p.product_ingredients ?? [];
    if (p.outcome === 'bad') {
      for (const i of ings) {
        const entry = badMap.get(i.inci_normalized) ?? {
          rawName: i.inci_raw,
          productIds: new Set<string>(),
          productNames: new Set<string>(),
        };
        entry.productIds.add(p.id);
        entry.productNames.add(p.product_name);
        badMap.set(i.inci_normalized, entry);
      }
    } else if (p.outcome === 'good') {
      for (const i of ings) {
        const entry = goodMap.get(i.inci_normalized) ?? {
          productIds: new Set<string>(),
          productNames: new Set<string>(),
        };
        entry.productIds.add(p.id);
        entry.productNames.add(p.product_name);
        goodMap.set(i.inci_normalized, entry);
      }
    }
  }

  const high: Culprit[] = [];
  const medium: Culprit[] = [];

  for (const [normalized, bad] of badMap.entries()) {
    if (bad.productIds.size < 2) continue;
    const good = goodMap.get(normalized);
    const goodCount = good?.productIds.size ?? 0;
    const culprit: Culprit = {
      name: bad.rawName,
      normalized,
      badCount: bad.productIds.size,
      goodCount,
      badProducts: [...bad.productNames],
      goodProducts: good ? [...good.productNames] : [],
      risk: goodCount > 0 ? 'medium' : 'high',
    };
    if (culprit.risk === 'high') high.push(culprit);
    else medium.push(culprit);
  }

  const sort = (a: Culprit, b: Culprit) =>
    b.badCount - a.badCount || a.normalized.localeCompare(b.normalized);
  high.sort(sort);
  medium.sort(sort);

  return { high, medium };
}
