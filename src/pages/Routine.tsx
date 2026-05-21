import { useMemo, useState } from 'react';
import { Sun, Moon, AlertTriangle, CheckCircle2, Sparkles, Loader2 } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { supabase } from '@/lib/supabase';

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

function verdictClass(v: Verdict): string {
  if (v === 'good') return 'bg-good-bg text-good-fg';
  if (v === 'caution') return 'bg-unsure-bg text-unsure-fg';
  return 'bg-bad-bg text-bad-fg';
}

function severityColor(s: Severity): string {
  if (s === 'high') return '#B22B2B';
  if (s === 'medium') return '#8B6914';
  return '#6B6760';
}

export default function Routine() {
  const { products, loading } = useProducts();
  const [amIds, setAmIds] = useState<string[]>([]);
  const [pmIds, setPmIds] = useState<string[]>([]);
  const [result, setResult] = useState<RoutineResult | null>(null);
  const [running, setRunning] = useState(false);
  const [err, setErr] = useState<string | null>(null);

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

  async function analyze() {
    if (amIds.length === 0 && pmIds.length === 0) return;
    setRunning(true);
    setErr(null);
    setResult(null);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const r = await fetch('/api/analyze-routine', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${session?.access_token ?? ''}`,
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

  const canAnalyze = (amIds.length > 0 || pmIds.length > 0) && !running;

  return (
    <div className="max-w-5xl">
      <div className="mb-6">
        <h1 className="font-display text-4xl">Routine</h1>
        <p className="text-muted text-sm mt-1">
          Build your AM and PM stacks from your tagged products. Claude checks for ingredient conflicts, redundancies, and layering issues.
        </p>
      </div>

      {loading ? (
        <div className="card p-6 flex items-center gap-2 text-muted">
          <Loader2 size={16} className="animate-spin" /> Loading products…
        </div>
      ) : products.length === 0 ? (
        <div className="card p-6 text-muted text-sm">
          You haven't added any products yet. Add products first, then come back to build a routine.
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <RoutineColumn
              title="AM Routine"
              icon={<Sun size={18} />}
              ids={amIds}
              labelFor={labelFor}
              onMove={(id, dir) => move(amIds, setAmIds, id, dir)}
              onRemove={(id) => toggle(amIds, setAmIds, id)}
            />
            <RoutineColumn
              title="PM Routine"
              icon={<Moon size={18} />}
              ids={pmIds}
              labelFor={labelFor}
              onMove={(id, dir) => move(pmIds, setPmIds, id, dir)}
              onRemove={(id) => toggle(pmIds, setPmIds, id)}
            />
          </div>

          <div className="card p-6 mb-6">
            <div className="flex items-center justify-between mb-3">
              <span className="font-display text-xl">Product library</span>
              <span className="text-xs text-muted">{products.length} tagged</span>
            </div>
            <ul className="space-y-2">
              {products.map((p) => {
                const inAm = amIds.includes(p.id);
                const inPm = pmIds.includes(p.id);
                const label = [p.brand, p.product_name].filter(Boolean).join(' ') || p.product_name;
                return (
                  <li
                    key={p.id}
                    className="flex items-center justify-between bg-card rounded-lg px-4 py-2"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="text-sm truncate">{label}</div>
                      {p.category && <div className="text-xs text-muted">{p.category}</div>}
                    </div>
                    <div className="flex gap-2 shrink-0 ml-3">
                      <button
                        className={inAm ? 'btn-ghost' : 'btn-primary'}
                        onClick={() => toggle(amIds, setAmIds, p.id)}
                      >
                        <Sun size={14} /> {inAm ? 'Remove AM' : '+ AM'}
                      </button>
                      <button
                        className={inPm ? 'btn-ghost' : 'btn-primary'}
                        onClick={() => toggle(pmIds, setPmIds, p.id)}
                      >
                        <Moon size={14} /> {inPm ? 'Remove PM' : '+ PM'}
                      </button>
                    </div>
                  </li>
                );
              })}
            </ul>
          </div>

          <div className="mb-6">
            <button className="btn-primary" disabled={!canAnalyze} onClick={analyze}>
              {running ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
              {running ? 'Analyzing…' : 'Analyze routine'}
            </button>
            {err && <p className="text-sm text-bad-fg mt-2">Analysis failed: {err}</p>}
          </div>
        </>
      )}

      {result && (
        <div className="space-y-4">
          <div className="card p-6">
            <div className="flex items-center gap-2 mb-3">
              <Sparkles size={18} />
              <span className="font-display text-xl">Routine verdict</span>
            </div>
            <div className="flex gap-3 flex-wrap">
              <span className={`text-xs font-mono px-3 py-1 rounded ${verdictClass(result.amVerdict)}`}>
                AM · {result.amVerdict.toUpperCase()}
              </span>
              <span className={`text-xs font-mono px-3 py-1 rounded ${verdictClass(result.pmVerdict)}`}>
                PM · {result.pmVerdict.toUpperCase()}
              </span>
            </div>
          </div>

          {result.conflicts.length > 0 ? (
            <div className="card p-6">
              <div className="flex items-center gap-2 mb-3">
                <AlertTriangle size={18} />
                <span className="font-display text-xl">
                  {result.conflicts.length} conflict{result.conflicts.length === 1 ? '' : 's'}
                </span>
              </div>
              <ul className="space-y-3">
                {result.conflicts.map((c, i) => (
                  <li
                    key={i}
                    className="border-l-4 pl-4 py-2"
                    style={{ borderColor: severityColor(c.severity) }}
                  >
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs font-mono text-muted">
                        {c.products.join(' + ')}
                      </span>
                      <span className="text-xs font-mono text-muted">{c.severity.toUpperCase()}</span>
                    </div>
                    <p className="text-sm">{c.issue}</p>
                    <p className="text-xs text-muted mt-1"><strong>Fix:</strong> {c.fix}</p>
                  </li>
                ))}
              </ul>
            </div>
          ) : (
            <div className="card p-6 bg-good-bg text-good-fg flex items-start gap-3">
              <CheckCircle2 size={20} className="shrink-0 mt-0.5" />
              <div>
                <div className="font-display text-lg mb-1">No conflicts detected</div>
                <p className="text-sm">Your routine looks well-layered.</p>
              </div>
            </div>
          )}

          {result.redundancies.length > 0 && (
            <div className="card p-6">
              <span className="font-display text-xl block mb-2">Redundancies</span>
              <ul className="list-disc list-inside text-sm space-y-1">
                {result.redundancies.map((r, i) => (
                  <li key={i}>{r}</li>
                ))}
              </ul>
            </div>
          )}

          {result.suggestions.length > 0 && (
            <div className="card p-6">
              <span className="font-display text-xl block mb-2">Suggestions</span>
              <ul className="list-disc list-inside text-sm space-y-1">
                {result.suggestions.map((s, i) => (
                  <li key={i}>{s}</li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function RoutineColumn(props: {
  title: string;
  icon: React.ReactNode;
  ids: string[];
  labelFor: (id: string) => string;
  onMove: (id: string, dir: -1 | 1) => void;
  onRemove: (id: string) => void;
}) {
  const { title, icon, ids, labelFor, onMove, onRemove } = props;
  return (
    <div className="card p-6">
      <div className="flex items-center gap-2 mb-3">
        {icon}
        <span className="font-display text-xl">{title}</span>
        <span className="text-xs text-muted ml-auto">{ids.length} step{ids.length === 1 ? '' : 's'}</span>
      </div>
      {ids.length === 0 ? (
        <p className="text-xs text-muted">Add products from the library below.</p>
      ) : (
        <ol className="space-y-2">
          {ids.map((id, i) => (
            <li
              key={id}
              className="flex items-center gap-2 bg-card rounded-lg px-3 py-2"
            >
              <span className="text-xs text-muted font-mono w-6">{i + 1}.</span>
              <span className="text-sm flex-1 truncate">{labelFor(id)}</span>
              <button
                className="btn-ghost"
                onClick={() => onMove(id, -1)}
                disabled={i === 0}
                aria-label="Move up"
              >
                ↑
              </button>
              <button
                className="btn-ghost"
                onClick={() => onMove(id, 1)}
                disabled={i === ids.length - 1}
                aria-label="Move down"
              >
                ↓
              </button>
              <button className="btn-ghost" onClick={() => onRemove(id)} aria-label="Remove">
                ✕
              </button>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
