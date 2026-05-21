import { useState } from 'react';
import { Lightbulb, Sparkles, Loader2 } from 'lucide-react';
import { supabase } from '@/lib/supabase';

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

const GOALS: { value: Goal; label: string }[] = [
  { value: 'cleanser', label: 'Cleanser' },
  { value: 'moisturizer', label: 'Moisturizer' },
  { value: 'serum', label: 'Serum' },
  { value: 'sunscreen', label: 'Sunscreen' },
  { value: 'toner', label: 'Toner' },
  { value: 'exfoliant', label: 'Exfoliant' },
];

const BUDGETS: { value: Budget; label: string; hint: string }[] = [
  { value: 'drugstore', label: 'Drugstore', hint: 'Under $20' },
  { value: 'mid', label: 'Mid', hint: '$20–50' },
  { value: 'luxury', label: 'Luxury', hint: '$50+' },
];

export default function Recommend() {
  const [goal, setGoal] = useState<Goal>('moisturizer');
  const [budget, setBudget] = useState<Budget>('mid');
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [recs, setRecs] = useState<Recommendation[] | null>(null);
  const [meta, setMeta] = useState<ApiResponse['meta'] | null>(null);

  async function getRecommendations() {
    setLoading(true);
    setError(null);
    setRecs(null);
    setMeta(null);
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      const r = await fetch('/api/recommend', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${session?.access_token ?? ''}`,
        },
        body: JSON.stringify({ goal, budget, notes: notes.trim() || undefined }),
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

  return (
    <div className="max-w-3xl">
      <div className="mb-6">
        <h1 className="font-display text-4xl">Recommend</h1>
        <p className="text-muted text-sm mt-1">
          Pick a category and budget. We avoid ingredients tied to your bad/unsure products and prefer
          ingredients from your good ones.
        </p>
      </div>

      <div className="card p-6">
        <label className="label">Category</label>
        <select
          className="input"
          value={goal}
          onChange={(e) => setGoal(e.target.value as Goal)}
        >
          {GOALS.map((g) => (
            <option key={g.value} value={g.value}>
              {g.label}
            </option>
          ))}
        </select>

        <div className="mt-4">
          <div className="label">Budget</div>
          <div className="grid grid-cols-3 gap-2">
            {BUDGETS.map((b) => {
              const selected = budget === b.value;
              return (
                <label
                  key={b.value}
                  className={`cursor-pointer rounded-lg border px-3 py-2 text-center text-sm transition ${
                    selected ? 'border-ink bg-ink text-card' : 'border-muted/40 hover:border-muted'
                  }`}
                >
                  <input
                    type="radio"
                    name="budget"
                    className="sr-only"
                    value={b.value}
                    checked={selected}
                    onChange={() => setBudget(b.value)}
                  />
                  <div className="font-display">{b.label}</div>
                  <div className={`text-xs ${selected ? 'opacity-80' : 'text-muted'}`}>{b.hint}</div>
                </label>
              );
            })}
          </div>
        </div>

        <div className="mt-4">
          <label className="label">Notes (optional)</label>
          <textarea
            className="input min-h-20 text-sm"
            placeholder="e.g. dry skin, sensitive, fragrance-free, acne-prone…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            maxLength={500}
          />
        </div>

        <div className="flex items-center gap-3 mt-4">
          <button className="btn-primary" disabled={loading} onClick={getRecommendations}>
            {loading ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
            {loading ? 'Finding picks…' : 'Get recommendations'}
          </button>
          {meta && (
            <span className="text-xs text-muted">
              Filtered against {meta.avoidCount} avoid · {meta.preferCount} prefer
            </span>
          )}
        </div>
        {error && <p className="text-sm text-bad-fg mt-3">Recommendation failed: {error}</p>}
      </div>

      {recs && recs.length === 0 && (
        <div className="card mt-6 p-6 text-sm text-muted">
          The model returned no recommendations. Try adjusting your notes or budget.
        </div>
      )}

      {recs && recs.length > 0 && (
        <div className="mt-6 space-y-4">
          {recs.map((r, i) => (
            <div key={i} className="card p-6">
              <div className="flex items-start justify-between gap-3 mb-2">
                <div>
                  <div className="text-xs text-muted uppercase tracking-wide">{r.brand}</div>
                  <div className="font-display text-xl">{r.productName}</div>
                  <div className="text-xs text-muted mt-1">{r.category}</div>
                </div>
                <span className="text-xs font-mono px-2 py-1 rounded bg-good-bg text-good-fg shrink-0">
                  {r.priceRange}
                </span>
              </div>

              <p className="text-sm flex items-start gap-2 mt-3">
                <Lightbulb size={16} className="shrink-0 mt-0.5" />
                <span>{r.whyItFits}</span>
              </p>

              {r.keyIngredients?.length > 0 && (
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {r.keyIngredients.map((ing, j) => (
                    <span
                      key={j}
                      className="text-xs font-mono px-2 py-1 rounded bg-card border border-muted/30"
                    >
                      {ing}
                    </span>
                  ))}
                </div>
              )}

              {r.watchOuts && (
                <p className="mt-3 text-xs text-unsure-fg bg-unsure-bg rounded-lg px-3 py-2">
                  Watch-out: {r.watchOuts}
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
