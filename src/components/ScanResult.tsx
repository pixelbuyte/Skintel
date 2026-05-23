import { useMemo } from 'react';
import { parseInci } from '@/lib/inci';
import {
  categorizeIngredients,
  generateVerdict,
  type Culprit,
} from '@/lib/ingredient-knowledge';
import { VerdictCard } from './VerdictCard';
import { Bucket, CollapsibleBucket } from './Bucket';

type CulpritInput = {
  name: string;
  normalized: string;
  badCount: number;
};

export function ScanResult({
  ingredients,
  high,
  medium,
}: {
  ingredients: string;
  high: CulpritInput[];
  medium: CulpritInput[];
}) {
  const buckets = useMemo(() => {
    const parsed = parseInci(ingredients);
    const map = new Map<string, Culprit>();
    for (const c of high) map.set(c.normalized, { name: c.name, risk: 'high', badCount: c.badCount });
    for (const c of medium) {
      if (!map.has(c.normalized))
        map.set(c.normalized, { name: c.name, risk: 'medium', badCount: c.badCount });
    }
    return categorizeIngredients(parsed, map);
  }, [ingredients, high, medium]);

  const verdict = useMemo(() => generateVerdict(buckets), [buckets]);

  return (
    <div className="space-y-5">
      <VerdictCard verdict={verdict} />
      <Bucket title="Watch out" tone="bad" rows={buckets.watchOut} />
      <Bucket title="Good for your skin" tone="good" rows={buckets.good} />
      <CollapsibleBucket title="Everything else" tone="muted" rows={buckets.rest} />
    </div>
  );
}
