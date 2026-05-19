import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Trash2 } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useProducts } from '@/hooks/useProducts';
import { parseInci } from '@/lib/inci';
import type { Outcome, ProductWithIngredients } from '@/lib/types';
import { ConfirmDialog } from '@/components/ConfirmDialog';

export default function EditProduct() {
  const { id } = useParams();
  const nav = useNavigate();
  const { updateProduct, deleteProduct } = useProducts();
  const [product, setProduct] = useState<ProductWithIngredients | null>(null);
  const [brand, setBrand] = useState('');
  const [productName, setProductName] = useState('');
  const [category, setCategory] = useState('');
  const [outcome, setOutcome] = useState<Outcome>('unsure');
  const [notes, setNotes] = useState('');
  const [ingredientsRaw, setIngredientsRaw] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);

  useEffect(() => {
    if (!id) return;
    supabase
      .from('products')
      .select('*, product_ingredients(*)')
      .eq('id', id)
      .single()
      .then(({ data }) => {
        if (!data) return;
        const p = data as ProductWithIngredients;
        setProduct(p);
        setBrand(p.brand ?? '');
        setProductName(p.product_name);
        setCategory(p.category ?? '');
        setOutcome(p.outcome);
        setNotes(p.notes ?? '');
        setIngredientsRaw(
          (p.product_ingredients ?? [])
            .sort((a, b) => a.position - b.position)
            .map((i) => i.inci_raw)
            .join(', '),
        );
      });
  }, [id]);

  if (!product) {
    return <div className="text-muted">Loading…</div>;
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!id) return;
    setErr(null);
    setSubmitting(true);
    try {
      await updateProduct(
        id,
        {
          brand: brand.trim() || null,
          product_name: productName.trim(),
          category: category.trim() || null,
          outcome,
          notes: notes.trim() || null,
        },
        parseInci(ingredientsRaw),
      );
      nav('/app/products');
    } catch (e: any) {
      setErr(e?.message ?? 'Failed to update');
    } finally {
      setSubmitting(false);
    }
  }

  async function doDelete() {
    if (!id) return;
    await deleteProduct(id);
    nav('/app/products');
  }

  return (
    <div className="max-w-3xl">
      <Link to="/app/products" className="inline-flex items-center gap-1 text-sm text-muted mb-4">
        <ArrowLeft size={16} /> Back to products
      </Link>
      <div className="flex items-start justify-between mb-6">
        <h1 className="font-display text-4xl">Edit product</h1>
        <button className="btn-ghost text-bad-fg" onClick={() => setConfirmDelete(true)}>
          <Trash2 size={16} /> Delete
        </button>
      </div>

      <form onSubmit={submit} className="flex flex-col gap-5">
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <label className="label">Brand</label>
            <input className="input" value={brand} onChange={(e) => setBrand(e.target.value)} />
          </div>
          <div>
            <label className="label">Product name *</label>
            <input
              className="input"
              required
              value={productName}
              onChange={(e) => setProductName(e.target.value)}
            />
          </div>
        </div>

        <div>
          <label className="label">Category</label>
          <input className="input" value={category} onChange={(e) => setCategory(e.target.value)} />
        </div>

        <div>
          <label className="label">How did it work for you?</label>
          <div className="flex gap-2 flex-wrap">
            {(['good', 'unsure', 'bad'] as Outcome[]).map((o) => (
              <button
                type="button"
                key={o}
                onClick={() => setOutcome(o)}
                className={`px-4 py-2 rounded-lg text-sm font-medium border ${
                  outcome === o
                    ? o === 'good'
                      ? 'bg-good-bg text-good-fg border-good-fg/30'
                      : o === 'bad'
                      ? 'bg-bad-bg text-bad-fg border-bad-fg/30'
                      : 'bg-unsure-bg text-unsure-fg border-unsure-fg/30'
                    : 'bg-card text-ink border-border'
                }`}
              >
                {o === 'good' ? '✓ Worked great' : o === 'bad' ? '✗ Broke me out' : '? Unsure'}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="label">Notes</label>
          <textarea
            className="input min-h-20"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
          />
        </div>

        <div>
          <label className="label">INCI ingredient list</label>
          <textarea
            className="input min-h-40 font-mono text-xs"
            value={ingredientsRaw}
            onChange={(e) => setIngredientsRaw(e.target.value)}
          />
        </div>

        {err && <div className="text-sm text-bad-fg">{err}</div>}

        <div className="flex gap-2">
          <button className="btn-primary" disabled={submitting}>
            {submitting ? 'Saving…' : 'Save changes'}
          </button>
          <Link to="/app/products" className="btn-secondary">Cancel</Link>
        </div>
      </form>

      <ConfirmDialog
        open={confirmDelete}
        title="Delete this product?"
        body="This removes the product and all its tracked ingredients. The correlation engine will re-run."
        confirmLabel="Delete"
        danger
        onConfirm={doDelete}
        onCancel={() => setConfirmDelete(false)}
      />
    </div>
  );
}
