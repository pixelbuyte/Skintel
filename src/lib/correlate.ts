import type { Trigger, ProductWithIngredients } from './types';

export function correlate(products: ProductWithIngredients[]): {
  high: Trigger[];
  medium: Trigger[];
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

  const high: Trigger[] = [];
  const medium: Trigger[] = [];

  for (const [normalized, bad] of badMap.entries()) {
    if (bad.productIds.size < 2) continue;
    const good = goodMap.get(normalized);
    const goodCount = good?.productIds.size ?? 0;
    const trigger: Trigger = {
      name: bad.rawName,
      normalized,
      badCount: bad.productIds.size,
      goodCount,
      badProducts: [...bad.productNames],
      goodProducts: good ? [...good.productNames] : [],
      risk: goodCount > 0 ? 'medium' : 'high',
    };
    if (trigger.risk === 'high') high.push(trigger);
    else medium.push(trigger);
  }

  const sort = (a: Trigger, b: Trigger) =>
    b.badCount - a.badCount || a.normalized.localeCompare(b.normalized);
  high.sort(sort);
  medium.sort(sort);

  return { high, medium };
}
