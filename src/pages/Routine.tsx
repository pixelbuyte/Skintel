import { useEffect, useMemo, useState } from 'react';
import {
  Sun,
  Moon,
  AlertTriangle,
  CheckCircle2,
  Sparkles,
  Loader2,
  Plus,
  Trash2,
  ArrowUp,
  ArrowDown,
  Clock,
  Save,
  Copy,
  Wand2,
  Layers,
} from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { supabase } from '@/lib/supabase';
import { isPreview } from '@/lib/preview';

type Verdict = 'good' | 'caution' | 'avoid';
type Severity = 'high' | 'medium' | 'low';

type Conflict = {
  products: string[];
  issue: string;
  severity: Severity;
  fix: string;
};

type RoutineResult = {
  amVerdict: Verdict;
  pmVerdict: Verdict;
  conflicts: Conflict[];
  redundancies: string[];
  suggestions: string[];
};

type Template = {
  id: string;
  name: string;
  blurb: string;
  am: string[]; // category tags to auto-fill from library
  pm: string[];
};

const TEMPLATES: Template[] = [
  {
    id: 'beginner',
    name: 'Beginner Barrier Repair',
    blurb: 'Gentle 3-step. Cleanser → moisturizer → SPF.',
    am: ['cleanser', 'moisturizer', 'sunscreen'],
    pm: ['cleanser', 'moisturizer'],
  },
  {
    id: 'antiaging',
    name: 'Anti-Aging Stack',
    blurb: 'Vitamin C AM, retinol PM, peptide layering.',
    am: ['cleanser', 'serum', 'moisturizer', 'sunscreen'],
    pm: ['cleanser', 'toner', 'serum', 'moisturizer'],
  },
  {
    id: 'acne',
    name: 'Acne-Prone Minimal',
    blurb: 'Fewer actives, more barrier. BHA only PM.',
    am: ['cleanser', 'moisturizer', 'sunscreen'],
    pm: ['cleanser', 'exfoliant', 'moisturizer'],
  },
  {
    id: 'sensitive',
    name: 'Reactive / Sensitive',
    blurb: 'Strip actives. Cream cleanser, ceramides, mineral SPF.',
    am: ['cleanser', 'moisturizer', 'sunscreen'],
    pm: ['cleanser', 'moisturizer'],
  },
  {
    id: 'glow',
    name: 'Glass Skin Glow',
    blurb: 'Hydration heavy. Niacinamide, HA, occlusive PM.',
    am: ['cleanser', 'toner', 'serum', 'moisturizer', 'sunscreen'],
    pm: ['cleanser', 'toner', 'serum', 'moisturizer'],
  },
];

const STORAGE_KEY = 'skintel:routine:v1';

function verdictTone(v: Verdict): { tint: string; label: string } {
  if (v === 'good') return { tint: 'bg-good-bg text-good-fg border-good-fg/30', label: 'CLEAN' };
  if (v === 'caution') return { tint: 'bg-unsure-bg text-unsure-fg border-unsure-fg/30', label: 'CAUTION' };
  return { tint: 'bg-bad-bg text-bad-fg border-bad-fg/30', label: 'AVOID' };
}

function severityColor(s: Severity): string {
  if (s === 'high') return '#B22B2B';
  if (s === 'medium') return '#8B6914';
  return '#6B6760';
}

function severityBg(s: Severity): string {
  if (s === 'high') return 'bg-bad-bg/60';
  if (s === 'medium') return 'bg-unsure-bg/60';
  return 'bg-card';
}

const MOCK_RESULT: RoutineResult = {
  amVerdict: 'caution',
  pmVerdict: 'good',
  conflicts: [
    {
      products: ['Vitamin C Serum', 'Niacinamide 10%'],
      issue: 'High-strength Vitamin C plus niacinamide can flush and reduce efficacy on sensitive skin.',
      severity: 'medium',
      fix: 'Move niacinamide to PM, keep Vitamin C in AM only.',
    },
    {
      products: ['Retinol 0.5%', 'Glycolic Toner'],
      issue: 'Layering retinoid with glycolic acid raises irritation risk on barrier.',
      severity: 'high',
      fix: 'Alternate nights, or drop the glycolic to 2x/week.',
    },
  ],
  redundancies: [
    'Two products both contain niacinamide at >5% — diminishing returns past 10% daily exposure.',
  ],
  suggestions: [
    'Add a mineral SPF 30+ to AM to protect the active layering.',
    'Consider a barrier cream PM after retinol nights.',
    'Hyaluronic acid layered under occlusive will lock in more hydration.',
  ],
};

export default function Routine() {
  const { products, loading } = useProducts();
  const [amIds, setAmIds] = useState<string[]>([]);
  const [pmIds, setPmIds] = useState<string[]>([]);
  const [result, setResult] = useState<RoutineResult | null>(null);
  const [running, setRunning] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [routineName, setRoutineName] = useState('My routine');
  const [saved, setSaved] = useState(false);
  const [copied, setCopied] = useState(false);
  const preview = isPreview();

  // Restore from local cache.
  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const obj = JSON.parse(raw) as { am: string[]; pm: string[]; name?: string };
        if (Array.isArray(obj.am)) setAmIds(obj.am);
        if (Array.isArray(obj.pm)) setPmIds(obj.pm);
        if (obj.name) setRoutineName(obj.name);
      }
    } catch {}
  }, []);

  const productMap = useMemo(() => {
    const m = new Map<string, (typeof products)[number]>();
    for (const p of products) m.set(p.id, p);
    return m;
  }, [products]);

  function toggle(list: string[], setList: (v: string[]) => void, id: string) {
    if (list.includes(id)) setList(list.filter((x) => x !== id));
    else setList([...list, id]);
  }

  function move(list: string[], setList: (v: string[]) => void, id: string, dir: -1 | 1) {
    const idx = list.indexOf(id);
    if (idx < 0) return;
    const next = idx + dir;
    if (next < 0 || next >= list.length) return;
    const copy = list.slice();
    [copy[idx], copy[next]] = [copy[next], copy[idx]];
    setList(copy);
  }

  function labelFor(id: string): string {
    const p = productMap.get(id);
    if (!p) return id;
    return [p.brand, p.product_name].filter(Boolean).join(' ') || p.product_name;
  }

  function clearAll() {
    setAmIds([]);
    setPmIds([]);
    setResult(null);
  }

  function applyTemplate(t: Template) {
    const byCat = new Map<string, string[]>();
    for (const p of products) {
      const cat = (p.category ?? '').toLowerCase();
      if (!cat) continue;
      const arr = byCat.get(cat) ?? [];
      arr.push(p.id);
      byCat.set(cat, arr);
    }
    const pick = (cats: string[]): string[] => {
      const out: string[] = [];
      for (const c of cats) {
        const ids = byCat.get(c);
        if (ids && ids.length > 0) out.push(ids[0]);
      }
      return out;
    };
    setAmIds(pick(t.am));
    setPmIds(pick(t.pm));
    setResult(null);
  }

  function saveLocal() {
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({ am: amIds, pm: pmIds, name: routineName, savedAt: Date.now() }),
      );
      setSaved(true);
      setTimeout(() => setSaved(false), 1800);
    } catch {}
  }

  function copyShare() {
    const lines: string[] = [`${routineName} · via Skintel`, ''];
    lines.push('☀️ AM');
    amIds.forEach((id, i) => lines.push(`  ${i + 1}. ${labelFor(id)}`));
    lines.push('');
    lines.push('🌙 PM');
    pmIds.forEach((id, i) => lines.push(`  ${i + 1}. ${labelFor(id)}`));
    try {
      navigator.clipboard.writeText(lines.join('\n'));
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {}
  }

  async function analyze() {
    if (amIds.length === 0 && pmIds.length === 0) return;
    setRunning(true);
    setErr(null);
    setResult(null);

    if (preview) {
      setTimeout(() => {
        setResult(MOCK_RESULT);
        setRunning(false);
      }, 700);
      return;
    }

    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session?.access_token) {
        setErr('Sign in to analyze your routine.');
        setRunning(false);
        return;
      }
      const r = await fetch('/api/analyze-routine', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({ amProductIds: amIds, pmProductIds: pmIds }),
      });
      if (!r.ok) {
        const e = await r.json().catch(() => ({}));
        throw new Error(e.error ?? `HTTP ${r.status}`);
      }
      const { result: data } = (await r.json()) as { result: RoutineResult };
      setResult(data);
    } catch (e: any) {
      setErr(String(e?.message ?? e));
    } finally {
      setRunning(false);
    }
  }

  const totalSteps = amIds.length + pmIds.length;
  const estMinutes = Math.max(1, Math.round(totalSteps * 0.6));
  const canAnalyze = totalSteps > 0 && !running;

  return (
    <div className="max-w-6xl">
      {/* HERO */}
      <header className="mb-8 relative">
        <div className="absolute -inset-x-4 -top-4 h-32 bg-gradient-to-br from-amber-50/40 via-cream to-indigo-50/30 blur-3xl -z-10" />
        <div className="flex items-baseline gap-3 flex-wrap">
          <h1 className="font-display text-5xl tracking-tight">Routine</h1>
          <span className="font-display italic text-3xl text-muted/70">studio</span>
        </div>
        <p className="text-muted text-sm mt-2 max-w-xl">
          Layer your products. Skintel checks order, ingredient conflicts, redundancy, and AM/PM clashes.
        </p>
      </header>

      {/* TEMPLATES */}
      {!loading && products.length > 0 && (
        <section className="mb-6">
          <div className="flex items-center gap-2 mb-3">
            <Wand2 size={16} className="text-muted" />
            <span className="text-xs uppercase tracking-[0.18em] text-muted">Quick start</span>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-2">
            {TEMPLATES.map((t) => (
              <button
                key={t.id}
                onClick={() => applyTemplate(t)}
                className="text-left rounded-xl border border-border bg-card/60 hover:bg-card hover:border-ink/30 transition-all p-3 active:scale-[0.98]"
              >
                <div className="text-sm font-medium leading-tight">{t.name}</div>
                <div className="text-[11px] text-muted mt-1 leading-snug">{t.blurb}</div>
              </button>
            ))}
          </div>
        </section>
      )}

      {loading ? (
        <div className="card p-6 flex items-center gap-2 text-muted">
          <Loader2 size={16} className="animate-spin" /> Loading products…
        </div>
      ) : products.length === 0 ? (
        <div className="card p-8 text-center">
          <Layers size={32} className="mx-auto text-muted mb-3" />
          <div className="font-display text-2xl mb-1">No products yet</div>
          <p className="text-sm text-muted max-w-md mx-auto">
            Add a few products first — paste an INCI, scan a barcode, or snap a label. Then come back and stack them.
          </p>
        </div>
      ) : (
        <>
          {/* ROUTINE BAR */}
          <section className="mb-4 flex items-center gap-3 flex-wrap">
            <input
              type="text"
              value={routineName}
              onChange={(e) => setRoutineName(e.target.value)}
              className="bg-transparent border-b border-border/60 focus:border-ink outline-none font-display text-xl px-1 py-0.5 min-w-[180px]"
            />
            <div className="flex items-center gap-1 text-xs text-muted">
              <Clock size={12} />
              <span>{totalSteps} steps · ~{estMinutes} min</span>
            </div>
            <div className="ml-auto flex gap-2">
              <button
                onClick={saveLocal}
                disabled={totalSteps === 0}
                className="btn-ghost"
                title="Save locally"
              >
                <Save size={14} /> {saved ? 'Saved ✓' : 'Save'}
              </button>
              <button
                onClick={copyShare}
                disabled={totalSteps === 0}
                className="btn-ghost"
                title="Copy to clipboard"
              >
                <Copy size={14} /> {copied ? 'Copied ✓' : 'Copy'}
              </button>
              <button
                onClick={clearAll}
                disabled={totalSteps === 0}
                className="btn-ghost text-bad-fg/80"
              >
                <Trash2 size={14} /> Clear
              </button>
            </div>
          </section>

          {/* AM / PM COLUMNS */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <RoutineColumn
              kind="am"
              ids={amIds}
              labelFor={labelFor}
              category={(id) => productMap.get(id)?.category ?? null}
              onMove={(id, dir) => move(amIds, setAmIds, id, dir)}
              onRemove={(id) => toggle(amIds, setAmIds, id)}
            />
            <RoutineColumn
              kind="pm"
              ids={pmIds}
              labelFor={labelFor}
              category={(id) => productMap.get(id)?.category ?? null}
              onMove={(id, dir) => move(pmIds, setPmIds, id, dir)}
              onRemove={(id) => toggle(pmIds, setPmIds, id)}
            />
          </div>

          {/* LIBRARY */}
          <section className="card p-5 mb-6">
            <div className="flex items-center justify-between mb-3">
              <span className="font-display text-xl">Library</span>
              <span className="text-xs text-muted">{products.length} tagged</span>
            </div>
            <ul className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {products.map((p) => {
                const inAm = amIds.includes(p.id);
                const inPm = pmIds.includes(p.id);
                const label = [p.brand, p.product_name].filter(Boolean).join(' ') || p.product_name;
                return (
                  <li
                    key={p.id}
                    className="flex items-center gap-2 bg-card/60 hover:bg-card transition-colors rounded-xl px-3 py-2 border border-transparent hover:border-border"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="text-sm truncate font-medium">{label}</div>
                      {p.category && (
                        <div className="text-[11px] text-muted font-mono uppercase tracking-wide">
                          {p.category}
                        </div>
                      )}
                    </div>
                    <button
                      onClick={() => toggle(amIds, setAmIds, p.id)}
                      className={`inline-flex items-center justify-center size-8 rounded-lg border transition-colors ${
                        inAm
                          ? 'bg-amber-100 border-amber-300 text-amber-700'
                          : 'border-border text-muted hover:border-amber-300 hover:text-amber-600'
                      }`}
                      aria-label={inAm ? 'Remove from AM' : 'Add to AM'}
                      title={inAm ? 'In AM — click to remove' : 'Add to AM'}
                    >
                      <Sun size={14} />
                    </button>
                    <button
                      onClick={() => toggle(pmIds, setPmIds, p.id)}
                      className={`inline-flex items-center justify-center size-8 rounded-lg border transition-colors ${
                        inPm
                          ? 'bg-indigo-100 border-indigo-300 text-indigo-700'
                          : 'border-border text-muted hover:border-indigo-300 hover:text-indigo-600'
                      }`}
                      aria-label={inPm ? 'Remove from PM' : 'Add to PM'}
                      title={inPm ? 'In PM — click to remove' : 'Add to PM'}
                    >
                      <Moon size={14} />
                    </button>
                  </li>
                );
              })}
            </ul>
          </section>

          {/* ANALYZE BAR */}
          <div className="mb-6 flex items-center gap-3 flex-wrap">
            <button className="btn-primary" disabled={!canAnalyze} onClick={analyze}>
              {running ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
              {running ? 'Analyzing…' : 'Analyze routine'}
            </button>
            {preview && (
              <span className="text-[11px] uppercase tracking-wider text-muted">
                preview · mock analysis
              </span>
            )}
            {err && (
              <p className="text-sm text-bad-fg">
                {err}
              </p>
            )}
          </div>
        </>
      )}

      {/* RESULTS */}
      {result && (
        <div className="space-y-4 animate-in fade-in duration-500">
          {/* Verdict header */}
          <div className="card p-6">
            <div className="flex items-center gap-2 mb-4">
              <Sparkles size={18} />
              <span className="font-display text-2xl">Verdict</span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <VerdictPanel kind="am" verdict={result.amVerdict} steps={amIds.length} />
              <VerdictPanel kind="pm" verdict={result.pmVerdict} steps={pmIds.length} />
            </div>
          </div>

          {/* Conflict heatmap */}
          {result.conflicts.length > 0 ? (
            <div className="card p-6">
              <div className="flex items-center gap-2 mb-4">
                <AlertTriangle size={18} className="text-bad-fg" />
                <span className="font-display text-xl">
                  {result.conflicts.length} conflict{result.conflicts.length === 1 ? '' : 's'}
                </span>
                <span className="ml-auto text-[11px] uppercase tracking-wider text-muted">
                  severity
                </span>
              </div>
              <ul className="space-y-2">
                {result.conflicts.map((c, i) => (
                  <li
                    key={i}
                    className={`rounded-xl border-l-4 pl-4 pr-4 py-3 ${severityBg(c.severity)}`}
                    style={{ borderColor: severityColor(c.severity) }}
                  >
                    <div className="flex items-center justify-between gap-3 mb-1 flex-wrap">
                      <span className="text-xs font-mono text-muted">
                        {c.products.join(' + ')}
                      </span>
                      <span
                        className="text-[10px] font-mono uppercase tracking-wider px-2 py-0.5 rounded-full border"
                        style={{ borderColor: severityColor(c.severity), color: severityColor(c.severity) }}
                      >
                        {c.severity}
                      </span>
                    </div>
                    <p className="text-sm">{c.issue}</p>
                    <p className="text-xs text-muted mt-1.5">
                      <strong className="text-ink/80">Fix:</strong> {c.fix}
                    </p>
                  </li>
                ))}
              </ul>
            </div>
          ) : (
            <div className="card p-6 bg-good-bg/60 flex items-start gap-3">
              <CheckCircle2 size={22} className="shrink-0 mt-0.5 text-good-fg" />
              <div>
                <div className="font-display text-xl mb-1">No conflicts</div>
                <p className="text-sm text-muted">Your stack layers cleanly. Ship it.</p>
              </div>
            </div>
          )}

          {result.redundancies.length > 0 && (
            <div className="card p-6">
              <div className="flex items-center gap-2 mb-3">
                <Layers size={16} className="text-muted" />
                <span className="font-display text-xl">Redundancies</span>
              </div>
              <ul className="space-y-1.5">
                {result.redundancies.map((r, i) => (
                  <li key={i} className="text-sm flex gap-2">
                    <span className="text-muted">·</span>
                    <span>{r}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {result.suggestions.length > 0 && (
            <div className="card p-6">
              <div className="flex items-center gap-2 mb-3">
                <Sparkles size={16} className="text-muted" />
                <span className="font-display text-xl">Suggestions</span>
              </div>
              <ul className="space-y-2">
                {result.suggestions.map((s, i) => (
                  <li
                    key={i}
                    className="text-sm flex gap-3 items-start rounded-lg bg-card/60 px-3 py-2"
                  >
                    <Plus size={14} className="text-muted mt-0.5 shrink-0" />
                    <span>{s}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function VerdictPanel({ kind, verdict, steps }: { kind: 'am' | 'pm'; verdict: Verdict; steps: number }) {
  const tone = verdictTone(verdict);
  const isAm = kind === 'am';
  return (
    <div
      className={`rounded-2xl p-4 border ${tone.tint} relative overflow-hidden`}
    >
      <div
        className={`absolute -right-6 -top-6 size-24 rounded-full opacity-30 blur-xl ${
          isAm ? 'bg-amber-200' : 'bg-indigo-300'
        }`}
      />
      <div className="relative">
        <div className="flex items-center gap-2 mb-2">
          {isAm ? <Sun size={16} /> : <Moon size={16} />}
          <span className="font-mono text-xs uppercase tracking-wider">{isAm ? 'Morning' : 'Evening'}</span>
        </div>
        <div className="font-display text-3xl tracking-tight">{tone.label}</div>
        <div className="text-[11px] text-muted mt-1">{steps} step{steps === 1 ? '' : 's'}</div>
      </div>
    </div>
  );
}

function RoutineColumn(props: {
  kind: 'am' | 'pm';
  ids: string[];
  labelFor: (id: string) => string;
  category: (id: string) => string | null;
  onMove: (id: string, dir: -1 | 1) => void;
  onRemove: (id: string) => void;
}) {
  const { kind, ids, labelFor, category, onMove, onRemove } = props;
  const isAm = kind === 'am';
  return (
    <div
      className={`card p-5 relative overflow-hidden ${
        isAm ? 'bg-gradient-to-br from-amber-50/60 to-card' : 'bg-gradient-to-br from-indigo-50/40 to-card'
      }`}
    >
      <div
        className={`absolute -right-8 -top-8 size-32 rounded-full opacity-25 blur-2xl ${
          isAm ? 'bg-amber-200' : 'bg-indigo-300'
        }`}
      />
      <div className="relative">
        <div className="flex items-center gap-2 mb-4">
          <div
            className={`size-9 rounded-xl flex items-center justify-center ${
              isAm ? 'bg-amber-100 text-amber-700' : 'bg-indigo-100 text-indigo-700'
            }`}
          >
            {isAm ? <Sun size={18} /> : <Moon size={18} />}
          </div>
          <div>
            <div className="font-display text-xl leading-none">{isAm ? 'AM' : 'PM'}</div>
            <div className="text-[11px] text-muted">{ids.length} step{ids.length === 1 ? '' : 's'}</div>
          </div>
        </div>

        {ids.length === 0 ? (
          <p className="text-xs text-muted italic py-4">
            Tap {isAm ? <Sun size={11} className="inline align-text-bottom" /> : <Moon size={11} className="inline align-text-bottom" />} on a library product to add it.
          </p>
        ) : (
          <ol className="space-y-1.5 relative">
            {/* connecting spine */}
            <div className="absolute left-[14px] top-3 bottom-3 w-px bg-border/50" aria-hidden />
            {ids.map((id, i) => {
              const cat = category(id);
              return (
                <li
                  key={id}
                  className="flex items-center gap-2 bg-cream/80 rounded-xl px-2 py-2 relative"
                >
                  <span
                    className={`relative z-10 size-7 rounded-full flex items-center justify-center text-[11px] font-mono ${
                      isAm ? 'bg-amber-100 text-amber-800' : 'bg-indigo-100 text-indigo-800'
                    } border border-border/50`}
                  >
                    {i + 1}
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="text-sm truncate">{labelFor(id)}</div>
                    {cat && (
                      <div className="text-[10px] text-muted font-mono uppercase tracking-wide">{cat}</div>
                    )}
                  </div>
                  <div className="flex shrink-0 items-center gap-0.5">
                    <button
                      className="size-7 rounded-md hover:bg-card text-muted hover:text-ink disabled:opacity-30 inline-flex items-center justify-center"
                      onClick={() => onMove(id, -1)}
                      disabled={i === 0}
                      aria-label="Move up"
                    >
                      <ArrowUp size={13} />
                    </button>
                    <button
                      className="size-7 rounded-md hover:bg-card text-muted hover:text-ink disabled:opacity-30 inline-flex items-center justify-center"
                      onClick={() => onMove(id, 1)}
                      disabled={i === ids.length - 1}
                      aria-label="Move down"
                    >
                      <ArrowDown size={13} />
                    </button>
                    <button
                      className="size-7 rounded-md hover:bg-bad-bg text-muted hover:text-bad-fg inline-flex items-center justify-center"
                      onClick={() => onRemove(id)}
                      aria-label="Remove"
                    >
                      <Trash2 size={12} />
                    </button>
                  </div>
                </li>
              );
            })}
          </ol>
        )}
      </div>
    </div>
  );
}
