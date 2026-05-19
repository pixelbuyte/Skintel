import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useProducts } from '@/hooks/useProducts';
import { useSubscription } from '@/hooks/useSubscription';
import { parseInci } from '@/lib/inci';
import type { Outcome } from '@/lib/types';
import { PaywallBanner } from '@/components/PaywallBanner';

export default function AddProduct() {
  const nav = useNavigate();
  const { addProduct, products } = useProducts();
  const { tier, productLimit } = useSubscription();
  const [brand, setBrand] = useState('');
  const [productName, setProductName] = useState('');
  const [category, setCategory] = useState('');
  const [outcome, setOutcome] = useState<Outcome>('unsure');
  const [notes, setNotes] = useState('');
  const [ingredientsRaw, setIngredientsRaw] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const parsed = parseInci(ingredientsRaw);
  const atCap = tier === 'free' && products.length >= productLimit;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (atCap) {
      setErr('Free plan limit reached — upgrade to add more products.');
      return;
    }
    setSubmitting(true);
    try {
      await addProduct({
        brand: brand.trim() || null,
        product_name: productName.trim(),
        category: category.trim() || null,
        outcome,
        notes: notes.trim() || null,
        ingredients: parsed,
      });
      nav('/app/products');
    } catch (e: any) {
      if (e?.message?.includes('FREE_PLAN_LIMIT')) {
        setErr('Free plan limit reached — upgrade to add more products.');
      } else {
        setErr(e?.message ?? 'Failed to save product');
      }
    } finally {
      setSubmitting(false);
    }
  }

  if (atCap) {
    return (
      <div>
        <Link to="/app/products" className="inline-flex items-center gap-1 text-sm text-muted mb-4">
          <ArrowLeft size={16} /> Back to products
        </Link>
        <PaywallBanner reason="product-cap" />
      </div>
    );
  }

  return (
    <div className="max-w-3xl">
      <Link to="/app/products" className="inline-flex items-center gap-1 text-sm text-muted mb-4">
        <ArrowLeft size={16} /> Back to products
      </Link>
      <h1 className="font-display text-4xl mb-6">Add a product</h1>

      <form onSubmit={submit} className="flex flex-col gap-5">
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <label className="label">Brand</label>
            <input className="input" value={brand} onChange={(e) => setBrand(e.target.value)} placeholder="CeraVe" />
          </div>
          <div>
            <label className="label">Product name *</label>
            <input
              className="input"
              required
              value={productName}
              onChange={(e) => setProductName(e.target.value)}
              placeholder="Foaming Cleanser"
            />
          </div>
        </div>

        <div>
          <label className="label">Category</label>
          <input
            className="input"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            placeholder="Cleanser / Moisturizer / Sunscreen…"
          />
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
            placeholder="Anything to remember about this product…"
          />
        </div>

        <div>
          <label className="label">
            INCI ingredient list <span className="text-muted font-normal">({parsed.length} parsed)</span>
          </label>
          <textarea
            className="input min-h-40 font-mono text-xs"
            value={ingredientsRaw}
            onChange={(e) => setIngredientsRaw(e.target.value)}
            placeholder="Water, Glycerin, Niacinamide, Cetyl Alcohol, …"
          />
          {parsed.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-1.5">
              {parsed.slice(0, 12).map((i) => (
                <span key={i.normalized} className="text-xs font-mono bg-bg px-2 py-0.5 rounded">{i.raw}</span>
              ))}
              {parsed.length > 12 && (
                <span className="text-xs text-muted">+{parsed.length - 12} more</span>
              )}
            </div>
          )}
        </div>

        {err && <div className="text-sm text-bad-fg">{err}</div>}

        <div className="flex gap-2">
          <button className="btn-primary" disabled={submitting}>
            {submitting ? 'Saving…' : 'Save product'}
          </button>
          <Link to="/app/products" className="btn-secondary">Cancel</Link>
        </div>
      </form>
    </div>
  );
}
