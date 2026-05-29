import { useMemo, useState } from 'react';
import { GitCompare, Loader2, Plus, Trophy, X, Sparkles, AlertTriangle, Check } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useSubscription } from '@/hooks/useSubscription';
import { PaywallBanner } from '@/components/PaywallBanner';
import { supabase } from '@/lib/supabase';
import { isPreview } from '@/lib/preview';

type Verdict = 'clean' | 'caution' | 'avoid';

type CompareItem = {
  name: string;
  verdict: Verdict;
  score: number;
  short: string;
  keyConcerns: string[];
  keyWins: string[];
};

type CompareResponse = {
  items: CompareItem[];
  winner: { index: number; reason: string };
  usage: { model: string };
};

type Slot = { name: string; inci: string };

const EMPTY_SLOT: Slot = { name: '', inci: '' };

const VERDICT_TONE: Record<
  Verdict,
  { label: string; color: string; bg: string; border: string; ring: string }
> = {
  clean: {
    label: 'Good',
    color: '#5C7A4F',
    bg: 'rgba(92,122,79,0.10)',
    border: 'rgba(92,122,79,0.25)',
    ring: '#5C7A4F',
  },
  caution: {
    label: 'Caution',
    color: '#8B6914',
    bg: 'rgba(139,105,20,0.10)',
    border: 'rgba(139,105,20,0.25)',
    ring: '#8B6914',
  },
  avoid: {
    label: 'Skip',
    color: '#B22B2B',
    bg: 'rgba(178,43,43,0.10)',
    border: 'rgba(178,43,43,0.25)',
    ring: '#B22B2B',
  },
};

const MOCK_RESPONSE: CompareResponse = {
  items: [
    {
      name: 'CeraVe Moisturizer',
      verdict: 'clean',
      score: 86,
      short: 'Ceramide-led barrier formula with niacinamide and no fragrance.',
      keyConcerns: [],
      keyWins: ['Ceramide NP', 'Niacinamide', 'Hyaluronic Acid'],
    },
    {
      name: 'Fragrance-heavy lotion',
      verdict: 'avoid',
      score: 28,
      short: 'Stacked fragrance allergens (linalool, limonene) plus methylisothiazolinone.',
      keyConcerns: ['Fragrance', 'Linalool', 'Methylisothiazolinone'],
      keyWins: ['Glycerin'],
    },
  ],
  winner: {
    index: 0,
    reason: 'Same hydration story without the fragrance allergens flagged in your triggers.',
  },
  usage: { model: 'preview' },
};

export default function Compare() {
  const { products } = useProducts();
  const { canUseScanner } = useSubscription();
  const preview = isPreview();

  const [slots, setSlots] = useState<Slot[]>([{ ...EMPTY_SLOT }, { ...EMPTY_SLOT }]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<CompareResponse | null>(null);

  const savedOptions = useMemo(() => {
    return products.map((p) => {
      const label = [p.brand, p.product_name].filter(Boolean).join(' ') || p.product_name;
      const inci = (p.product_ingredients ?? [])
        .slice()
        .sort((a, b) => a.position - b.position)
        .map((i) => i.inci_raw)
        .join(', ');
      return { id: p.id, label, inci, name: p.product_name };
    });
  }, [products]);

  function updateSlot(idx: number, patch: Partial<Slot>) {
    setSlots((prev) => prev.map((s, i) => (i === idx ? { ...s, ...patch } : s)));
  }

  function addSlot() {
    if (slots.length >= 3) return;
    setSlots((prev) => [...prev, { ...EMPTY_SLOT }]);
  }

  function removeSlot(idx: number) {
    if (slots.length <= 2) return;
    setSlots((prev) => prev.filter((_, i) => i !== idx));
  }

  function pickSaved(idx: number, optionId: string) {
    if (!optionId) return;
    const opt = savedOptions.find((o) => o.id === optionId);
    if (!opt) return;
    updateSlot(idx, { name: opt.label, inci: opt.inci });
  }

  const ready = slots.every((s) => s.name.trim() && s.inci.trim()) && slots.length >= 2;

  async function runCompare() {
    if (!ready) return;
    setLoading(true);
    setError(null);
    setResult(null);

    if (preview) {
      setTimeout(() => {
        setResult(MOCK_RESPONSE);
        setLoading(false);
      }, 700);
      return;
    }

    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session?.access_token) {
        setError('Sign in to run comparisons.');
        setLoading(false);
        return;
      }
      const r = await fetch('/api/lookup?mode=compare', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          products: slots.map((s) => ({ name: s.name.trim(), inci: s.inci.trim() })),
        }),
      });
      if (!r.ok) {
        const e = await r.json().catch(() => ({}));
        throw new Error(e.error ?? `HTTP ${r.status}`);
      }
      const data = (await r.json()) as CompareResponse;
      setResult(data);
    } catch (e: any) {
      setError(String(e?.message ?? e));
    } finally {
      setLoading(false);
    }
  }

  if (!canUseScanner) {
    return (
      <div className="max-w-3xl">
        <h1 className="font-display text-5xl mb-6">Compare</h1>
        <PaywallBanner reason="scanner" />
      </div>
    );
  }

  const gridCols =
    result && result.items.length === 3
      ? 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3'
      : 'grid-cols-1 md:grid-cols-2';

  return (
    <div className="max-w-5xl">
      <header className="mb-6 relative">
        <div className="absolute -inset-x-4 -top-4 h-28 bg-gradient-to-br from-amber-50/40 via-cream to-rose-50/30 blur-3xl -z-10" />
        <div className="flex items-baseline gap-3 flex-wrap">
          <h1 className="font-display text-5xl tracking-tight">Compare</h1>
          <span className="font-display italic text-3xl text-muted/70">side by side</span>
        </div>
        <p className="text-muted text-sm mt-2 max-w-xl">
          Pick 2 or 3 products. Skintel checks each ingredient list against your personal triggers
          and picks the best fit for your skin.
        </p>
      </header>

      <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3 mb-4">
        {slots.map((slot, idx) => (
          <div key={idx} className="card p-4 flex flex-col gap-3 relative">
            <div className="flex items-center gap-2">
              <span className="text-[11px] uppercase tracking-[0.18em] text-muted">
                Product {idx + 1}
              </span>
              {slots.length > 2 && (
                <button
                  type="button"
                  onClick={() => removeSlot(idx)}
                  className="ml-auto text-muted hover:text-bad-fg transition-colors"
                  aria-label="Remove product"
                >
                  <X size={14} />
                </button>
              )}
            </div>

            <input
              className="input"
              placeholder="Product name"
              value={slot.name}
              onChange={(e) => updateSlot(idx, { name: e.target.value })}
            />

            {savedOptions.length > 0 && (
              <select
                className="input text-sm"
                value=""
                onChange={(e) => {
                  pickSaved(idx, e.target.value);
                  e.target.value = '';
                }}
              >
                <option value="">Pick saved product…</option>
                {savedOptions.map((o) => (
                  <option key={o.id} value={o.id}>
                    {o.label}
                  </option>
                ))}
              </select>
            )}

            <textarea
              className="input min-h-32 font-mono text-xs"
              placeholder="Water, Glycerin, Niacinamide, Ceramide NP, …"
              value={slot.inci}
              onChange={(e) => updateSlot(idx, { inci: e.target.value })}
            />
          </div>
        ))}

        {slots.length < 3 && (
          <button
            type="button"
            onClick={addSlot}
            className="card p-4 min-h-40 flex items-center justify-center text-muted hover:text-ink hover:border-ink/30 transition-colors text-sm"
          >
            <Plus size={16} className="mr-1.5" /> Add another
          </button>
        )}
      </div>

      <div className="flex items-center gap-2 flex-wrap mb-6">
        <button className="btn-primary" onClick={runCompare} disabled={!ready || loading}>
          {loading ? <Loader2 size={16} className="animate-spin" /> : <GitCompare size={16} />}
          {loading ? 'Comparing…' : 'Compare'}
        </button>
        {preview && (
          <span className="text-[11px] uppercase tracking-wider text-muted">
            preview · mock result
          </span>
        )}
        {error && <p className="text-sm text-bad-fg w-full">Compare failed: {error}</p>}
      </div>

      {loading && (
        <div className={`grid gap-3 ${gridCols}`}>
          {slots.map((_, i) => (
            <div key={i} className="card p-5 animate-pulse">
              <div className="h-3 w-20 bg-bg/60 rounded mb-3" />
              <div className="h-8 w-24 bg-bg/60 rounded mb-2" />
              <div className="h-3 w-full bg-bg/60 rounded mb-2" />
              <div className="h-3 w-2/3 bg-bg/60 rounded mb-4" />
              <div className="h-3 w-1/2 bg-bg/60 rounded mb-2" />
              <div className="h-3 w-3/4 bg-bg/60 rounded" />
            </div>
          ))}
        </div>
      )}

      {result && !loading && (
        <>
          <div className={`grid gap-3 ${gridCols} mb-5`}>
            {result.items.map((item, idx) => {
              const tone = VERDICT_TONE[item.verdict];
              const isWinner = idx === result.winner.index;
              return (
                <article
                  key={idx}
                  className="card p-5 flex flex-col gap-3 relative"
                  style={{
                    borderColor: isWinner ? '#A35848' : undefined,
                    boxShadow: isWinner ? '0 0 0 1px rgba(163,88,72,0.35)' : undefined,
                  }}
                >
                  {isWinner && (
                    <span
                      className="absolute -top-2 left-4 inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-mono uppercase tracking-wider"
                      style={{ background: '#A35848', color: '#FFFEFA' }}
                    >
                      <Trophy size={10} /> Winner
                    </span>
                  )}

                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="text-[11px] uppercase tracking-[0.18em] text-muted">
                        Product {idx + 1}
                      </div>
                      <div className="font-display text-xl truncate">{item.name}</div>
                    </div>
                    <ScoreRing score={item.score} color={tone.ring} />
                  </div>

                  <div
                    className="inline-flex self-start items-center gap-1.5 px-2.5 py-1 rounded-full border text-xs font-mono"
                    style={{
                      background: tone.bg,
                      borderColor: tone.border,
                      color: tone.color,
                    }}
                  >
                    {item.verdict === 'clean' ? (
                      <Check size={12} />
                    ) : item.verdict === 'caution' ? (
                      <AlertTriangle size={12} />
                    ) : (
                      <X size={12} />
                    )}
                    {tone.label.toUpperCase()}
                  </div>

                  <p className="text-sm leading-relaxed">{item.short}</p>

                  {item.keyConcerns.length > 0 && (
                    <div>
                      <div className="text-[10px] uppercase tracking-wider text-muted mb-1.5">
                        Concerns
                      </div>
                      <div className="flex flex-wrap gap-1.5">
                        {item.keyConcerns.map((c, i) => (
                          <span
                            key={i}
                            className="text-[11px] font-mono px-2 py-0.5 rounded-full bg-bad-bg text-bad-fg border border-bad-fg/20"
                          >
                            {c}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}

                  {item.keyWins.length > 0 && (
                    <div>
                      <div className="text-[10px] uppercase tracking-wider text-muted mb-1.5">
                        Wins
                      </div>
                      <div className="flex flex-wrap gap-1.5">
                        {item.keyWins.map((w, i) => (
                          <span
                            key={i}
                            className="text-[11px] font-mono px-2 py-0.5 rounded-full bg-good-bg text-good-fg border border-good-fg/20"
                          >
                            {w}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}
                </article>
              );
            })}
          </div>

          <div
            className="card p-5 flex items-start gap-3"
            style={{
              background: 'linear-gradient(135deg, rgba(163,88,72,0.10), #FFFEFA 60%)',
              borderColor: 'rgba(163,88,72,0.30)',
            }}
          >
            <div
              className="size-10 rounded-xl flex items-center justify-center shrink-0"
              style={{ background: '#A35848', color: '#FFFEFA' }}
            >
              <Trophy size={18} />
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="text-[11px] uppercase tracking-[0.18em] text-muted">
                  Best for you
                </span>
                <Sparkles size={12} className="text-primary" />
              </div>
              <div className="font-display text-2xl mt-0.5 truncate">
                {result.items[result.winner.index]?.name ?? 'Winner'}
              </div>
              <p className="text-sm text-muted mt-1 leading-relaxed">{result.winner.reason}</p>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function ScoreRing({ score, color }: { score: number; color: string }) {
  const clamped = Math.max(0, Math.min(100, score));
  const r = 22;
  const c = 2 * Math.PI * r;
  const dash = (clamped / 100) * c;
  return (
    <div className="relative size-14 shrink-0">
      <svg width="56" height="56" viewBox="0 0 56 56" className="-rotate-90">
        <circle cx="28" cy="28" r={r} fill="none" stroke="rgba(0,0,0,0.06)" strokeWidth="4" />
        <circle
          cx="28"
          cy="28"
          r={r}
          fill="none"
          stroke={color}
          strokeWidth="4"
          strokeLinecap="round"
          strokeDasharray={`${dash} ${c}`}
        />
      </svg>
      <div
        className="absolute inset-0 flex items-center justify-center font-mono text-sm font-medium"
        style={{ color }}
      >
        {clamped}
      </div>
    </div>
  );
}
