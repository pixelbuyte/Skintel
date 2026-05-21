import { useMemo, useState } from 'react';
import { ScanLine, CheckCircle2, AlertTriangle, Sparkles, Loader2 } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useCulprits } from '@/hooks/useCulprits';
import { useSubscription } from '@/hooks/useSubscription';
import { parseInci } from '@/lib/inci';
import { PaywallBanner } from '@/components/PaywallBanner';
import { supabase } from '@/lib/supabase';

const EXAMPLE = `Water, Glycerin, Niacinamide, Cetyl Alcohol, Caprylic/Capric Triglyceride, Ceramide NP, Sodium Hyaluronate, Phenoxyethanol, Fragrance`;

type Flag = {
  ingredient: string;
  level: 'high' | 'medium' | 'low';
  reason: string;
  source: 'personal' | 'general' | 'both';
};
type AiResult = {
  verdict: 'clean' | 'caution' | 'avoid';
  summary: string;
  flags: Flag[];
  notes?: string;
};

export default function Scanner() {
  const { products } = useProducts();
  const { high, medium } = useCulprits(products);
  const { canUseScanner } = useSubscription();
  const [input, setInput] = useState('');
  const [scanned, setScanned] = useState<string | null>(null);
  const [ai, setAi] = useState<AiResult | null>(null);
  const [aiLoading, setAiLoading] = useState(false);
  const [aiErr, setAiErr] = useState<string | null>(null);

  const culpritMap = useMemo(() => {
    const m = new Map<string, { name: string; risk: 'high' | 'medium'; badCount: number }>();
    for (const c of high) m.set(c.normalized, { name: c.name, risk: 'high', badCount: c.badCount });
    for (const c of medium) m.set(c.normalized, { name: c.name, risk: 'medium', badCount: c.badCount });
    return m;
  }, [high, medium]);

  const matches = useMemo(() => {
    if (!scanned) return null;
    const parsed = parseInci(scanned);
    const out: { name: string; risk: 'high' | 'medium'; badCount: number }[] = [];
    for (const i of parsed) {
      const hit = culpritMap.get(i.normalized);
      if (hit) out.push(hit);
    }
    out.sort((a, b) => (a.risk === b.risk ? b.badCount - a.badCount : a.risk === 'high' ? -1 : 1));
    return out;
  }, [scanned, culpritMap]);

  async function runAiScan() {
    if (!scanned) return;
    setAiLoading(true);
    setAiErr(null);
    setAi(null);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const r = await fetch('/api/scan-ai', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${session?.access_token ?? ''}`,
        },
        body: JSON.stringify({ inci: scanned, matches }),
      });
      if (!r.ok) {
        const e = await r.json().catch(() => ({}));
        throw new Error(e.error ?? `HTTP ${r.status}`);
      }
      const { result } = (await r.json()) as { result: AiResult };
      setAi(result);
    } catch (e: any) {
      setAiErr(String(e?.message ?? e));
    } finally {
      setAiLoading(false);
    }
  }

  function doScan() {
    setScanned(input);
    setAi(null);
    setAiErr(null);
    setTimeout(() => runAiScanWith(input), 0);
  }

  async function runAiScanWith(text: string) {
    if (!text.trim()) return;
    setAiLoading(true);
    setAiErr(null);
    setAi(null);
    try {
      const parsed = parseInci(text);
      const localMatches: { name: string; risk: 'high' | 'medium'; badCount: number }[] = [];
      for (const i of parsed) {
        const hit = culpritMap.get(i.normalized);
        if (hit) localMatches.push(hit);
      }
      const { data: { session } } = await supabase.auth.getSession();
      const r = await fetch('/api/scan-ai', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${session?.access_token ?? ''}`,
        },
        body: JSON.stringify({ inci: text, matches: localMatches }),
      });
      if (!r.ok) {
        const e = await r.json().catch(() => ({}));
        throw new Error(e.error ?? `HTTP ${r.status}`);
      }
      const { result } = (await r.json()) as { result: AiResult };
      setAi(result);
    } catch (e: any) {
      setAiErr(String(e?.message ?? e));
    } finally {
      setAiLoading(false);
    }
  }

  if (!canUseScanner) {
    return (
      <div>
        <h1 className="font-display text-4xl mb-6">Scanner</h1>
        <PaywallBanner reason="scanner" />
      </div>
    );
  }

  return (
    <div className="max-w-3xl">
      <div className="mb-6">
        <h1 className="font-display text-4xl">Scanner</h1>
        <p className="text-muted text-sm mt-1">
          Paste any product's INCI list. Cross-checks against your personal triggers and runs an AI ingredient analysis.
        </p>
      </div>

      <div className="card p-6">
        <label className="label">Ingredient list</label>
        <textarea
          className="input min-h-40 font-mono text-xs"
          placeholder="Paste an INCI list from any product page…"
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <div className="flex gap-2 mt-3">
          <button className="btn-primary" disabled={!input.trim()} onClick={doScan}>
            <ScanLine size={16} /> Scan
          </button>
          <button
            className="btn-ghost"
            onClick={() => {
              setInput(EXAMPLE);
              setScanned(null);
              setAi(null);
            }}
          >
            Try example
          </button>
        </div>
      </div>

      {matches && matches.length === 0 && (
        <div className="card mt-6 p-6 bg-good-bg text-good-fg flex items-start gap-3">
          <CheckCircle2 size={24} className="shrink-0 mt-0.5" />
          <div>
            <div className="font-display text-xl mb-1">No personal triggers found</div>
            <p className="text-sm">This product doesn't contain any of your flagged ingredients.</p>
          </div>
        </div>
      )}

      {matches && matches.length > 0 && (
        <div className="card mt-6 p-6 bg-bad-bg text-bad-fg">
          <div className="flex items-start gap-3 mb-4">
            <AlertTriangle size={24} className="shrink-0 mt-0.5" />
            <div>
              <div className="font-display text-xl mb-1">
                {matches.length} personal trigger{matches.length === 1 ? '' : 's'} detected
              </div>
              <p className="text-sm">This product contains ingredients that appear in your breakouts.</p>
            </div>
          </div>
          <ul className="space-y-2">
            {matches.map((m) => (
              <li
                key={m.name}
                className="flex items-center justify-between bg-card rounded-lg px-4 py-2 text-ink"
              >
                <span className="font-mono text-sm">{m.name}</span>
                <span className="text-xs">
                  {m.risk === 'high' ? 'HIGH' : 'MEDIUM'} · in {m.badCount} breakouts
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {scanned && (
        <div className="mt-6">
          <button
            className="btn-primary"
            onClick={runAiScan}
            disabled={aiLoading}
          >
            {aiLoading ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
            {aiLoading ? 'Analyzing…' : ai ? 'Re-run AI analysis' : 'Run AI analysis'}
          </button>
          {aiErr && <p className="text-sm text-bad-fg mt-2">AI scan failed: {aiErr}</p>}
        </div>
      )}

      {ai && (
        <div className="card mt-6 p-6">
          <div className="flex items-center gap-2 mb-3">
            <Sparkles size={18} />
            <span className="font-display text-xl">AI ingredient analysis</span>
            <span
              className={`text-xs font-mono px-2 py-1 rounded ${
                ai.verdict === 'clean'
                  ? 'bg-good-bg text-good-fg'
                  : ai.verdict === 'caution'
                  ? 'bg-unsure-bg text-unsure-fg'
                  : 'bg-bad-bg text-bad-fg'
              }`}
            >
              {ai.verdict.toUpperCase()}
            </span>
          </div>
          <p className="text-sm mb-4">{ai.summary}</p>
          {ai.flags.length > 0 && (
            <ul className="space-y-2 mb-3">
              {ai.flags.map((f, i) => (
                <li key={i} className="border-l-2 pl-3 py-1" style={{ borderColor: f.level === 'high' ? '#B22B2B' : f.level === 'medium' ? '#8B6914' : '#6B6760' }}>
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-sm">{f.ingredient}</span>
                    <span className="text-xs text-muted">
                      {f.level.toUpperCase()} · {f.source}
                    </span>
                  </div>
                  <p className="text-xs text-muted mt-1">{f.reason}</p>
                </li>
              ))}
            </ul>
          )}
          {ai.notes && <p className="text-xs text-muted italic">{ai.notes}</p>}
        </div>
      )}
    </div>
  );
}
