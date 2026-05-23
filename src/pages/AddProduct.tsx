import { useEffect, useState } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, ChevronDown } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useSubscription } from '@/hooks/useSubscription';
import { parseInci } from '@/lib/inci';
import type { Outcome } from '@/lib/types';
import { PaywallBanner } from '@/components/PaywallBanner';

type PrefillState = {
  prefill?: {
    brand?: string | null;
    productName?: string | null;
    ingredients?: string;
    upc?: string | null;
  };
};

export default function AddProduct() {
  const nav = useNavigate();
  const location = useLocation();
  const prefill = (location.state as PrefillState | null)?.prefill;

  const { addProduct, products } = useProducts();
  const { tier, productLimit } = useSubscription();
  const [brand, setBrand] = useState(prefill?.brand ?? '');
  const [productName, setProductName] = useState(prefill?.productName ?? '');
  const [category, setCategory] = useState('');
  const [outcome, setOutcome] = useState<Outcome>('unsure');
  const [notes, setNotes] = useState('');
  const [ingredientsRaw, setIngredientsRaw] = useState(prefill?.ingredients ?? '');
  const [showDetails, setShowDetails] = useState(!prefill);
  const [err, setErr] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const parsed = parseInci(ingredientsRaw);
  const atCap = tier === 'free' && products.length >= productLimit;

  useEffect(() => {
    if (prefill && !productName && !brand) {
      // Empty prefill — open details so user can fill manually.
      setShowDetails(true);
    }
  }, [prefill, productName, brand]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (atCap) {
      setErr('Free plan limit reached. Upgrade to add more products.');
      return;
    }
    if (!productName.trim()) {
      setErr('Product name is required.');
      setShowDetails(true);
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
        setErr('Free plan limit reached. Upgrade to add more products.');
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

      <form onSubmit={submit} className="flex flex-col gap-6">
        <div>
          <h1 className="font-display text-4xl mb-2">
            {prefill ? 'Review & confirm' : 'Add a product'}
          </h1>
          {prefill && (
            <p className="text-sm text-muted">
              Captured from {prefill.upc ? 'barcode' : 'scan'}. Tweak anything before saving.
            </p>
          )}
        </div>

        <div className="card p-5 space-y-4">
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
            <label className="label">How did it work for you?</label>
            <div className="flex gap-2 flex-wrap">
              {(['good', 'unsure', 'bad'] as Outcome[]).map((o) => (
                <button
                  type="button"
                  key={o}
                  onClick={() => setOutcome(o)}
                  className={`px-4 py-2 rounded-2xl text-sm font-medium border min-h-11 ${
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

          {parsed.length > 0 && (
            <div className="text-xs text-muted">
              {parsed.length} ingredients parsed
            </div>
          )}
        </div>

        <button
          type="button"
          onClick={() => setShowDetails((v) => !v)}
          className="self-start inline-flex items-center gap-1 text-sm text-muted hover:text-ink min-h-11"
        >
          <ChevronDown size={16} className={`transition-transform ${showDetails ? 'rotate-180' : ''}`} />
          {showDetails ? 'Hide details' : 'Edit details'}
        </button>

        {showDetails && (
          <div className="card p-5 space-y-5">
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
          </div>
        )}

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
