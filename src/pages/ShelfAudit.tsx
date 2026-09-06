import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, Plus, Sparkles, X } from 'lucide-react';
import { PublicPage } from '@/components/PublicPage';
import { parseInci } from '@/lib/inci';
import { isFragrance, lookupIngredient, POSITIVE_CATEGORIES } from '@/lib/ingredient-knowledge';

type Product = { id: number; name: string; ingredients: string };
type SharedRow = { normalized: string; display: string; count: number; productNames: string[] };

let nextId = 3;

function emptyProduct(id: number): Product {
  return { id, name: '', ingredients: '' };
}

/**
 * Ingredients that show up in 2+ pasted products. This is the free,
 * no-signup version of what the full app does with your breakout history:
 * instead of correlating against *your* reactions, it just shows overlap
 * across whatever you paste. Real computation, no fake demo data.
 */
function computeOverlap(products: Product[]): SharedRow[] {
  const byNorm = new Map<string, SharedRow>();

  for (const product of products) {
    const parsed = parseInci(product.ingredients);
    const label = product.name.trim() || 'Unnamed product';
    const seenInThisProduct = new Set<string>();

    for (const ing of parsed) {
      if (seenInThisProduct.has(ing.normalized)) continue;
      seenInThisProduct.add(ing.normalized);

      const existing = byNorm.get(ing.normalized);
      if (existing) {
        existing.count += 1;
        existing.productNames.push(label);
      } else {
        byNorm.set(ing.normalized, {
          normalized: ing.normalized,
          display: ing.raw,
          count: 1,
          productNames: [label],
        });
      }
    }
  }

  return Array.from(byNorm.values())
    .filter((row) => row.count >= 2)
    .sort((a, b) => b.count - a.count);
}

function IngredientBadge({ row, totalProducts }: { row: SharedRow; totalProducts: number }) {
  const info = lookupIngredient(row.display);
  const flaggedFragrance = isFragrance(row.display);
  const isPositive = info && POSITIVE_CATEGORIES.has(info.category);
  const inAll = row.count === totalProducts && totalProducts > 1;

  const tone = flaggedFragrance
    ? 'bad'
    : isPositive
      ? 'good'
      : 'neutral';

  const toneCls =
    tone === 'bad'
      ? 'border-bad-fg/25 bg-bad-bg/40'
      : tone === 'good'
        ? 'border-good-fg/25 bg-good-bg/40'
        : 'border-border bg-card/60';

  return (
    <div className={`rounded-xl border p-4 ${toneCls}`}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="font-medium">{row.display}</div>
          {info && <div className="text-sm text-muted mt-0.5">{info.benefit}</div>}
          {flaggedFragrance && (
            <div className="text-sm text-bad-fg mt-0.5">
              Common allergen category (fragrance) — worth watching if you're reactive.
            </div>
          )}
        </div>
        <div className="shrink-0 text-xs font-medium uppercase tracking-wide text-muted whitespace-nowrap">
          {inAll ? `in all ${row.count}` : `in ${row.count}`}
        </div>
      </div>
      <div className="text-xs text-muted mt-2 truncate">{row.productNames.join(' · ')}</div>
    </div>
  );
}

export default function ShelfAudit() {
  const [products, setProducts] = useState<Product[]>([emptyProduct(1), emptyProduct(2)]);
  const [analyzed, setAnalyzed] = useState(false);
  const [email, setEmail] = useState('');
  const [emailState, setEmailState] = useState<'idle' | 'submitting' | 'done' | 'error'>('idle');

  const filledCount = products.filter((p) => p.ingredients.trim().length > 0).length;
  const canAnalyze = filledCount >= 2;

  const shared = useMemo(() => (analyzed ? computeOverlap(products) : []), [analyzed, products]);
  const totalWithIngredients = products.filter((p) => p.ingredients.trim().length > 0).length;

  function updateProduct(id: number, patch: Partial<Product>) {
    setAnalyzed(false);
    setProducts((prev) => prev.map((p) => (p.id === id ? { ...p, ...patch } : p)));
  }

  function addProduct() {
    if (products.length >= 6) return;
    setAnalyzed(false);
    setProducts((prev) => [...prev, emptyProduct(nextId++)]);
  }

  function removeProduct(id: number) {
    if (products.length <= 2) return;
    setAnalyzed(false);
    setProducts((prev) => prev.filter((p) => p.id !== id));
  }

  async function submitEmail(e: React.FormEvent) {
    e.preventDefault();
    const clean = email.trim().toLowerCase();
    if (!clean) return;
    setEmailState('submitting');
    try {
      let ref: string | null = null;
      try {
        ref = localStorage.getItem('skintel_ref');
      } catch {
        /* storage unavailable */
      }
      const res = await fetch('/api/waitlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: clean,
          source: ref ? `shelf-audit:${ref}` : 'shelf-audit',
        }),
      });
      if (!res.ok) throw new Error('failed');
      setEmailState('done');
    } catch {
      setEmailState('error');
    }
  }

  return (
    <PublicPage
      eyebrow="Free tool — no signup required"
      title="What do your products have in common?"
    >
      <p>
        Paste the ingredient list from 2 or more products you actually use — Sephora, Ulta, the
        brand's site, or straight off the label. We'll show you every ingredient that shows up in
        more than one, so you can see what's actually layering on your skin every day.
      </p>

      <div className="not-prose mt-8 space-y-4">
        {products.map((product, i) => (
          <div key={product.id} className="rounded-xl border border-border bg-card/40 p-4">
            <div className="flex items-center gap-2 mb-2">
              <input
                value={product.name}
                onChange={(e) => updateProduct(product.id, { name: e.target.value })}
                placeholder={`Product ${i + 1} name (optional)`}
                className="flex-1 min-w-0 bg-transparent text-sm font-medium placeholder:text-muted/70 outline-none"
              />
              {products.length > 2 && (
                <button
                  type="button"
                  onClick={() => removeProduct(product.id)}
                  aria-label="Remove product"
                  className="text-muted hover:text-ink transition-colors duration-150 ease-emil shrink-0"
                >
                  <X size={16} />
                </button>
              )}
            </div>
            <textarea
              value={product.ingredients}
              onChange={(e) => updateProduct(product.id, { ingredients: e.target.value })}
              placeholder="Aqua, Glycerin, Niacinamide, Fragrance, Phenoxyethanol..."
              rows={3}
              className="w-full resize-none rounded-lg border border-border bg-bg/60 px-3 py-2 text-sm leading-relaxed outline-none focus:border-primary/40 transition-colors duration-150 ease-emil"
            />
          </div>
        ))}

        <div className="flex items-center gap-3 flex-wrap">
          {products.length < 6 && (
            <button
              type="button"
              onClick={addProduct}
              className="btn-secondary text-sm active:scale-[0.97] transition-transform duration-150 ease-emil"
            >
              <Plus size={14} /> Add another product
            </button>
          )}
          <button
            type="button"
            disabled={!canAnalyze}
            onClick={() => setAnalyzed(true)}
            className="btn-primary text-sm disabled:opacity-40 disabled:pointer-events-none active:scale-[0.97] transition-transform duration-150 ease-emil"
          >
            <Sparkles size={14} /> Find shared ingredients
          </button>
          {!canAnalyze && (
            <span className="text-xs text-muted">Paste at least 2 ingredient lists to compare.</span>
          )}
        </div>

        {analyzed && (
          <div className="pt-6 mt-2 border-t border-border">
            {shared.length === 0 ? (
              <div className="rounded-xl border border-border bg-card/40 p-6 text-center">
                <div className="font-display text-lg mb-1">No shared ingredients found</div>
                <p className="text-sm text-muted max-w-[48ch] mx-auto">
                  These products don't have anything obvious in common — which is genuinely useful
                  to know if you're trying to isolate what's causing a reaction.
                </p>
              </div>
            ) : (
              <>
                <div className="text-sm text-muted mb-3">
                  Found <span className="text-ink font-medium">{shared.length}</span> ingredient
                  {shared.length === 1 ? '' : 's'} shared across your {totalWithIngredients}{' '}
                  products.
                </div>
                <div className="grid sm:grid-cols-2 gap-3">
                  {shared.map((row) => (
                    <IngredientBadge key={row.normalized} row={row} totalProducts={totalWithIngredients} />
                  ))}
                </div>
              </>
            )}

            <div className="mt-8 rounded-xl border border-primary/20 bg-primary/5 p-5 sm:p-6">
              <div className="font-display text-lg mb-1">
                Want to know which one is actually breaking you out?
              </div>
              <p className="text-sm text-muted mb-4 max-w-[56ch]">
                This tool shows overlap. The full app cross-references these ingredients against
                your own logged breakouts, so it can tell you which shared ingredient is the real
                culprit — not just which ones are common.
              </p>
              {emailState === 'done' ? (
                <div className="text-sm text-good-fg font-medium">
                  You're on the list — check your inbox.
                </div>
              ) : (
                <form onSubmit={submitEmail} className="flex flex-col sm:flex-row gap-2 max-w-md">
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@email.com"
                    className="flex-1 min-w-0 rounded-lg border border-border bg-bg px-3 py-2 text-sm outline-none focus:border-primary/40 transition-colors duration-150 ease-emil"
                  />
                  <button
                    type="submit"
                    disabled={emailState === 'submitting'}
                    className="btn-primary text-sm shrink-0 disabled:opacity-60 active:scale-[0.97] transition-transform duration-150 ease-emil"
                  >
                    {emailState === 'submitting' ? 'Sending…' : 'Find my culprit'} <ArrowRight size={14} />
                  </button>
                </form>
              )}
              {emailState === 'error' && (
                <div className="text-sm text-bad-fg mt-2">Something went wrong — try again?</div>
              )}
              <div className="mt-3 text-xs text-muted">
                Or skip the email and{' '}
                <Link to="/login" className="underline hover:text-ink transition-colors duration-150 ease-emil">
                  start free right now
                </Link>
                .
              </div>
            </div>
          </div>
        )}
      </div>
    </PublicPage>
  );
}
