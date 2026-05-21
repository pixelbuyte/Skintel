import { useEffect, useState } from 'react';
import { BookOpen, Calendar, Sparkles, Trash2, Loader2 } from 'lucide-react';
import { supabase } from '@/lib/supabase';

type Condition = 'clear' | 'mild' | 'moderate' | 'breakout';

type Entry = {
  id: string;
  entry_date: string;
  condition: Condition;
  notes: string | null;
  photo_url: string | null;
  created_at: string;
};

type Suspect = {
  productOrIngredient: string;
  confidence: 'high' | 'medium' | 'low';
  reasoning: string;
  evidenceDates: string[];
};

type AnalyzeResult = {
  summary: string;
  suspects: Suspect[];
  patterns: string[];
  recommendations: string[];
};

const CONDITION_META: Record<Condition, { label: string; bg: string; fg: string; ring: string }> = {
  clear: { label: 'Clear', bg: 'bg-good-bg', fg: 'text-good-fg', ring: 'ring-good-fg' },
  mild: { label: 'Mild', bg: 'bg-unsure-bg', fg: 'text-unsure-fg', ring: 'ring-unsure-fg' },
  moderate: { label: 'Moderate', bg: 'bg-unsure-bg', fg: 'text-unsure-fg', ring: 'ring-unsure-fg' },
  breakout: { label: 'Breakout', bg: 'bg-bad-bg', fg: 'text-bad-fg', ring: 'ring-bad-fg' },
};

function todayISO() {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

async function authHeader() {
  const { data: { session } } = await supabase.auth.getSession();
  return { authorization: `Bearer ${session?.access_token ?? ''}` };
}

export default function Journal() {
  const [entries, setEntries] = useState<Entry[]>([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const [entryDate, setEntryDate] = useState(todayISO());
  const [condition, setCondition] = useState<Condition>('clear');
  const [notes, setNotes] = useState('');
  const [photoUrl, setPhotoUrl] = useState('');
  const [saving, setSaving] = useState(false);

  const [analysis, setAnalysis] = useState<AnalyzeResult | null>(null);
  const [analyzeLoading, setAnalyzeLoading] = useState(false);
  const [analyzeErr, setAnalyzeErr] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setErr(null);
    try {
      const headers = await authHeader();
      const r = await fetch('/api/journal', { headers });
      if (!r.ok) {
        const e = await r.json().catch(() => ({}));
        throw new Error(e.error ?? `HTTP ${r.status}`);
      }
      const { entries: list } = (await r.json()) as { entries: Entry[] };
      setEntries(list);
    } catch (e: any) {
      setErr(String(e?.message ?? e));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  // When date changes, prefill form with that day's existing entry if any.
  useEffect(() => {
    const existing = entries.find((e) => e.entry_date === entryDate);
    if (existing) {
      setCondition(existing.condition);
      setNotes(existing.notes ?? '');
      setPhotoUrl(existing.photo_url ?? '');
    }
  }, [entryDate, entries]);

  async function save() {
    setSaving(true);
    setErr(null);
    try {
      const headers = await authHeader();
      const r = await fetch('/api/journal', {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...headers },
        body: JSON.stringify({
          entryDate,
          condition,
          notes: notes.trim() || undefined,
          photoUrl: photoUrl.trim() || undefined,
        }),
      });
      if (!r.ok) {
        const e = await r.json().catch(() => ({}));
        throw new Error(e.error ?? `HTTP ${r.status}`);
      }
      await load();
    } catch (e: any) {
      setErr(String(e?.message ?? e));
    } finally {
      setSaving(false);
    }
  }

  async function remove(id: string) {
    if (!confirm('Delete this entry?')) return;
    try {
      const headers = await authHeader();
      const r = await fetch(`/api/journal?id=${encodeURIComponent(id)}`, {
        method: 'DELETE',
        headers,
      });
      if (!r.ok) {
        const e = await r.json().catch(() => ({}));
        throw new Error(e.error ?? `HTTP ${r.status}`);
      }
      await load();
    } catch (e: any) {
      setErr(String(e?.message ?? e));
    }
  }

  async function analyze() {
    setAnalyzeLoading(true);
    setAnalyzeErr(null);
    setAnalysis(null);
    try {
      const headers = await authHeader();
      const r = await fetch('/api/journal?action=analyze', {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...headers },
      });
      if (!r.ok) {
        const e = await r.json().catch(() => ({}));
        throw new Error(e.error ?? `HTTP ${r.status}`);
      }
      const { result } = (await r.json()) as { result: AnalyzeResult };
      setAnalysis(result);
    } catch (e: any) {
      setAnalyzeErr(String(e?.message ?? e));
    } finally {
      setAnalyzeLoading(false);
    }
  }

  const recent = entries.slice(0, 30);

  return (
    <div className="max-w-4xl">
      <div className="mb-6 flex items-center gap-3">
        <BookOpen size={28} />
        <div>
          <h1 className="font-display text-4xl">Skin Journal</h1>
          <p className="text-muted text-sm mt-1">
            Log how your skin looks each day. AI correlates condition changes with product introductions over time.
          </p>
        </div>
      </div>

      {err && <div className="card p-3 mb-4 bg-bad-bg text-bad-fg text-sm">{err}</div>}

      <div className="card p-6 mb-6">
        <div className="flex items-center gap-2 mb-4">
          <Calendar size={18} />
          <span className="font-display text-xl">Today's entry</span>
        </div>

        <div className="grid sm:grid-cols-2 gap-4">
          <div>
            <label className="label">Date</label>
            <input
              type="date"
              className="input"
              value={entryDate}
              max={todayISO()}
              onChange={(e) => setEntryDate(e.target.value)}
            />
          </div>
          <div>
            <label className="label">Photo URL (optional)</label>
            <input
              type="url"
              className="input"
              placeholder="https://…"
              value={photoUrl}
              onChange={(e) => setPhotoUrl(e.target.value)}
            />
          </div>
        </div>

        <div className="mt-4">
          <label className="label">Condition</label>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            {(Object.keys(CONDITION_META) as Condition[]).map((c) => {
              const meta = CONDITION_META[c];
              const selected = condition === c;
              return (
                <button
                  key={c}
                  type="button"
                  onClick={() => setCondition(c)}
                  className={`rounded-lg px-3 py-3 text-sm font-medium ${meta.bg} ${meta.fg} ${
                    selected ? `ring-2 ${meta.ring}` : 'opacity-70 hover:opacity-100'
                  }`}
                >
                  {meta.label}
                </button>
              );
            })}
          </div>
        </div>

        <div className="mt-4">
          <label className="label">Notes</label>
          <textarea
            className="input min-h-24"
            placeholder="What did you notice? New products, stress, diet, sleep…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            maxLength={2000}
          />
        </div>

        <div className="mt-4">
          <button className="btn-primary" onClick={save} disabled={saving}>
            {saving ? <Loader2 size={16} className="animate-spin" /> : <BookOpen size={16} />}
            {saving ? 'Saving…' : 'Save entry'}
          </button>
        </div>
      </div>

      <div className="card p-6 mb-6">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <Calendar size={18} />
            <span className="font-display text-xl">Recent entries</span>
          </div>
          <span className="text-xs text-muted">{recent.length} of last 90</span>
        </div>

        {loading && <div className="text-sm text-muted">Loading…</div>}
        {!loading && recent.length === 0 && (
          <div className="text-sm text-muted">No entries yet. Log your first day above.</div>
        )}

        {!loading && recent.length > 0 && (
          <ul className="space-y-2">
            {recent.map((e) => {
              const meta = CONDITION_META[e.condition];
              return (
                <li
                  key={e.id}
                  className="flex items-start gap-3 border-b border-card pb-2 last:border-0 last:pb-0"
                >
                  <button
                    type="button"
                    onClick={() => setEntryDate(e.entry_date)}
                    className="font-mono text-xs text-muted w-24 shrink-0 text-left hover:underline"
                    title="Load into form"
                  >
                    {e.entry_date}
                  </button>
                  <span
                    className={`text-xs px-2 py-0.5 rounded ${meta.bg} ${meta.fg} font-medium shrink-0`}
                  >
                    {meta.label}
                  </span>
                  <div className="flex-1 text-sm">
                    {e.notes && <div className="text-ink">{e.notes}</div>}
                    {e.photo_url && (
                      <a
                        href={e.photo_url}
                        target="_blank"
                        rel="noreferrer"
                        className="text-xs text-muted underline"
                      >
                        photo
                      </a>
                    )}
                  </div>
                  <button
                    type="button"
                    className="text-muted hover:text-bad-fg"
                    onClick={() => remove(e.id)}
                    aria-label="Delete entry"
                  >
                    <Trash2 size={16} />
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <div className="card p-6">
        <div className="flex items-center gap-2 mb-3">
          <Sparkles size={18} />
          <span className="font-display text-xl">Analyze patterns</span>
        </div>
        <p className="text-sm text-muted mb-3">
          Pro feature. Claude cross-references your journal with product introduction dates and ingredients to flag likely culprits.
        </p>
        <button
          className="btn-primary"
          onClick={analyze}
          disabled={analyzeLoading || entries.length === 0}
        >
          {analyzeLoading ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
          {analyzeLoading ? 'Analyzing…' : analysis ? 'Re-run analysis' : 'Analyze patterns'}
        </button>
        {analyzeErr && <p className="text-sm text-bad-fg mt-2">Analysis failed: {analyzeErr}</p>}

        {analysis && (
          <div className="mt-5 space-y-5">
            <div>
              <div className="font-display text-lg mb-1">Summary</div>
              <p className="text-sm">{analysis.summary}</p>
            </div>

            {analysis.suspects.length > 0 && (
              <div>
                <div className="font-display text-lg mb-2">Likely culprits</div>
                <ul className="space-y-2">
                  {analysis.suspects.map((s, i) => (
                    <li
                      key={i}
                      className="border-l-2 pl-3 py-1"
                      style={{
                        borderColor:
                          s.confidence === 'high'
                            ? '#B22B2B'
                            : s.confidence === 'medium'
                            ? '#8B6914'
                            : '#6B6760',
                      }}
                    >
                      <div className="flex items-center justify-between">
                        <span className="font-mono text-sm">{s.productOrIngredient}</span>
                        <span className="text-xs text-muted uppercase">{s.confidence}</span>
                      </div>
                      <p className="text-xs text-muted mt-1">{s.reasoning}</p>
                      {s.evidenceDates.length > 0 && (
                        <p className="text-xs text-muted mt-1 font-mono">
                          dates: {s.evidenceDates.join(', ')}
                        </p>
                      )}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {analysis.patterns.length > 0 && (
              <div>
                <div className="font-display text-lg mb-2">Patterns</div>
                <ul className="list-disc list-inside text-sm space-y-1">
                  {analysis.patterns.map((p, i) => (
                    <li key={i}>{p}</li>
                  ))}
                </ul>
              </div>
            )}

            {analysis.recommendations.length > 0 && (
              <div>
                <div className="font-display text-lg mb-2">Recommendations</div>
                <ul className="list-disc list-inside text-sm space-y-1">
                  {analysis.recommendations.map((p, i) => (
                    <li key={i}>{p}</li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
