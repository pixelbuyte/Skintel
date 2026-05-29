import { useEffect, useMemo, useState } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, ChevronDown, Sparkles, Loader2, Sun, Moon } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useSubscription } from '@/hooks/useSubscription';
import { useCulprits } from '@/hooks/useCulprits';
import { parseInci } from '@/lib/inci';
import type { Outcome } from '@/lib/types';
import { PaywallBanner } from '@/components/PaywallBanner';
import { ScanResult } from '@/components/ScanResult';
import { supabase } from '@/lib/supabase';

const ROUTINE_KEY = 'skintel:routine:v1';

const VERDICT_LABEL: Record<'clean' | 'caution' | 'avoid', { short: string; tag: string }> = {
  clean:   { short: 'Good',    tag: 'safe to use daily' },
  caution: { short: 'Caution', tag: 'use with care — has risks' },
  avoid:   { short: 'Skip',    tag: 'do not use — high risk for your skin' },
};

function addProductToRoutine(productId: string, slot: 'am' | 'pm') {
  try {
    const raw = localStorage.getItem(ROUTINE_KEY);
    const obj = raw ? (JSON.parse(raw) as { am?: string[]; pm?: string[]; name?: string; savedAt?: number }) : {};
    const am = Array.isArray(obj.am) ? obj.am : [];
    const pm = Array.isArray(obj.pm) ? obj.pm : [];
    if (slot === 'am' && !am.includes(productId)) am.push(productId);
    if (slot === 'pm' && !pm.includes(productId)) pm.push(productId);
    localStorage.setItem(
      ROUTINE_KEY,
      JSON.stringify({ am, pm, name: obj.name ?? 'My routine', savedAt: Date.now() }),
    );
  } catch {}
}

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

  async function doSave(routineSlot?: 'am' | 'pm') {
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
      const savedId = await addProduct({
        brand: brand.trim() || null,
        product_name: productName.trim(),
        category: category.trim() || null,
        outcome,
        notes: notes.trim() || null,
        ingredients: parsed,
      });
      if (routineSlot && savedId) {
        addProductToRoutine(savedId, routineSlot);
        nav('/app/routine');
      } else {
        nav('/app/products');
      }
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

  function submit(e: React.FormEvent) {
    e.preventDefault();
    void doSave();
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
                  <Loader2 size={12} className="animate-spin" /> Analyzing…
                </span>
              )}
            </div>

            {/* Hero verdict band — short label + score, prominent */}
            {ai && (
              <div
                className={`mb-4 rounded-xl px-4 py-3 flex items-center gap-3 border ${
                  ai.verdict === 'clean'
                    ? 'bg-good-bg border-good-fg/25'
                    : ai.verdict === 'caution'
                    ? 'bg-unsure-bg border-unsure-fg/25'
                    : 'bg-bad-bg border-bad-fg/25'
                }`}
              >
                <div
                  className={`font-display text-3xl leading-none ${
                    ai.verdict === 'clean'
                      ? 'text-good-fg'
                      : ai.verdict === 'caution'
                      ? 'text-unsure-fg'
                      : 'text-bad-fg'
                  }`}
                >
                  {VERDICT_LABEL[ai.verdict].short}
                </div>
                <div className="flex-1 min-w-0">
                  <div
                    className={`text-xs uppercase tracking-[0.18em] font-bold ${
                      ai.verdict === 'clean'
                        ? 'text-good-fg'
                        : ai.verdict === 'caution'
                        ? 'text-unsure-fg'
                        : 'text-bad-fg'
                    }`}
                  >
                    {VERDICT_LABEL[ai.verdict].tag}
                  </div>
                </div>
                {typeof ai.score === 'number' && (
                  <div
                    className={`text-right shrink-0 ${
                      ai.verdict === 'clean'
                        ? 'text-good-fg'
                        : ai.verdict === 'caution'
                        ? 'text-unsure-fg'
                        : 'text-bad-fg'
                    }`}
                  >
                    <div className="font-display text-3xl leading-none tabular-nums">{ai.score}</div>
                    <div className="text-[10px] uppercase tracking-wider opacity-75">score</div>
                  </div>
                )}
              </div>
            )}

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

        <div className="space-y-2">
          <div className="flex gap-2 flex-wrap">
            <button className="btn-primary" disabled={submitting}>
              {submitting ? 'Saving…' : 'Save product'}
            </button>
            <Link to="/app/products" className="btn-secondary">Cancel</Link>
          </div>
          <div className="flex gap-2 flex-wrap">
            <button
              type="button"
              disabled={submitting}
              onClick={() => doSave('am')}
              className="btn-secondary inline-flex items-center gap-1.5 disabled:opacity-60"
            >
              <Sun size={14} /> Save + add to AM routine
            </button>
            <button
              type="button"
              disabled={submitting}
              onClick={() => doSave('pm')}
              className="btn-secondary inline-flex items-center gap-1.5 disabled:opacity-60"
            >
              <Moon size={14} /> Save + add to PM routine
            </button>
          </div>
        </div>
      </form>
    </div>
  );
}
