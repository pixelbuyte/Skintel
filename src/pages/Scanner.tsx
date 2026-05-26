import { useEffect, useMemo, useState } from 'react';
import {
  ScanLine,
  Sparkles,
  Loader2,
  Clipboard,
  Image as ImageIcon,
  Link as LinkIcon,
  History,
  Save,
  Trash2,
  Copy,
  ChevronDown,
  Beaker,
} from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useCulprits } from '@/hooks/useCulprits';
import { useSubscription } from '@/hooks/useSubscription';
import { PaywallBanner } from '@/components/PaywallBanner';
import { ScanResult } from '@/components/ScanResult';
import BarcodeScanner from '@/components/BarcodeScanner';
import PhotoUpload from '@/components/PhotoUpload';
import ImportFromUrl from '@/components/ImportFromUrl';
import { parseInci } from '@/lib/inci';
import { lookupIngredient, type IngredientCategory } from '@/lib/ingredient-knowledge';
import { supabase } from '@/lib/supabase';
import { isPreview } from '@/lib/preview';

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

type Tab = 'paste' | 'barcode' | 'photo' | 'url';

type Example = { id: string; label: string; blurb: string; inci: string };

const EXAMPLES: Example[] = [
  {
    id: 'cera-mz',
    label: 'CeraVe Moisturizer',
    blurb: 'Clean drugstore staple',
    inci:
      'Purified Water, Glycerin, Caprylic/Capric Triglyceride, Cetearyl Alcohol, Ceramide NP, Ceramide AP, Ceramide EOP, Carbomer, Dimethicone, Behentrimonium Methosulfate, Sodium Lauroyl Lactylate, Sodium Hyaluronate, Cholesterol, Phenoxyethanol, Disodium EDTA, Tocopherol, Phytosphingosine, Xanthan Gum, Ethylhexylglycerin',
  },
  {
    id: 'paula-bha',
    label: "Paula's Choice 2% BHA",
    blurb: 'Active exfoliant',
    inci:
      'Water, Methylpropanediol, Butylene Glycol, Salicylic Acid, Polysorbate 20, Camellia Oleifera Leaf Extract, Sodium Hydroxide, Tetrasodium EDTA',
  },
  {
    id: 'fenty-spf',
    label: 'Fenty Hydra Vizor SPF',
    blurb: 'Mineral + chemical hybrid',
    inci:
      'Active: Zinc Oxide 11%, Homosalate 9%, Octisalate 5%, Avobenzone 3%. Inactive: Water, Niacinamide, Glycerin, Butyloctyl Salicylate, Caprylic/Capric Triglyceride, Tocopherol, Hyaluronic Acid, Phenoxyethanol, Fragrance',
  },
  {
    id: 'ord-retin',
    label: 'The Ordinary Retinol 0.5%',
    blurb: 'PM active',
    inci:
      'Squalane, Caprylic/Capric Triglyceride, Retinol, Solanum Lycopersicum (Tomato) Fruit Extract, Simmondsia Chinensis (Jojoba) Seed Oil, Rosa Canina Fruit Oil, Helianthus Annuus (Sunflower) Seed Oil, BHT',
  },
  {
    id: 'fragheavy',
    label: 'Fragrance-heavy lotion',
    blurb: 'Reactive-skin red flag',
    inci:
      'Water, Mineral Oil, Glycerin, Fragrance, Linalool, Limonene, Geraniol, Citronellol, Coumarin, Cetearyl Alcohol, Parabens, Methylisothiazolinone',
  },
];

const HISTORY_KEY = 'skintel:scans:v1';

type HistoryItem = {
  id: string;
  label: string;
  inci: string;
  verdict?: AiResult['verdict'];
  score?: number;
  ts: number;
};

const CAT_TINT: Record<IngredientCategory | 'fragrance', { dot: string; label: string }> = {
  hydrator: { dot: 'bg-sky-400', label: 'Hydrator' },
  barrier: { dot: 'bg-amber-500', label: 'Barrier' },
  emollient: { dot: 'bg-rose-300', label: 'Emollient' },
  occlusive: { dot: 'bg-stone-500', label: 'Occlusive' },
  active: { dot: 'bg-fuchsia-500', label: 'Active' },
  spf: { dot: 'bg-yellow-400', label: 'SPF' },
  peptide: { dot: 'bg-violet-400', label: 'Peptide' },
  antioxidant: { dot: 'bg-emerald-500', label: 'Antioxidant' },
  soothing: { dot: 'bg-teal-400', label: 'Soothing' },
  filler: { dot: 'bg-stone-300', label: 'Filler' },
  preservative: { dot: 'bg-zinc-400', label: 'Preservative' },
  fragrance: { dot: 'bg-red-500', label: 'Fragrance' },
};

const MOCK_AI: AiResult = {
  verdict: 'caution',
  score: 62,
  summary:
    'Solid hydration base with niacinamide + ceramides. Fragrance at position 9 could provoke flush-prone skin — fine for most, flag for sensitive.',
  flags: [
    {
      ingredient: 'Fragrance',
      level: 'medium',
      reason: 'Common irritant. Generic "fragrance" hides 20+ possible allergens.',
      source: 'general',
    },
    {
      ingredient: 'Phenoxyethanol',
      level: 'low',
      reason: 'Preservative, generally well-tolerated at <1%.',
      source: 'general',
    },
  ],
  notes: 'Cross-checked against 0 personal triggers (preview mode).',
};

export default function Scanner() {
  const { products } = useProducts();
  const { high, medium } = useCulprits(products);
  const { canUseScanner } = useSubscription();
  const preview = isPreview();

  const [tab, setTab] = useState<Tab>('paste');
  const [input, setInput] = useState('');
  const [scanned, setScanned] = useState<string | null>(null);
  const [scannedMeta, setScannedMeta] = useState<{ brand?: string; productName?: string } | null>(
    null,
  );
  const [ai, setAi] = useState<AiResult | null>(null);
  const [aiLoading, setAiLoading] = useState(false);
  const [aiErr, setAiErr] = useState<string | null>(null);
  const [showExamples, setShowExamples] = useState(false);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [savedFlash, setSavedFlash] = useState(false);
  const [copiedFlash, setCopiedFlash] = useState(false);

  // Load history once.
  useEffect(() => {
    try {
      const raw = localStorage.getItem(HISTORY_KEY);
      if (raw) {
        const arr = JSON.parse(raw) as HistoryItem[];
        if (Array.isArray(arr)) setHistory(arr.slice(0, 8));
      }
    } catch {}
  }, []);

  const culpritMap = useMemo(() => {
    const m = new Map<string, { name: string; risk: 'high' | 'medium'; badCount: number }>();
    for (const c of high) m.set(c.normalized, { name: c.name, risk: 'high', badCount: c.badCount });
    for (const c of medium) m.set(c.normalized, { name: c.name, risk: 'medium', badCount: c.badCount });
    return m;
  }, [high, medium]);

  // Live ingredient categorization preview (before AI runs).
  const liveCats = useMemo(() => {
    const text = scanned ?? input;
    if (!text.trim()) return null;
    const parsed = parseInci(text);
    const buckets: Record<string, number> = {};
    let total = 0;
    let unknown = 0;
    for (const p of parsed) {
      total += 1;
      const fragHit = /(parfum|fragrance|linalool|limonene|geraniol|citronellol|coumarin)/i.test(p.raw);
      if (fragHit) {
        buckets.fragrance = (buckets.fragrance ?? 0) + 1;
        continue;
      }
      const info = lookupIngredient(p.raw);
      if (!info) {
        unknown += 1;
        continue;
      }
      buckets[info.category] = (buckets[info.category] ?? 0) + 1;
    }
    return { buckets, total, unknown };
  }, [scanned, input]);

  function saveHistoryItem(it: Omit<HistoryItem, 'id' | 'ts'>) {
    const next: HistoryItem = { ...it, id: crypto.randomUUID(), ts: Date.now() };
    const merged = [next, ...history.filter((h) => h.inci !== it.inci)].slice(0, 8);
    setHistory(merged);
    try {
      localStorage.setItem(HISTORY_KEY, JSON.stringify(merged));
    } catch {}
    setSavedFlash(true);
    setTimeout(() => setSavedFlash(false), 1500);
  }

  function clearHistory() {
    setHistory([]);
    try {
      localStorage.removeItem(HISTORY_KEY);
    } catch {}
  }

  function loadFromHistory(h: HistoryItem) {
    setInput(h.inci);
    setScanned(h.inci);
    setScannedMeta(null);
    setAi(null);
    setAiErr(null);
    setTab('paste');
    setTimeout(() => runAiScanWith(h.inci), 0);
  }

  function copyInci() {
    if (!scanned) return;
    try {
      navigator.clipboard.writeText(scanned);
      setCopiedFlash(true);
      setTimeout(() => setCopiedFlash(false), 1500);
    } catch {}
  }

  async function pasteFromClipboard() {
    try {
      const t = await navigator.clipboard.readText();
      if (t) setInput(t);
    } catch {}
  }

  function doScan(text?: string) {
    const t = (text ?? input).trim();
    if (!t) return;
    setScanned(t);
    setAi(null);
    setAiErr(null);
    setTimeout(() => runAiScanWith(t), 0);
  }

  async function runAiScanWith(text: string) {
    if (!text.trim()) return;
    setAiLoading(true);
    setAiErr(null);
    setAi(null);

    if (preview) {
      setTimeout(() => {
        setAi(MOCK_AI);
        setAiLoading(false);
      }, 800);
      return;
    }

    try {
      const localMatches: { name: string; risk: 'high' | 'medium'; badCount: number }[] = [];
      for (const i of parseInci(text)) {
        const hit = culpritMap.get(i.normalized);
        if (hit) localMatches.push(hit);
      }
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session?.access_token) {
        setAiErr('Sign in to run AI analysis.');
        setAiLoading(false);
        return;
      }
      const r = await fetch('/api/scan-ai', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${session.access_token}`,
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
      <div className="max-w-3xl">
        <h1 className="font-display text-5xl mb-6">Scanner</h1>
        <PaywallBanner reason="scanner" />
      </div>
    );
  }

  return (
    <div className="max-w-3xl">
      {/* HERO */}
      <header className="mb-6 relative">
        <div className="absolute -inset-x-4 -top-4 h-28 bg-gradient-to-br from-fuchsia-50/40 via-cream to-sky-50/30 blur-3xl -z-10" />
        <div className="flex items-baseline gap-3 flex-wrap">
          <h1 className="font-display text-5xl tracking-tight">Scanner</h1>
          <span className="font-display italic text-3xl text-muted/70">decode</span>
        </div>
        <p className="text-muted text-sm mt-2 max-w-xl">
          Paste, snap a barcode, OCR a label, or drop a product URL. Skintel cross-checks against your personal triggers + runs deep AI ingredient analysis.
        </p>
      </header>

      {/* TABS */}
      <div className="mb-4 flex gap-1.5 overflow-x-auto pb-1 -mx-1 px-1">
        <TabBtn active={tab === 'paste'} onClick={() => setTab('paste')} icon={<Clipboard size={14} />}>
          Paste
        </TabBtn>
        <TabBtn active={tab === 'barcode'} onClick={() => setTab('barcode')} icon={<ScanLine size={14} />}>
          Barcode
        </TabBtn>
        <TabBtn active={tab === 'photo'} onClick={() => setTab('photo')} icon={<ImageIcon size={14} />}>
          Photo
        </TabBtn>
        <TabBtn active={tab === 'url'} onClick={() => setTab('url')} icon={<LinkIcon size={14} />}>
          URL
        </TabBtn>
      </div>

      {/* INPUT PANEL */}
      {tab === 'paste' && (
        <div className="card p-5">
          <div className="flex items-center justify-between mb-2">
            <label className="label !mb-0">Ingredient list</label>
            <button
              type="button"
              onClick={pasteFromClipboard}
              className="text-[11px] text-muted hover:text-ink inline-flex items-center gap-1"
            >
              <Clipboard size={11} /> Paste from clipboard
            </button>
          </div>
          <textarea
            className="input min-h-40 font-mono text-xs"
            placeholder="Water, Glycerin, Niacinamide, Ceramide NP, …"
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
          <div className="flex gap-2 mt-3 flex-wrap items-center">
            <button className="btn-primary" disabled={!input.trim()} onClick={() => doScan()}>
              <ScanLine size={16} /> Scan
            </button>
            <div className="relative">
              <button
                className="btn-ghost"
                onClick={() => setShowExamples((v) => !v)}
                aria-expanded={showExamples}
              >
                <Beaker size={14} /> Examples
                <ChevronDown size={12} className={showExamples ? 'rotate-180 transition' : 'transition'} />
              </button>
              {showExamples && (
                <div className="absolute z-30 left-0 top-full mt-2 w-72 max-w-[calc(100vw-2rem)] rounded-xl border border-border bg-cream shadow-sheet p-1.5">
                  {EXAMPLES.map((ex) => (
                    <button
                      key={ex.id}
                      onClick={() => {
                        setInput(ex.inci);
                        setShowExamples(false);
                      }}
                      className="w-full text-left rounded-lg px-3 py-2 hover:bg-card transition-colors"
                    >
                      <div className="text-sm font-medium">{ex.label}</div>
                      <div className="text-[11px] text-muted">{ex.blurb}</div>
                    </button>
                  ))}
                </div>
              )}
            </div>
            {input && (
              <button
                className="btn-ghost text-muted ml-auto"
                onClick={() => {
                  setInput('');
                  setScanned(null);
                  setAi(null);
                }}
              >
                <Trash2 size={13} /> Clear
              </button>
            )}
          </div>
        </div>
      )}

      {tab === 'barcode' && (
        <div className="card p-5">
          <BarcodeScanner
            onScanned={(d) => {
              setInput(d.ingredients);
              setScanned(d.ingredients);
              setScannedMeta({ brand: d.brand ?? undefined, productName: d.productName ?? undefined });
              setAi(null);
              setTab('paste');
              setTimeout(() => runAiScanWith(d.ingredients), 0);
            }}
            onSwitchToPhoto={() => setTab('photo')}
          />
        </div>
      )}

      {tab === 'photo' && (
        <PhotoUpload
          onExtracted={(d) => {
            setInput(d.ingredients);
            setScanned(d.ingredients);
            setScannedMeta({ brand: d.brand ?? undefined, productName: d.productName ?? undefined });
            setAi(null);
            setTab('paste');
            setTimeout(() => runAiScanWith(d.ingredients), 0);
          }}
        />
      )}

      {tab === 'url' && (
        <ImportFromUrl
          onImported={(d) => {
            setInput(d.ingredients);
            setScanned(d.ingredients);
            setScannedMeta({ brand: d.brand, productName: d.productName });
            setAi(null);
            setTab('paste');
            setTimeout(() => runAiScanWith(d.ingredients), 0);
          }}
        />
      )}

      {/* LIVE CATEGORIZATION (while typing) */}
      {liveCats && liveCats.total > 0 && !scanned && (
        <div className="mt-4 card p-4">
          <div className="flex items-center gap-2 mb-2.5">
            <Beaker size={14} className="text-muted" />
            <span className="text-xs uppercase tracking-[0.18em] text-muted">Live breakdown</span>
            <span className="text-[11px] text-muted ml-auto">{liveCats.total} ingredients</span>
          </div>
          <CatBars buckets={liveCats.buckets} total={liveCats.total} unknown={liveCats.unknown} />
        </div>
      )}

      {/* SCANNED PRODUCT META */}
      {scanned && scannedMeta && (scannedMeta.brand || scannedMeta.productName) && (
        <div className="mt-4 card p-4 bg-gradient-to-br from-cream to-card">
          <div className="text-[11px] uppercase tracking-wider text-muted">Detected</div>
          <div className="font-display text-xl">{scannedMeta.productName ?? '—'}</div>
          {scannedMeta.brand && <div className="text-sm text-muted">{scannedMeta.brand}</div>}
        </div>
      )}

      {/* CULPRIT MATCH */}
      {scanned && (
        <div className="mt-4">
          <ScanResult ingredients={scanned} high={high} medium={medium} />
        </div>
      )}

      {/* CATEGORY BAR + ACTIONS */}
      {scanned && liveCats && (
        <div className="mt-4 card p-4">
          <div className="flex items-center gap-2 mb-2.5">
            <Beaker size={14} className="text-muted" />
            <span className="text-xs uppercase tracking-[0.18em] text-muted">Ingredient mix</span>
            <span className="text-[11px] text-muted ml-auto">{liveCats.total} total</span>
          </div>
          <CatBars buckets={liveCats.buckets} total={liveCats.total} unknown={liveCats.unknown} />
        </div>
      )}

      {/* AI BAR */}
      {scanned && (
        <div className="mt-4 flex items-center gap-2 flex-wrap">
          <button
            className="btn-primary"
            onClick={() => runAiScanWith(scanned)}
            disabled={aiLoading}
          >
            {aiLoading ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
            {aiLoading ? 'Analyzing…' : ai ? 'Re-run AI analysis' : 'Run AI analysis'}
          </button>
          <button
            className="btn-ghost"
            onClick={() => {
              const label =
                [scannedMeta?.brand, scannedMeta?.productName].filter(Boolean).join(' ') ||
                `Scan ${new Date().toLocaleString()}`;
              saveHistoryItem({ label, inci: scanned, verdict: ai?.verdict, score: ai?.score });
            }}
          >
            <Save size={14} /> {savedFlash ? 'Saved ✓' : 'Save scan'}
          </button>
          <button className="btn-ghost" onClick={copyInci}>
            <Copy size={14} /> {copiedFlash ? 'Copied ✓' : 'Copy INCI'}
          </button>
          {preview && (
            <span className="text-[11px] uppercase tracking-wider text-muted ml-auto">
              preview · mock AI
            </span>
          )}
          {aiErr && <p className="text-sm text-bad-fg w-full">AI scan failed: {aiErr}</p>}
        </div>
      )}

      {/* AI RESULT */}
      {ai && (
        <div className="card mt-4 p-6 animate-in fade-in duration-500">
          <div className="flex items-center gap-2 mb-3 flex-wrap">
            <Sparkles size={18} />
            <span className="font-display text-2xl">AI verdict</span>
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
          </div>
          <p className="text-sm mb-4 leading-relaxed">{ai.summary}</p>
          {ai.flags.length > 0 && (
            <ul className="space-y-2 mb-3">
              {ai.flags.map((f, i) => (
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
          {ai.notes && <p className="text-xs text-muted italic mt-2">{ai.notes}</p>}
        </div>
      )}

      {/* HISTORY */}
      {history.length > 0 && (
        <section className="mt-8">
          <div className="flex items-center gap-2 mb-3">
            <History size={14} className="text-muted" />
            <span className="text-xs uppercase tracking-[0.18em] text-muted">Recent scans</span>
            <button
              onClick={clearHistory}
              className="ml-auto text-[11px] text-muted hover:text-bad-fg inline-flex items-center gap-1"
            >
              <Trash2 size={11} /> Clear all
            </button>
          </div>
          <ul className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            {history.map((h) => (
              <li key={h.id}>
                <button
                  onClick={() => loadFromHistory(h)}
                  className="w-full text-left card p-3 hover:border-ink/30 transition-colors active:scale-[0.99]"
                >
                  <div className="flex items-center gap-2">
                    <div className="min-w-0 flex-1">
                      <div className="text-sm font-medium truncate">{h.label}</div>
                      <div className="text-[11px] text-muted">
                        {new Date(h.ts).toLocaleDateString()} ·{' '}
                        {h.inci.split(',').length} ingredients
                      </div>
                    </div>
                    {h.verdict && (
                      <span
                        className={`text-[10px] font-mono px-1.5 py-0.5 rounded ${
                          h.verdict === 'clean'
                            ? 'bg-good-bg text-good-fg'
                            : h.verdict === 'caution'
                            ? 'bg-unsure-bg text-unsure-fg'
                            : 'bg-bad-bg text-bad-fg'
                        }`}
                      >
                        {h.verdict.toUpperCase()}
                      </span>
                    )}
                  </div>
                </button>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}

function TabBtn({
  active,
  onClick,
  icon,
  children,
}: {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-full text-sm transition-all whitespace-nowrap border ${
        active
          ? 'bg-cream border-ink/40 text-ink shadow-soft font-medium'
          : 'bg-card/60 border-border text-muted hover:text-ink hover:border-ink/20'
      }`}
    >
      {icon}
      {children}
    </button>
  );
}

function CatBars({
  buckets,
  total,
  unknown,
}: {
  buckets: Record<string, number>;
  total: number;
  unknown: number;
}) {
  const entries = Object.entries(buckets).sort((a, b) => b[1] - a[1]);
  if (entries.length === 0 && unknown === 0) return null;
  return (
    <div className="space-y-2">
      <div className="flex h-2 w-full rounded-full overflow-hidden bg-card">
        {entries.map(([cat, n]) => {
          const pct = (n / total) * 100;
          const style = (CAT_TINT as Record<string, { dot: string; label: string }>)[cat];
          return (
            <div
              key={cat}
              style={{ width: `${pct}%` }}
              className={style ? style.dot : 'bg-stone-300'}
              title={`${style?.label ?? cat}: ${n}`}
            />
          );
        })}
        {unknown > 0 && (
          <div
            style={{ width: `${(unknown / total) * 100}%` }}
            className="bg-stone-300/60"
            title={`Unknown: ${unknown}`}
          />
        )}
      </div>
      <div className="flex flex-wrap gap-2">
        {entries.map(([cat, n]) => {
          const style = (CAT_TINT as Record<string, { dot: string; label: string }>)[cat];
          return (
            <span
              key={cat}
              className="inline-flex items-center gap-1.5 text-[11px] font-mono text-muted"
            >
              <span className={`size-1.5 rounded-full ${style?.dot ?? 'bg-stone-400'}`} />
              {style?.label ?? cat} · {n}
            </span>
          );
        })}
        {unknown > 0 && (
          <span className="inline-flex items-center gap-1.5 text-[11px] font-mono text-muted">
            <span className="size-1.5 rounded-full bg-stone-300/80" />
            Unknown · {unknown}
          </span>
        )}
      </div>
    </div>
  );
}
