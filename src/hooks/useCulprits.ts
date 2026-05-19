import { useMemo } from 'react';
import { correlate } from '@/lib/correlate';
import type { ProductWithIngredients } from '@/lib/types';

export function useCulprits(products: ProductWithIngredients[]) {
  return useMemo(() => correlate(products), [products]);
}
