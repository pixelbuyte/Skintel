import { useCallback, useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import type { Outcome, ProductWithIngredients } from '@/lib/types';
import { useAuth } from './useAuth';

export function useProducts() {
  const { user } = useAuth();
  const [products, setProducts] = useState<ProductWithIngredients[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchProducts = useCallback(async () => {
    if (!user) {
      setProducts([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    const { data, error } = await supabase
      .from('products')
      .select('*, product_ingredients(*)')
      .order('created_at', { ascending: false });
    if (error) setError(error.message);
    setProducts((data as ProductWithIngredients[]) ?? []);
    setLoading(false);
  }, [user]);

  useEffect(() => {
    fetchProducts();
  }, [fetchProducts]);

  const addProduct = useCallback(
    async (input: {
      brand: string | null;
      product_name: string;
      category: string | null;
      outcome: Outcome;
      notes: string | null;
      ingredients: { raw: string; normalized: string; position: number }[];
    }) => {
      if (!user) throw new Error('Not authenticated');
      const { data: product, error: pErr } = await supabase
        .from('products')
        .insert({
          user_id: user.id,
          brand: input.brand,
          product_name: input.product_name,
          category: input.category,
          outcome: input.outcome,
          notes: input.notes,
        })
        .select()
        .single();
      if (pErr) throw pErr;

      if (input.ingredients.length > 0) {
        const rows = input.ingredients.map((i) => ({
          product_id: product.id,
          user_id: user.id,
          position: i.position,
          inci_raw: i.raw,
          inci_normalized: i.normalized,
        }));
        const { error: iErr } = await supabase.from('product_ingredients').insert(rows);
        if (iErr) {
          await supabase.from('products').delete().eq('id', product.id);
          throw iErr;
        }
      }
      await fetchProducts();
      return product.id as string;
    },
    [user, fetchProducts],
  );

  const updateProduct = useCallback(
    async (
      id: string,
      patch: Partial<{
        brand: string | null;
        product_name: string;
        category: string | null;
        outcome: Outcome;
        notes: string | null;
      }>,
      ingredients?: { raw: string; normalized: string; position: number }[],
    ) => {
      if (!user) throw new Error('Not authenticated');
      const { error: uErr } = await supabase.from('products').update(patch).eq('id', id);
      if (uErr) throw uErr;
      if (ingredients) {
        await supabase.from('product_ingredients').delete().eq('product_id', id);
        if (ingredients.length > 0) {
          const rows = ingredients.map((i) => ({
            product_id: id,
            user_id: user.id,
            position: i.position,
            inci_raw: i.raw,
            inci_normalized: i.normalized,
          }));
          const { error: iErr } = await supabase.from('product_ingredients').insert(rows);
          if (iErr) throw iErr;
        }
      }
      await fetchProducts();
    },
    [user, fetchProducts],
  );

  const deleteProduct = useCallback(
    async (id: string) => {
      const { error } = await supabase.from('products').delete().eq('id', id);
      if (error) throw error;
      await fetchProducts();
    },
    [fetchProducts],
  );

  return { products, loading, error, addProduct, updateProduct, deleteProduct, refresh: fetchProducts };
}
