import { useEffect, useMemo, useState } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, ChevronDown, Sparkles, Loader2 } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useSubscription } from '@/hooks/useSubscription';
import { useCulprits } from '@/hooks/useCulprits';
import { parseInci } from '@/lib/inci';
import type { Outcome } from '@/lib/types';
import { PaywallBanner } from '@/components/PaywallBanner';
import { ScanResult } from '@/components/ScanResult';
import { supabase } from '@/lib/supabase';

type PrefillState = {
  prefill?: {
    brand?: string | null;
    productName?: string | null;
    ingredients?: string;
    upc?: string | null;
  };
};

type Flag = {
  ingredient: string;
  level: 'high' | 'medium' | 'low';
  reason: string;
  source: 'personal' | 'general' | 'both';
};
type AiResult = {
  verdict: 'clean' | 'caution' | 'avoid';
  score?: number;
  summary: string;
  flags: Flag[];
  notes?: string;
};

export default function AddProduct() {
  const nav = useNavigate();
  const location = useLocation();
  const prefill = (location.state as PrefillState | null)?.prefill;

  const { addProduct, products } = useProducts();
  const { tier, productLimit } = useSubscription();
  const { high, medium } = useCulprits(products);
  const [brand, setBrand] = useState(prefill?.brand ?? '');
  const [productName, setProductName] = useState(prefill?.productName ?? '');
  const [category, setCategory] = useState('');
  const outcome: Outcome = 'unsure';
  const [notes, setNotes] = useState('');
  const [ingredientsRaw, setIngredientsRaw] = useState(prefill?.ingredients ?? '');
  const [showDetails, setShowDetails] = useState(!prefill);
  const [err, setErr] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // AI insight state — auto-fires when prefill arrives or user pastes ingredients
  const [ai, setAi] = useState<AiResult | null>(null);
  const [aiLoading, setAiLoading] = useState(false);
  const [aiErr, setAiErr] = useState<string | null>(null);

  const parsed = parseInci(ingredientsRaw);
  const atCap = tier === 'free' && products.length >= productLimit;

  const culpritMap = useMemo(() => {
    const m = new Map<string, { name: string; risk: 'high' | 'medium'; badCount: number }>();
    for (const c of high) m.set(c.normalized, { name: c.name, risk: 'high', badCount: c.badCount });
    for (const c of medium) m.set(c.normalized, { name: c.name, risk: 'medium', badCount: c.badCount });
    return m;
  }, [high, medium]);

  useEffect(() => {
    if (prefill && !productName && !brand) {
      setShowDetails(true);
    }
  }, [prefill, productName, brand]);

  // Auto-run AI insights when ingredients are present
  useEffect(() => {
    const inci = ingredientsRaw.trim();
    if (!inci || parsed.length < 3) return;

    let cancelled = false;
    setAi(null);
    setAiErr(null);
    setAiLoading(true);

    const localMatches: { name: string; risk: 'high' | 'medium'; badCount: number }[] = [];
    for (const i of parsed) {
      const hit = culpritMap.get(i.normalized);
      if (hit) localMatches.push(hit);
    }

    (async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (!session?.access_token) {
          if (!cancelled) {
            setAiErr('Sign in to see AI insights.');
            setAiLoading(false);
          }
          return;
        }
        const r = await fetch('/api/scan-ai', {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            authorization: `Bearer ${session.access_token}`,
          },
          body: JSON.stringify({ inci, matches: localMatches }),
        });
        if (!r.ok) {
          const e = await r.json().catch(() => ({}));
          throw new Error(e.error ?? `HTTP ${r.status}`);
        }
        const { result } = (await r.json()) as { result: AiResult };
        if (!cancelled) {
          setAi(result);
          setAiLoading(false);
        }
      } catch (e: any) {
        if (!cancelled) {
          setAiErr(String(e?.message ?? e));
          setAiLoading(false);
        }
      }
    })();

    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ingredientsRaw, culpritMap]);

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

  const hasInsight = parsed.length >= 3;

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
              Captured from {prefill.upc ? 'barcode' : 'scan'}. Insights below — tweak anything before saving.
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
        </div>

        {/* INSTANT LOCAL INSIGHT — Bucket view + Verdict, zero latency */}
        {hasInsight && (
          <ScanResult ingredients={ingredientsRaw} high={high} medium={medium} />
        )}

        {/* AI DEEP INSIGHT — async, auto-fires on prefill */}
        {hasInsight && (
          <div className="card p-5">
            <div className="flex items-center gap-2 mb-3 flex-wrap">
              <Sparkles size={18} className="text-primary" />
              <span className="font-display text-2xl">AI insight</span>
              {aiLoading && (
                <span className="inline-flex items-center gap-1.5 text-xs text-muted ml-2">
                  <Loader2 size={12} className="animate-spin" /> Opus 4.8 analyzing…
                </span>
              )}
              {ai && (
                <>
                  <span
                    className={`text-xs font-mono px-2.5 py-1 rounded-full border ${
                      ai.verdict === 'clean'
                        ? 'bg-good-bg text-good-fg border-good-fg/30'
                        : ai.verdict === 'caution'
                        ? 'bg-unsure-bg text-unsure-fg border-unsure-fg/30'
                        : 'bg-bad-bg text-bad-fg border-bad-fg/30'
                    }`}
                  >
                    {ai.verdict.toUpperCase()}
                  </span>
                  {typeof ai.score === 'number' && (
                    <span className="text-xs font-mono px-2.5 py-1 rounded-full bg-card border border-border">
                      {ai.score}/100
                    </span>
                  )}
                </>
              )}
            </div>

            {aiLoading && !ai && (
              <div className="space-y-2 animate-pulse">
                <div className="h-3 w-3/4 bg-border rounded" />
                <div className="h-3 w-2/3 bg-border rounded" />
                <div className="h-3 w-5/6 bg-border rounded" />
              </div>
            )}

            {aiErr && (
              <p className="text-sm text-bad-fg">{aiErr}</p>
            )}

            {ai && (
              <>
                <p className="text-sm leading-relaxed mb-3">{ai.summary}</p>
                {ai.flags.filter((f) => f.level !== 'low').length > 0 && (
                  <ul className="space-y-2 mb-3">
                    {ai.flags
                      .filter((f) => f.level !== 'low')
                      .map((f, i) => (
                        <li
                          key={i}
                          className="border-l-2 pl-3 py-1.5 rounded-r-md"
                          style={{
                            borderColor:
                              f.level === 'high' ? '#B22B2B' : f.level === 'medium' ? '#8B6914' : '#6B6760',
                          }}
                        >
                          <div className="flex items-center justify-between gap-2">
                            <span className="font-mono text-sm">{f.ingredient}</span>
                            <span className="text-[10px] uppercase tracking-wider text-muted font-mono">
                              {f.level} · {f.source}
                            </span>
                          </div>
                          <p className="text-xs text-muted mt-1">{f.reason}</p>
                        </li>
                      ))}
                  </ul>
                )}
                {ai.notes && (
                  <p className="text-xs text-muted italic mt-2 border-t border-border pt-3">
                    {ai.notes}
                  </p>
                )}
              </>
            )}
          </div>
        )}

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
