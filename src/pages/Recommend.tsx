import { useState } from 'react';
import {
  Sparkles,
  Loader2,
  Droplets,
  Sun,
  Beaker,
  Layers,
  Wind,
  Flame,
  Wallet,
  Gem,
  Crown,
  AlertTriangle,
  CheckCircle2,
  ShoppingBag,
  ArrowUpRight,
} from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { isPreview } from '@/lib/preview';
import { lookupIngredient, type IngredientCategory } from '@/lib/ingredient-knowledge';

const CAT_STYLE: Record<IngredientCategory, { dot: string; tint: string; label: string }> = {
  hydrator: { dot: 'bg-sky-500', tint: 'bg-sky-50 text-sky-800 border-sky-200', label: 'Hydrator' },
  barrier: { dot: 'bg-emerald-500', tint: 'bg-emerald-50 text-emerald-800 border-emerald-200', label: 'Barrier' },
  emollient: { dot: 'bg-amber-500', tint: 'bg-amber-50 text-amber-800 border-amber-200', label: 'Emollient' },
  occlusive: { dot: 'bg-orange-500', tint: 'bg-orange-50 text-orange-800 border-orange-200', label: 'Occlusive' },
  active: { dot: 'bg-violet-500', tint: 'bg-violet-50 text-violet-800 border-violet-200', label: 'Active' },
  spf: { dot: 'bg-yellow-500', tint: 'bg-yellow-50 text-yellow-800 border-yellow-200', label: 'SPF' },
  peptide: { dot: 'bg-fuchsia-500', tint: 'bg-fuchsia-50 text-fuchsia-800 border-fuchsia-200', label: 'Peptide' },
  antioxidant: { dot: 'bg-rose-500', tint: 'bg-rose-50 text-rose-800 border-rose-200', label: 'Antioxidant' },
  soothing: { dot: 'bg-teal-500', tint: 'bg-teal-50 text-teal-800 border-teal-200', label: 'Soothing' },
  filler: { dot: 'bg-stone-400', tint: 'bg-stone-50 text-stone-700 border-stone-200', label: 'Filler' },
  preservative: { dot: 'bg-zinc-400', tint: 'bg-zinc-50 text-zinc-700 border-zinc-200', label: 'Preserv.' },
  fragrance: { dot: 'bg-bad-fg', tint: 'bg-bad-bg text-bad-fg border-bad-fg/30', label: 'Fragrance' },
};

const GENERIC_PURPOSE: Record<string, { category: IngredientCategory; benefit: string }> = {
  'salicylic acid': { category: 'active', benefit: 'Unclogs pores' },
  'glycolic acid': { category: 'active', benefit: 'Exfoliates surface' },
  'lactic acid': { category: 'active', benefit: 'Gentle exfoliant' },
  'mandelic acid': { category: 'active', benefit: 'Gentle AHA' },
  'tranexamic acid': { category: 'active', benefit: 'Fades dark spots' },
  'retinol': { category: 'active', benefit: 'Cell turnover' },
  'tamanu oil': { category: 'emollient', benefit: 'Soothing oil' },
  'shea butter': { category: 'occlusive', benefit: 'Rich moisture seal' },
  'squalane': { category: 'emollient', benefit: 'Lightweight oil' },
  'sunflower seed oil': { category: 'emollient', benefit: 'Plant oil' },
  'hemp seed oil': { category: 'emollient', benefit: 'Omega-rich oil' },
  'silica': { category: 'filler', benefit: 'Smooths texture' },
  'centella asiatica': { category: 'soothing', benefit: 'Calms redness' },
  'green tea': { category: 'antioxidant', benefit: 'Protects skin' },
  'vitamin e': { category: 'antioxidant', benefit: 'Protects + heals' },
  'liquorice root': { category: 'soothing', benefit: 'Brightens, calms' },
  'liquorice': { category: 'soothing', benefit: 'Brightens, calms' },
  'ferulic acid': { category: 'antioxidant', benefit: 'Boosts vit C' },
  'l-ascorbic acid 15%': { category: 'antioxidant', benefit: 'Brightens skin' },
  'l-ascorbic acid': { category: 'antioxidant', benefit: 'Brightens skin' },
  'thd ascorbate': { category: 'antioxidant', benefit: 'Stable vit C' },
  'propolis': { category: 'soothing', benefit: 'Heals + hydrates' },
  'calendula extract': { category: 'soothing', benefit: 'Anti-inflam.' },
  'red bean extract': { category: 'soothing', benefit: 'Mild cleanse' },
  'rice powder': { category: 'soothing', benefit: 'Soft polish' },
  'rice extract': { category: 'soothing', benefit: 'Brightens' },
  'matcha': { category: 'antioxidant', benefit: 'Protects skin' },
  'birch sap': { category: 'hydrator', benefit: 'Natural water' },
  'chemical filters': { category: 'spf', benefit: 'UV protection' },
  'avobenzone': { category: 'spf', benefit: 'UVA filter' },
  'octisalate': { category: 'spf', benefit: 'UVB filter' },
  'octinoxate': { category: 'spf', benefit: 'UVB filter' },
  'cell-ox shield': { category: 'spf', benefit: 'Broad-spectrum' },
  'zinc oxide': { category: 'spf', benefit: 'Mineral UV block' },
  'titanium dioxide': { category: 'spf', benefit: 'Mineral UV block' },
  'tinosorb': { category: 'spf', benefit: 'EU UV filter' },
  'mexoryl': { category: 'spf', benefit: 'EU UV filter' },
  'synchroshield': { category: 'spf', benefit: 'Sweat-activated' },
  'polyplant': { category: 'soothing', benefit: 'Botanical blend' },
  'beta-glucan': { category: 'soothing', benefit: 'Soothes + repairs' },
  '5 hyaluronic acids': { category: 'hydrator', benefit: 'Layered hydration' },
  'milk vetch root': { category: 'soothing', benefit: 'K-beauty calmer' },
  'phenol': { category: 'active', benefit: 'Surface renewal' },
  'witch hazel': { category: 'soothing', benefit: 'Astringent' },
  'purslane': { category: 'antioxidant', benefit: 'Anti-aging' },
  'pitera (galactomyces)': { category: 'soothing', benefit: 'Ferment essence' },
  'pitera': { category: 'soothing', benefit: 'Ferment essence' },
  'jaum balancing complex': { category: 'soothing', benefit: 'Korean herb mix' },
  'japanese wild rose': { category: 'soothing', benefit: 'Botanical extract' },
  'hadasei-3': { category: 'soothing', benefit: 'Tatcha trio' },
  'tfc8': { category: 'peptide', benefit: 'Signal peptide' },
  'pha': { category: 'active', benefit: 'Gentlest acid' },
  'aha': { category: 'active', benefit: 'Surface exfoliant' },
  'bha': { category: 'active', benefit: 'Pore exfoliant' },
  'zinc pca': { category: 'soothing', benefit: 'Calms + regulates' },
  'panthenol': { category: 'hydrator', benefit: 'Heals + hydrates' },
  'encapsulated retinol': { category: 'active', benefit: 'Stable retinol' },
  'sunflower oil': { category: 'emollient', benefit: 'Plant oil' },
  'tasmanian pepperberry': { category: 'soothing', benefit: 'Calms AHA sting' },
  'mushroom extract': { category: 'soothing', benefit: 'Hydrating ferment' },
  'probiotics': { category: 'soothing', benefit: 'Microbiome support' },
  'citric acid': { category: 'active', benefit: 'pH balance' },
  'glycerin': { category: 'hydrator', benefit: 'Pulls in water' },
};

function explainIngredient(name: string): { category: IngredientCategory; benefit: string } | null {
  const hit = lookupIngredient(name);
  if (hit) return { category: hit.category, benefit: hit.benefit };
  const key = name.toLowerCase().trim();
  if (GENERIC_PURPOSE[key]) return GENERIC_PURPOSE[key];
  for (const k of Object.keys(GENERIC_PURPOSE)) {
    if (key.includes(k)) return GENERIC_PURPOSE[k];
  }
  return null;
}

type Goal = 'cleanser' | 'moisturizer' | 'serum' | 'sunscreen' | 'toner' | 'exfoliant';
type Budget = 'drugstore' | 'mid' | 'luxury';

type Recommendation = {
  brand: string;
  productName: string;
  category: string;
  priceRange: string;
  keyIngredients: string[];
  whyItFits: string;
  watchOuts: string | null;
};

type ApiResponse = {
  result: { recommendations: Recommendation[] };
  meta?: { avoidCount: number; preferCount: number };
};

const GOALS: { value: Goal; label: string; icon: React.ReactNode; tint: string }[] = [
  { value: 'cleanser', label: 'Cleanser', icon: <Droplets size={16} />, tint: 'from-sky-100 to-sky-50 text-sky-700' },
  { value: 'moisturizer', label: 'Moisturizer', icon: <Layers size={16} />, tint: 'from-rose-100 to-rose-50 text-rose-700' },
  { value: 'serum', label: 'Serum', icon: <Beaker size={16} />, tint: 'from-violet-100 to-violet-50 text-violet-700' },
  { value: 'sunscreen', label: 'Sunscreen', icon: <Sun size={16} />, tint: 'from-amber-100 to-amber-50 text-amber-700' },
  { value: 'toner', label: 'Toner', icon: <Wind size={16} />, tint: 'from-emerald-100 to-emerald-50 text-emerald-700' },
  { value: 'exfoliant', label: 'Exfoliant', icon: <Flame size={16} />, tint: 'from-orange-100 to-orange-50 text-orange-700' },
];

const BUDGET_PRESETS: { label: string; max: number; icon: React.ReactNode; accent: string; hint: string }[] = [
  { label: 'Everyday', max: 20, hint: '≤ $20', icon: <Wallet size={16} />, accent: 'good' },
  { label: 'Mid', max: 50, hint: '≤ $50', icon: <Gem size={16} />, accent: 'primary' },
  { label: 'Luxury', max: 100, hint: '≤ $100', icon: <Crown size={16} />, accent: 'unsure' },
];

const BUDGET_ACCENT: Record<string, { text: string; bg: string; ring: string; track: string }> = {
  good: { text: 'text-good-fg', bg: 'bg-good-bg', ring: 'border-good-fg', track: 'from-good-bg via-good-fg/40 to-good-fg' },
  primary: { text: 'text-primary', bg: 'bg-primary/10', ring: 'border-primary', track: 'from-primary/15 via-primary/50 to-primary' },
  unsure: { text: 'text-unsure-fg', bg: 'bg-unsure-bg', ring: 'border-unsure-fg', track: 'from-unsure-bg via-unsure-fg/40 to-unsure-fg' },
};

function tierFromPrice(max: number): 'good' | 'primary' | 'unsure' {
  if (max <= 20) return 'good';
  if (max <= 50) return 'primary';
  return 'unsure';
}
function tierLabel(max: number): string {
  if (max <= 20) return 'Everyday';
  if (max <= 50) return 'Mid';
  return 'Luxury';
}

const QUICK_NOTES = [
  'sensitive skin',
  'fragrance-free',
  'acne-prone',
  'dry skin',
  'oily skin',
  'rosacea',
  'pregnancy-safe',
];

export default function Recommend() {
  const [goal, setGoal] = useState<Goal>('moisturizer');
  const [maxPrice, setMaxPrice] = useState<number>(50);
  const [count, setCount] = useState<number>(12);
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [recs, setRecs] = useState<Recommendation[] | null>(null);
  const [meta, setMeta] = useState<ApiResponse['meta'] | null>(null);

  const tier = tierFromPrice(maxPrice);
  const tierName = tierLabel(maxPrice);
  const budget: Budget = maxPrice <= 20 ? 'drugstore' : maxPrice <= 50 ? 'mid' : 'luxury';

  function toggleNote(n: string) {
    const tokens = notes
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    const has = tokens.includes(n);
    const next = has ? tokens.filter((t) => t !== n) : [...tokens, n];
    setNotes(next.join(', '));
  }

  async function getRecommendations() {
    setLoading(true);
    setError(null);
    setRecs(null);
    setMeta(null);

    if (isPreview()) {
      await new Promise((r) => setTimeout(r, 900));
      setRecs(mockRecsFor(goal, maxPrice, count));
      setMeta({ avoidCount: 7, preferCount: 4 });
      setLoading(false);
      return;
    }

    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session?.access_token) {
        throw new Error('Sign in required');
      }
      const r = await fetch('/api/recommend', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({ goal, budget, maxPrice, count, notes: notes.trim() || undefined }),
      });
      if (!r.ok) {
        const e = await r.json().catch(() => ({}));
        throw new Error(e.error ?? `HTTP ${r.status}`);
      }
      const data = (await r.json()) as ApiResponse;
      setRecs(data.result?.recommendations ?? []);
      setMeta(data.meta ?? null);
    } catch (e: any) {
      setError(String(e?.message ?? e));
    } finally {
      setLoading(false);
    }
  }

  const selectedGoal = GOALS.find((g) => g.value === goal)!;
  const activeNotes = notes
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  return (
    <div className="relative max-w-4xl">
      <div aria-hidden className="pointer-events-none absolute -top-20 -right-10 size-72 rounded-full blur-3xl bg-gradient-to-br from-primary/15 to-transparent" />

      <div className="relative mb-8">
        <div className="inline-flex items-center gap-2 text-[10px] uppercase tracking-[0.18em] text-primary bg-primary/10 border border-primary/25 px-3 py-1.5 rounded-full font-semibold mb-4">
          <Sparkles size={11} />
          AI Picks
        </div>
        <h1 className="font-display text-5xl leading-[0.95] tracking-tight">
          Find your next <em className="italic font-display text-primary">match.</em>
        </h1>
        <p className="text-muted text-sm mt-3 max-w-prose">
          We screen against ingredients tied to your bad and unsure logs, lean toward what your good ones share, then pick three real products at your price point.
        </p>
      </div>

      <div className="relative card p-6 md:p-8 overflow-hidden">
        <div aria-hidden className="absolute -top-16 -left-16 size-40 rounded-full blur-3xl bg-gradient-to-br from-primary/10 to-transparent" />

        <div className="relative">
          <div className="flex items-center justify-between mb-3">
            <label className="text-[10px] uppercase tracking-[0.16em] text-muted font-semibold">Category</label>
            <span className="text-xs text-muted">Pick one</span>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2">
            {GOALS.map((g) => {
              const selected = goal === g.value;
              return (
                <button
                  key={g.value}
                  type="button"
                  onClick={() => setGoal(g.value)}
                  className={`group relative flex flex-col items-center gap-1.5 rounded-xl border px-2 py-3 text-xs font-medium transition-all duration-200 ${
                    selected
                      ? 'border-ink bg-ink text-card shadow-soft -translate-y-0.5'
                      : 'border-border bg-card hover:border-primary/40 hover:-translate-y-0.5'
                  }`}
                >
                  <div
                    className={`size-9 rounded-lg flex items-center justify-center transition-all ${
                      selected ? 'bg-card/15 text-card' : `bg-gradient-to-br ${g.tint}`
                    }`}
                  >
                    {g.icon}
                  </div>
                  <span>{g.label}</span>
                </button>
              );
            })}
          </div>
        </div>

        <div className="relative mt-7">
          <div className="flex items-center justify-between mb-3">
            <label className="text-[10px] uppercase tracking-[0.16em] text-muted font-semibold">Budget</label>
            <div className="flex items-center gap-2">
              <span className={`text-[11px] font-mono px-2 py-0.5 rounded-md ${BUDGET_ACCENT[tier].bg} ${BUDGET_ACCENT[tier].text} font-semibold`}>
                {tierName}
              </span>
              <span className="text-xs text-muted">up to <span className="text-ink font-display text-base">${maxPrice}</span></span>
            </div>
          </div>

          <div className="relative px-1 pt-2 pb-1">
            <div className={`absolute left-1 right-1 top-1/2 -translate-y-1/2 h-1.5 rounded-full bg-gradient-to-r ${BUDGET_ACCENT[tier].track} opacity-70`} />
            <input
              type="range"
              min={10}
              max={100}
              step={5}
              value={maxPrice}
              onChange={(e) => setMaxPrice(Number(e.target.value))}
              className="relative w-full appearance-none bg-transparent cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:size-5 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-ink [&::-webkit-slider-thumb]:border-2 [&::-webkit-slider-thumb]:border-card [&::-webkit-slider-thumb]:shadow-soft [&::-webkit-slider-thumb]:transition-transform hover:[&::-webkit-slider-thumb]:scale-110 [&::-moz-range-thumb]:size-5 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-ink [&::-moz-range-thumb]:border-2 [&::-moz-range-thumb]:border-card [&::-moz-range-thumb]:shadow-soft"
            />
          </div>
          <div className="flex items-center justify-between text-[10px] text-muted font-mono px-1 mt-0.5">
            <span>$10</span>
            <span>$30</span>
            <span>$55</span>
            <span>$80</span>
            <span>$100</span>
          </div>

          <div className="flex flex-wrap gap-2 mt-3">
            {BUDGET_PRESETS.map((p) => {
              const selected = maxPrice === p.max;
              const a = BUDGET_ACCENT[p.accent];
              return (
                <button
                  key={p.label}
                  type="button"
                  onClick={() => setMaxPrice(p.max)}
                  className={`group inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-xs transition ${
                    selected
                      ? `${a.ring} ${a.bg} ${a.text} font-semibold`
                      : 'border-border text-muted hover:border-muted hover:text-ink'
                  }`}
                >
                  <span className={selected ? '' : a.text}>{p.icon}</span>
                  {p.label}
                  <span className="text-[10px] opacity-70 font-mono">{p.hint}</span>
                  {selected && <CheckCircle2 size={12} />}
                </button>
              );
            })}
          </div>
        </div>

        <div className="relative mt-7">
          <div className="flex items-center justify-between mb-3">
            <label className="text-[10px] uppercase tracking-[0.16em] text-muted font-semibold">How many picks</label>
            <span className="text-xs text-muted">
              <span className="font-display text-base text-ink">{count}</span> {count === 1 ? 'product' : 'products'}
            </span>
          </div>
          <div className="relative px-1 pt-2 pb-1">
            <div className="absolute left-1 right-1 top-1/2 -translate-y-1/2 h-1.5 rounded-full bg-gradient-to-r from-primary/15 via-primary/50 to-primary opacity-70" />
            <input
              type="range"
              min={3}
              max={100}
              step={1}
              value={count}
              onChange={(e) => setCount(Number(e.target.value))}
              className="relative w-full appearance-none bg-transparent cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:size-5 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-primary [&::-webkit-slider-thumb]:border-2 [&::-webkit-slider-thumb]:border-card [&::-webkit-slider-thumb]:shadow-soft [&::-webkit-slider-thumb]:transition-transform hover:[&::-webkit-slider-thumb]:scale-110 [&::-moz-range-thumb]:size-5 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-primary [&::-moz-range-thumb]:border-2 [&::-moz-range-thumb]:border-card [&::-moz-range-thumb]:shadow-soft"
            />
          </div>
          <div className="flex items-center justify-between text-[10px] text-muted font-mono px-1 mt-0.5">
            <span>3</span>
            <span>25</span>
            <span>50</span>
            <span>75</span>
            <span>100</span>
          </div>
          <div className="flex flex-wrap gap-2 mt-3">
            {[6, 12, 24, 50, 100].map((n) => {
              const selected = count === n;
              return (
                <button
                  key={n}
                  type="button"
                  onClick={() => setCount(n)}
                  className={`text-xs rounded-full border px-3 py-1 transition ${
                    selected
                      ? 'border-primary bg-primary/10 text-primary font-semibold'
                      : 'border-border text-muted hover:border-muted hover:text-ink'
                  }`}
                >
                  {n}
                </button>
              );
            })}
          </div>
          {count > 30 && (
            <p className="text-[11px] text-unsure-fg mt-2 flex items-start gap-1.5">
              <AlertTriangle size={12} className="shrink-0 mt-0.5" />
              Large lists may surface duplicates or stretch into adjacent budget tiers.
            </p>
          )}
        </div>

        <div className="relative mt-7">
          <div className="flex items-center justify-between mb-3">
            <label className="text-[10px] uppercase tracking-[0.16em] text-muted font-semibold">Notes</label>
            <span className="text-xs text-muted">{notes.length}/500</span>
          </div>
          <textarea
            className="input min-h-20 text-sm font-mono leading-relaxed"
            placeholder="dry skin, sensitive, fragrance-free, acne-prone…"
            value={notes}
            onChange={(e) => setNotes(e.target.value.slice(0, 500))}
            maxLength={500}
          />
          <div className="flex flex-wrap gap-1.5 mt-2.5">
            {QUICK_NOTES.map((n) => {
              const on = activeNotes.includes(n);
              return (
                <button
                  key={n}
                  type="button"
                  onClick={() => toggleNote(n)}
                  className={`text-[11px] px-2.5 py-1 rounded-full border transition ${
                    on
                      ? 'border-ink bg-ink text-card'
                      : 'border-border text-muted hover:border-muted hover:text-ink'
                  }`}
                >
                  {on ? '✓ ' : '+ '}
                  {n}
                </button>
              );
            })}
          </div>
        </div>

        <div className="relative flex items-center justify-between gap-3 mt-7 pt-5 border-t border-border/60">
          <div className="text-[11px] text-muted">
            <span className="text-ink font-medium">{count}</span> {selectedGoal.label.toLowerCase()}{count === 1 ? '' : 's'} · ≤<span className="text-ink font-medium">${maxPrice}</span>
            {meta && (
              <span className="ml-2 hidden sm:inline">
                · {meta.avoidCount} avoid · {meta.preferCount} prefer
              </span>
            )}
          </div>
          <button
            className="btn-primary group"
            disabled={loading}
            onClick={getRecommendations}
          >
            {loading ? (
              <>
                <Loader2 size={16} className="animate-spin" />
                Finding picks…
              </>
            ) : (
              <>
                <Sparkles size={16} className="group-hover:rotate-12 transition-transform" />
                Get recommendations
              </>
            )}
          </button>
        </div>

        {error && (
          <div className="relative mt-4 flex items-start gap-2 text-sm text-bad-fg bg-bad-bg border border-bad-fg/20 rounded-lg px-3 py-2.5">
            <AlertTriangle size={16} className="shrink-0 mt-0.5" />
            <span>Recommendation failed: {error}</span>
          </div>
        )}
      </div>

      {loading && !recs && (
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: Math.min(count, 6) }, (_, i) => i).map((i) => (
            <div key={i} className="card p-6 overflow-hidden">
              <div className="h-3 w-20 bg-border rounded animate-pulse mb-3" />
              <div className="h-5 w-3/4 bg-border rounded animate-pulse mb-2" />
              <div className="h-3 w-1/2 bg-border rounded animate-pulse mb-5" />
              <div className="space-y-2">
                <div className="h-2.5 bg-border/60 rounded animate-pulse" />
                <div className="h-2.5 bg-border/60 rounded animate-pulse w-5/6" />
                <div className="h-2.5 bg-border/60 rounded animate-pulse w-2/3" />
              </div>
              <div className="flex gap-1.5 mt-4">
                <div className="h-5 w-12 bg-border rounded-full animate-pulse" />
                <div className="h-5 w-16 bg-border rounded-full animate-pulse" />
                <div className="h-5 w-14 bg-border rounded-full animate-pulse" />
              </div>
            </div>
          ))}
        </div>
      )}

      {recs && recs.length === 0 && (
        <div className="card mt-6 p-8 text-center">
          <div className="mx-auto size-12 rounded-full bg-unsure-bg text-unsure-fg flex items-center justify-center mb-3">
            <HelpCircleIcon />
          </div>
          <div className="font-display text-xl mb-1">No picks found</div>
          <p className="text-sm text-muted max-w-md mx-auto">
            The model returned an empty list. Try a different budget tier or drop a constraint from your notes.
          </p>
        </div>
      )}

      {recs && recs.length > 0 && (
        <div className="mt-8">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="font-display text-2xl">
                Picked for <em className="italic text-primary">you.</em>
              </h2>
              <p className="text-xs text-muted mt-1">
                {recs.length} {recs.length === 1 ? 'match' : 'matches'} · screened against your logs
              </p>
            </div>
            <button
              onClick={getRecommendations}
              disabled={loading}
              className="text-xs text-muted hover:text-ink transition flex items-center gap-1.5"
            >
              <Sparkles size={12} />
              Reroll
            </button>
          </div>

          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {recs.map((r, i) => (
              <RecCard key={i} rec={r} index={i} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

const MOCK_LIBRARY: Record<Goal, Record<Budget, Recommendation[]>> = {
  moisturizer: {
    drugstore: [
      { brand: 'CeraVe', productName: 'Daily Moisturizing Lotion', category: 'moisturizer', priceRange: '$14',
        keyIngredients: ['Ceramide NP', 'Hyaluronic Acid', 'Niacinamide', 'Glycerin'],
        whyItFits: 'Fragrance-free ceramide trio rebuilds your barrier — overlaps the ingredients your good logs share.',
        watchOuts: null },
      { brand: 'Vanicream', productName: 'Daily Facial Moisturizer', category: 'moisturizer', priceRange: '$16',
        keyIngredients: ['Squalane', 'Glycerin', 'Hyaluronic Acid', 'Ceramide NP'],
        whyItFits: 'Stripped formula — no fragrance, no bisabolol, no botanicals. Safe pick given your fragrance flares.',
        watchOuts: null },
      { brand: 'La Roche-Posay', productName: 'Toleriane Double Repair', category: 'moisturizer', priceRange: '$20',
        keyIngredients: ['Niacinamide', 'Ceramide NP', 'Glycerin', 'Shea Butter'],
        whyItFits: 'You already love this one — your "good" Toleriane is the template, this is the daily driver.',
        watchOuts: null },
    ],
    mid: [
      { brand: 'Stratia', productName: 'Liquid Gold', category: 'moisturizer', priceRange: '$28',
        keyIngredients: ['Squalane', 'Ceramide NP', 'Ceramide AP', 'Cholesterol', 'Niacinamide'],
        whyItFits: 'Cholesterol + ceramide + fatty acid ratio mimics intact skin barrier — barrier saver per your logs.',
        watchOuts: null },
      { brand: 'Krave Beauty', productName: 'Great Barrier Relief', category: 'moisturizer', priceRange: '$32',
        keyIngredients: ['Tamanu Oil', 'Centella Asiatica', 'Niacinamide', 'Glycerin'],
        whyItFits: 'Lightweight occlusive layer without your fragrance triggers. Calms post-flare days.',
        watchOuts: 'Contains tamanu oil — patch test if very acne-prone.' },
      { brand: 'Glossier', productName: 'Priming Moisturizer Balance', category: 'moisturizer', priceRange: '$30',
        keyIngredients: ['Niacinamide', 'Zinc PCA', 'Silica', 'Hyaluronic Acid'],
        whyItFits: 'Niacinamide + zinc combo your skin already responds well to. Lightweight, no botanicals.',
        watchOuts: null },
    ],
    luxury: [
      { brand: 'Skinceuticals', productName: 'Triple Lipid Restore 2:4:2', category: 'moisturizer', priceRange: '$140',
        keyIngredients: ['Ceramide', 'Cholesterol', 'Fatty Acids'],
        whyItFits: 'Clinical-grade barrier rebuild ratio. Worth it if budget allows — your "good" picks all favor ceramides.',
        watchOuts: null },
      { brand: 'Augustinus Bader', productName: 'The Cream', category: 'moisturizer', priceRange: '$285',
        keyIngredients: ['TFC8', 'Squalane', 'Shea Butter', 'Vitamin E'],
        whyItFits: 'Fragrance-free, peptide-driven hydration. No botanical extracts that triggered your past flares.',
        watchOuts: 'Premium pricing — diminishing returns over $50 mid-tier picks.' },
      { brand: 'Tatcha', productName: 'The Water Cream', category: 'moisturizer', priceRange: '$72',
        keyIngredients: ['Japanese Wild Rose', 'Hadasei-3', 'Green Tea'],
        whyItFits: 'Oil-free gel-cream texture for combo skin. Watch the botanical complex though.',
        watchOuts: 'Contains plant extracts — your Tatcha Dewy Skin Cream flared, this is lighter.' },
    ],
  },
  cleanser: {
    drugstore: [
      { brand: 'CeraVe', productName: 'Hydrating Cleanser', category: 'cleanser', priceRange: '$15',
        keyIngredients: ['Ceramide NP', 'Hyaluronic Acid', 'Glycerin'],
        whyItFits: 'Non-stripping cream cleanser — already in your "good" logs.', watchOuts: null },
      { brand: 'Vanicream', productName: 'Gentle Facial Cleanser', category: 'cleanser', priceRange: '$10',
        keyIngredients: ['Glycerin', 'Squalane'], whyItFits: 'Free of common irritants and fragrance.', watchOuts: null },
      { brand: 'La Roche-Posay', productName: 'Toleriane Hydrating Cleanser', category: 'cleanser', priceRange: '$18',
        keyIngredients: ['Niacinamide', 'Ceramide NP', 'Glycerin'], whyItFits: 'Same Toleriane line you tolerate well.', watchOuts: null },
    ],
    mid: [
      { brand: 'Krave', productName: 'Matcha Hemp Hydrating Cleanser', category: 'cleanser', priceRange: '$22',
        keyIngredients: ['Matcha', 'Hemp Seed Oil', 'Glycerin'], whyItFits: 'Low-pH, no sulfates, no fragrance.', watchOuts: null },
      { brand: 'iUNIK', productName: 'Calendula Complete Cleansing Oil', category: 'cleanser', priceRange: '$24',
        keyIngredients: ['Calendula Extract', 'Sunflower Seed Oil'], whyItFits: 'First-cleanse oil that emulsifies clean.', watchOuts: 'Botanical extract — patch test.' },
      { brand: 'Beauty of Joseon', productName: 'Red Bean Cleansing Foam', category: 'cleanser', priceRange: '$20',
        keyIngredients: ['Red Bean Extract', 'Niacinamide'], whyItFits: 'pH-balanced foaming, no fragrance.', watchOuts: null },
    ],
    luxury: [
      { brand: 'iS Clinical', productName: 'Cleansing Complex', category: 'cleanser', priceRange: '$50',
        keyIngredients: ['Salicylic Acid', 'Glycolic Acid', 'Centella'], whyItFits: 'Mild acid cleanse for acne-prone with barrier respect.', watchOuts: 'Mild exfoliation — alternate with hydrating cleanser.' },
      { brand: 'Tatcha', productName: 'The Rice Wash', category: 'cleanser', priceRange: '$40',
        keyIngredients: ['Rice Powder', 'Hyaluronic Acid'], whyItFits: 'Creamy hydrating wash if you want indulgence.', watchOuts: null },
      { brand: 'Dr. Barbara Sturm', productName: 'Cleanser', category: 'cleanser', priceRange: '$60',
        keyIngredients: ['Purslane', 'Panthenol'], whyItFits: 'Anti-inflammatory cleanse for sensitive skin.', watchOuts: 'Premium for what it is.' },
    ],
  },
  serum: {
    drugstore: [
      { brand: 'The Ordinary', productName: 'Niacinamide 10% + Zinc 1%', category: 'serum', priceRange: '$7',
        keyIngredients: ['Niacinamide', 'Zinc PCA'], whyItFits: 'You already love this — calms redness, regulates oil.', watchOuts: null },
      { brand: 'The Ordinary', productName: 'Hyaluronic Acid 2% + B5', category: 'serum', priceRange: '$9',
        keyIngredients: ['Hyaluronic Acid', 'Panthenol'], whyItFits: 'Pure hydration, no botanicals.', watchOuts: null },
      { brand: 'Naturium', productName: 'Mandelic Acid 12%', category: 'serum', priceRange: '$18',
        keyIngredients: ['Mandelic Acid', 'Niacinamide'], whyItFits: 'Gentle AHA for texture without irritation.', watchOuts: 'Use 2-3x/week max.' },
    ],
    mid: [
      { brand: 'Paula\'s Choice', productName: 'C15 Super Booster', category: 'serum', priceRange: '$49',
        keyIngredients: ['L-Ascorbic Acid 15%', 'Vitamin E', 'Ferulic Acid'], whyItFits: 'Brightening + antioxidant duo.', watchOuts: 'Morning use, layer SPF.' },
      { brand: 'Good Molecules', productName: 'Discoloration Correcting Serum', category: 'serum', priceRange: '$22',
        keyIngredients: ['Tranexamic Acid', 'Niacinamide'], whyItFits: 'Spot-fade without retinol harshness.', watchOuts: null },
      { brand: 'Beauty of Joseon', productName: 'Glow Serum', category: 'serum', priceRange: '$18',
        keyIngredients: ['Propolis', 'Niacinamide'], whyItFits: 'Soothing + glow boost.', watchOuts: 'Bee derivative — skip if allergic.' },
    ],
    luxury: [
      { brand: 'Skinceuticals', productName: 'CE Ferulic', category: 'serum', priceRange: '$182',
        keyIngredients: ['L-Ascorbic Acid 15%', 'Vitamin E', 'Ferulic Acid'], whyItFits: 'Gold-standard antioxidant serum. Patented stability.', watchOuts: 'Pricey. Generic C15 covers 80% of effect.' },
      { brand: 'Dr. Dennis Gross', productName: 'Vitamin C Lactic Firm & Bright Serum', category: 'serum', priceRange: '$78',
        keyIngredients: ['THD Ascorbate', 'Lactic Acid'], whyItFits: 'Stable Vit C + mild exfoliation.', watchOuts: null },
      { brand: 'Sunday Riley', productName: 'B3 Nice', category: 'serum', priceRange: '$80',
        keyIngredients: ['Niacinamide 10%', 'Liquorice'], whyItFits: 'Premium niacinamide if Ordinary too basic.', watchOuts: 'Same active for 10x price.' },
    ],
  },
  sunscreen: {
    drugstore: [
      { brand: 'Beauty of Joseon', productName: 'Relief Sun SPF 50+ PA++++', category: 'sunscreen', priceRange: '$18',
        keyIngredients: ['Chemical filters', 'Rice Extract', 'Probiotics'], whyItFits: 'Cult favorite — no white cast, no fragrance.', watchOuts: null },
      { brand: 'CeraVe', productName: 'Hydrating Mineral Sunscreen SPF 30', category: 'sunscreen', priceRange: '$15',
        keyIngredients: ['Zinc Oxide', 'Titanium Dioxide', 'Niacinamide'], whyItFits: 'Mineral, fragrance-free, ceramide base.', watchOuts: 'Slight white cast.' },
      { brand: 'La Roche-Posay', productName: 'Anthelios Melt-In Milk SPF 60', category: 'sunscreen', priceRange: '$20',
        keyIngredients: ['Avobenzone', 'Octisalate', 'Cell-Ox Shield'], whyItFits: 'Lightweight, broad-spectrum.', watchOuts: null },
    ],
    mid: [
      { brand: 'Round Lab', productName: 'Birch Juice Moisturizing Sunscreen', category: 'sunscreen', priceRange: '$22',
        keyIngredients: ['Birch Sap', 'Panthenol', 'Chemical filters'], whyItFits: 'Hydrating Korean SPF, no fragrance.', watchOuts: null },
      { brand: 'Bioderma', productName: 'Photoderm Nude Touch SPF 50+', category: 'sunscreen', priceRange: '$30',
        keyIngredients: ['Tinosorb', 'Mexoryl'], whyItFits: 'European filters, lightweight tint.', watchOuts: null },
      { brand: 'Supergoop', productName: 'Unseen Sunscreen SPF 40', category: 'sunscreen', priceRange: '$38',
        keyIngredients: ['Avobenzone', 'Polyplant'], whyItFits: 'Invisible primer-style sunscreen.', watchOuts: 'Slightly silicone-heavy.' },
    ],
    luxury: [
      { brand: 'EltaMD', productName: 'UV Clear SPF 46', category: 'sunscreen', priceRange: '$41',
        keyIngredients: ['Zinc Oxide', 'Octinoxate', 'Niacinamide'], whyItFits: 'Dermatologist-favorite for acne-prone.', watchOuts: null },
      { brand: 'Shiseido', productName: 'Ultimate Sun Protector Lotion SPF 50+', category: 'sunscreen', priceRange: '$50',
        keyIngredients: ['Synchroshield', 'Hyaluronic Acid'], whyItFits: 'Sweat-activated UV protection.', watchOuts: null },
      { brand: 'Tatcha', productName: 'Silken Pore Perfecting Sunscreen SPF 35', category: 'sunscreen', priceRange: '$65',
        keyIngredients: ['Zinc Oxide', 'Hadasei-3'], whyItFits: 'Mineral with luxury feel.', watchOuts: 'Premium pricing.' },
    ],
  },
  toner: {
    drugstore: [
      { brand: 'Klairs', productName: 'Supple Preparation Unscented Toner', category: 'toner', priceRange: '$22',
        keyIngredients: ['Hyaluronic Acid', 'Beta-Glucan'], whyItFits: 'Fragrance-free, hydrating layer.', watchOuts: null },
      { brand: 'Hada Labo', productName: 'Gokujyun Hyaluronic Lotion', category: 'toner', priceRange: '$15',
        keyIngredients: ['5 Hyaluronic Acids'], whyItFits: 'Pure HA hydration, no botanicals.', watchOuts: null },
      { brand: 'COSRX', productName: 'AHA/BHA Clarifying Treatment Toner', category: 'toner', priceRange: '$14',
        keyIngredients: ['Glycolic Acid', 'Salicylic Acid'], whyItFits: 'Mild dual acid for texture.', watchOuts: 'Alternate days.' },
    ],
    mid: [
      { brand: 'Pyunkang Yul', productName: 'Essence Toner', category: 'toner', priceRange: '$22',
        keyIngredients: ['Milk Vetch Root', 'Glycerin'], whyItFits: 'Single-ingredient simplicity.', watchOuts: null },
      { brand: 'Biologique Recherche', productName: 'Lotion P50 1970 (sample)', category: 'toner', priceRange: '$32',
        keyIngredients: ['Phenol', 'Lactic Acid', 'Niacinamide'], whyItFits: 'Cult classic exfoliating toner.', watchOuts: 'Strong — patch test.' },
      { brand: 'Glow Recipe', productName: 'Watermelon Glow PHA Toner', category: 'toner', priceRange: '$34',
        keyIngredients: ['PHA', 'Hyaluronic Acid'], whyItFits: 'Gentlest acid family.', watchOuts: 'Watermelon flared you before — different formula.' },
    ],
    luxury: [
      { brand: 'SK-II', productName: 'Facial Treatment Essence', category: 'toner', priceRange: '$185',
        keyIngredients: ['Pitera (Galactomyces)'], whyItFits: 'Cult fermented essence.', watchOuts: 'Pricey for fermentation.' },
      { brand: 'Sulwhasoo', productName: 'First Care Activating Serum', category: 'toner', priceRange: '$98',
        keyIngredients: ['JAUM Balancing Complex'], whyItFits: 'Korean luxury first-step.', watchOuts: 'Subtle fragrance.' },
      { brand: 'Dr. Barbara Sturm', productName: 'Balancing Toner', category: 'toner', priceRange: '$70',
        keyIngredients: ['Witch Hazel', 'Glycerin'], whyItFits: 'No alcohol, gentle.', watchOuts: null },
    ],
  },
  exfoliant: {
    drugstore: [
      { brand: 'Paula\'s Choice', productName: '2% BHA Liquid', category: 'exfoliant', priceRange: '$13',
        keyIngredients: ['Salicylic Acid', 'Green Tea'], whyItFits: 'Your holy grail — already in your good logs.', watchOuts: null },
      { brand: 'The Ordinary', productName: 'Glycolic Acid 7% Toning Solution', category: 'exfoliant', priceRange: '$10',
        keyIngredients: ['Glycolic Acid', 'Tasmanian Pepperberry'], whyItFits: 'Cheap AHA workhorse.', watchOuts: 'Strong — 2x/week max.' },
      { brand: 'CeraVe', productName: 'Resurfacing Retinol Serum', category: 'exfoliant', priceRange: '$22',
        keyIngredients: ['Encapsulated Retinol', 'Ceramide NP', 'Niacinamide'], whyItFits: 'Beginner retinol with barrier support.', watchOuts: 'Start 2x/week.' },
    ],
    mid: [
      { brand: 'Drunk Elephant', productName: 'TLC Framboos Glycolic Night Serum', category: 'exfoliant', priceRange: '$48',
        keyIngredients: ['Glycolic Acid', 'Lactic Acid', 'Salicylic Acid'], whyItFits: 'Triple-acid for resilient skin.', watchOuts: 'Drunk Elephant flared you before — patch test.' },
      { brand: 'Naturium', productName: 'Multi-Hydroxy Acid Glow Serum', category: 'exfoliant', priceRange: '$22',
        keyIngredients: ['Glycolic', 'Lactic', 'Mandelic', 'PHA'], whyItFits: 'Lower concentration, gentler.', watchOuts: null },
      { brand: 'Murad', productName: 'AHA/BHA Exfoliating Cleanser', category: 'exfoliant', priceRange: '$40',
        keyIngredients: ['Salicylic', 'Glycolic', 'Lactic'], whyItFits: 'Exfoliating cleanser format.', watchOuts: null },
    ],
    luxury: [
      { brand: 'Sunday Riley', productName: 'Good Genes Lactic Acid', category: 'exfoliant', priceRange: '$85',
        keyIngredients: ['Lactic Acid', 'Liquorice Root'], whyItFits: 'You logged this as unsure — premium AHA.', watchOuts: 'Already triggered redness for you.' },
      { brand: 'Dr. Dennis Gross', productName: 'Alpha Beta Universal Daily Peel', category: 'exfoliant', priceRange: '$95',
        keyIngredients: ['Glycolic', 'Salicylic', 'Citric', 'Lactic'], whyItFits: 'Two-step peel pads.', watchOuts: 'Strong — 3x/week max.' },
      { brand: 'iS Clinical', productName: 'Active Serum', category: 'exfoliant', priceRange: '$142',
        keyIngredients: ['Glycolic', 'Salicylic', 'Mushroom Extract'], whyItFits: 'Clinical exfoliant.', watchOuts: 'Premium pricing.' },
    ],
  },
};

function priceNum(s: string): number {
  const m = s.match(/(\d+(?:\.\d+)?)/);
  return m ? Number(m[1]) : 9999;
}

function mockRecsFor(goal: Goal, maxPrice: number, count: number): Recommendation[] {
  const tiers = MOCK_LIBRARY[goal];
  const all = [...tiers.drugstore, ...tiers.mid, ...tiers.luxury];
  const pool = all.filter((r) => priceNum(r.priceRange) <= maxPrice);
  if (pool.length === 0) return [];
  const sorted = [...pool].sort((a, b) => priceNum(a.priceRange) - priceNum(b.priceRange));
  if (count <= sorted.length) return sorted.slice(0, count);
  const out: Recommendation[] = [];
  let idx = 0;
  let pass = 1;
  while (out.length < count) {
    const base = sorted[idx % sorted.length];
    if (pass === 1) {
      out.push(base);
    } else {
      out.push({
        ...base,
        productName: `${base.productName} · v${pass}`,
        whyItFits: base.whyItFits,
      });
    }
    idx++;
    if (idx % sorted.length === 0) pass++;
  }
  return out;
}

function HelpCircleIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" />
      <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
      <line x1="12" y1="17" x2="12.01" y2="17" />
    </svg>
  );
}

function RecCard({ rec, index }: { rec: Recommendation; index: number }) {
  const searchQuery = encodeURIComponent(`${rec.brand} ${rec.productName}`);
  return (
    <div
      className="group relative card p-5 overflow-hidden transition-all duration-300 hover:-translate-y-1 hover:shadow-soft"
      style={{ animation: `streamIn 0.5s ease-out ${index * 80}ms both` }}
    >
      <div aria-hidden className="absolute -top-12 -right-12 size-28 rounded-full blur-2xl bg-gradient-to-br from-primary/12 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />

      <div className="relative flex items-start justify-between gap-3 mb-3">
        <div className="min-w-0 flex-1">
          <div className="text-[10px] uppercase tracking-[0.14em] text-muted font-semibold truncate">{rec.brand}</div>
          <div className="font-display text-lg leading-tight mt-0.5">{rec.productName}</div>
          <div className="text-[11px] text-muted mt-1 capitalize">{rec.category}</div>
        </div>
        <span className="shrink-0 text-[11px] font-mono px-2 py-1 rounded-md bg-good-bg text-good-fg border border-good-fg/15">
          {rec.priceRange}
        </span>
      </div>

      <p className="relative text-sm text-ink/85 leading-relaxed border-l-2 border-primary/30 pl-3 italic">
        {rec.whyItFits}
      </p>

      {rec.keyIngredients?.length > 0 && (
        <div className="relative mt-4">
          <div className="text-[10px] uppercase tracking-[0.14em] text-muted font-semibold mb-1.5">Key</div>
          <div className="flex flex-wrap gap-1.5">
            {rec.keyIngredients.slice(0, 6).map((ing, j) => {
              const info = explainIngredient(ing);
              const style = info ? CAT_STYLE[info.category] : null;
              return (
                <span
                  key={j}
                  title={info ? `${style!.label} · ${info.benefit}` : ing}
                  className={`inline-flex items-center gap-1.5 text-[11px] font-mono px-2 py-1 rounded-md border ${
                    style ? style.tint : 'bg-card border-border text-ink/80'
                  }`}
                >
                  {style && <span aria-hidden className={`size-1.5 rounded-full ${style.dot}`} />}
                  <span className="leading-none">{ing}</span>
                  {info && (
                    <span className="opacity-70 leading-none font-sans text-[10px] before:content-['·'] before:mx-1 before:opacity-60">
                      {info.benefit}
                    </span>
                  )}
                </span>
              );
            })}
          </div>
        </div>
      )}

      {rec.watchOuts && (
        <div className="relative mt-3 flex items-start gap-1.5 text-[11px] text-unsure-fg bg-unsure-bg/70 border border-unsure-fg/15 rounded-lg px-2.5 py-2">
          <AlertTriangle size={12} className="shrink-0 mt-0.5" />
          <span className="leading-snug">{rec.watchOuts}</span>
        </div>
      )}

      <div className="relative flex items-center gap-2 mt-4 pt-4 border-t border-border/60">
        <a
          href={`https://www.google.com/search?q=${searchQuery}+buy`}
          target="_blank"
          rel="noreferrer"
          className="flex-1 inline-flex items-center justify-center gap-1.5 text-xs font-medium px-3 py-2 rounded-lg bg-ink text-card hover:bg-primary transition group/cta"
        >
          <ShoppingBag size={13} />
          Shop
          <ArrowUpRight size={12} className="group-hover/cta:translate-x-0.5 group-hover/cta:-translate-y-0.5 transition-transform" />
        </a>
        <a
          href={`https://incidecoder.com/search?query=${searchQuery}`}
          target="_blank"
          rel="noreferrer"
          className="text-xs px-3 py-2 rounded-lg border border-border text-muted hover:text-ink hover:border-muted transition"
          title="Inspect on INCIDecoder"
        >
          INCI
        </a>
      </div>
    </div>
  );
}
