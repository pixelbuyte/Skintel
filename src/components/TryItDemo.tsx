import { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, Barcode, Beaker, ScanBarcode, Sparkles, ScanLine, Zap, ShieldCheck, Wand2 } from 'lucide-react';
import { AnimatedBorder, SparkleField } from './Tilt3D';
import { parseInci } from '@/lib/inci';
import {
  categorizeIngredients,
  generateVerdict,
  type Culprit,
} from '@/lib/ingredient-knowledge';
import { VerdictCard } from './VerdictCard';
import { Bucket } from './Bucket';

const SAMPLE =
  'Aqua, Glycerin, Niacinamide, Bisabolol, Coconut Alkanes, Ceramide NP, Panthenol, Fragrance, Linalool, Sodium Hyaluronate';

const SHELF_PRODUCTS = [
  {
    name: 'Daily Barrier Moisturizer',
    shortName: 'moisturizer',
    barcode: '0 36000 29145 2',
    ingredients: 'Aqua, Glycerin, Niacinamide, Bisabolol, Coconut Alkanes, Ceramide NP, Panthenol, Squalane, Allantoin, Sodium Hyaluronate',
    triggers: [] as string[],
    back: '#C9DDEA',
    shape: 'rounded-[28px]',
  },
  {
    name: 'Fragrance Rich Lotion',
    shortName: 'lotion',
    barcode: '8 52177 04261 9',
    ingredients: 'Aqua, Glycerin, Coconut Alkanes, Fragrance, Linalool, Limonene, Shea Butter, Phenoxyethanol, Citric Acid, Tocopherol',
    triggers: ['Fragrance', 'Linalool'],
    back: '#E8A98F',
    shape: 'rounded-t-[24px] rounded-b-xl',
  },
  {
    name: 'Calming Peptide Serum',
    shortName: 'serum',
    barcode: '6 11804 77320 5',
    ingredients: 'Aqua, Glycerin, Panthenol, Peptide Complex, Beta-Glucan, Centella Asiatica Extract, Ceramide NP, Sodium Hyaluronate, Phenoxyethanol, Citric Acid',
    triggers: [] as string[],
    back: '#DCC8A9',
    shape: 'rounded-[30px]',
  },
] as const;

const EMPTY_MAP: Map<string, Culprit> = new Map();

export function TryItDemo() {
  const [demoMode, setDemoMode] = useState<'scan' | 'paste'>('scan');
  const [input, setInput] = useState('');
  const [analyzed, setAnalyzed] = useState<string | null>(null);
  const [scanning, setScanning] = useState(false);
  const [selectedProductIndex, setSelectedProductIndex] = useState<number | null>(null);
  const [productFlipped, setProductFlipped] = useState(false);
  const [scanStage, setScanStage] = useState<'shelf' | 'picked' | 'scanning' | 'result'>('shelf');
  const [showResult, setShowResult] = useState(false);
  const [typingSample, setTypingSample] = useState(false);
  const [scanCount, setScanCount] = useState(0);
  const [verdictGlow, setVerdictGlow] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const selectedProduct = selectedProductIndex === null ? null : SHELF_PRODUCTS[selectedProductIndex];

  const result = useMemo(() => {
    if (!analyzed) return null;
    const parsed = parseInci(analyzed);
    if (parsed.length === 0) return null;
    const culpritMap = selectedProduct
      ? new Map(selectedProduct.triggers.map((name) => [name.toLowerCase(), { name, risk: 'high' as const, badCount: 3 }]))
      : EMPTY_MAP;
    const buckets = categorizeIngredients(parsed, culpritMap);
    const verdict = generateVerdict(buckets);
    return { buckets, verdict, count: parsed.length };
  }, [analyzed, selectedProduct]);

  function triggerScan(value: string) {
    setAnalyzed(null);
    setShowResult(false);
    setVerdictGlow(false);
    setScanCount(0);
    setScanning(true);
    const total = value.split(',').length;
    let c = 0;
    const countUp = window.setInterval(() => {
      c = Math.min(c + Math.ceil(total / 12), total);
      setScanCount(c);
      if (c >= total) window.clearInterval(countUp);
    }, 80);
    window.setTimeout(() => {
      window.clearInterval(countUp);
      setScanCount(total);
      setAnalyzed(value);
      setScanning(false);
      setShowResult(true);
      if (demoMode === 'scan') setScanStage('result');
      window.setTimeout(() => setVerdictGlow(true), 200);
    }, 1100);
  }

  function loadSample() {
    setInput('');
    setAnalyzed(null);
    setShowResult(false);
    setTypingSample(true);
    let i = 0;
    const tick = () => {
      i++;
      setInput(SAMPLE.slice(0, i));
      if (i < SAMPLE.length) {
        window.setTimeout(tick, 14);
      } else {
        setTypingSample(false);
        triggerScan(SAMPLE);
      }
    };
    tick();
  }

  function selectShelfProduct(index: number) {
    setSelectedProductIndex(index);
    setProductFlipped(false);
    setScanStage('picked');
    setInput('');
    setAnalyzed(null);
    setShowResult(false);
    window.setTimeout(() => setProductFlipped(true), 360);
  }

  function resetShelf() {
    setSelectedProductIndex(null);
    setProductFlipped(false);
    setScanStage('shelf');
    setInput('');
    setAnalyzed(null);
    setShowResult(false);
  }

  function scanSampleBarcode() {
    if (!selectedProduct) return;
    setScanStage('scanning');
    setInput(selectedProduct.ingredients);
    triggerScan(selectedProduct.ingredients);
  }

  return (
    <div className="relative">
      <div
        aria-hidden
        className="absolute -inset-10 -z-10"
        style={{
          background:
            'radial-gradient(60% 50% at 30% 20%, rgba(163,88,72,0.18), transparent 70%), radial-gradient(50% 40% at 80% 90%, rgba(163,88,72,0.14), transparent 70%)',
          filter: 'blur(40px)',
        }}
      />
      <div
        aria-hidden
        className="absolute -inset-3 rounded-[36px] -z-10 opacity-60"
        style={{
          background:
            'conic-gradient(from var(--demo-angle, 0deg), rgba(163,88,72,0) 0%, rgba(163,88,72,0.4) 20%, rgba(255,200,180,0.55) 35%, rgba(163,88,72,0.4) 50%, rgba(163,88,72,0) 70%, rgba(163,88,72,0) 100%)',
          animation: 'demoAngle 8s linear infinite',
          filter: 'blur(14px)',
        }}
      />

      <AnimatedBorder intensity={0.9}>
        <div className="card relative overflow-hidden shadow-soft rounded-card">
          <SparkleField count={10} />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 opacity-[0.06]"
            style={{
              backgroundImage:
                "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='180' height='180'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/></filter><rect width='100%' height='100%' filter='url(%23n)' opacity='0.5'/></svg>\")",
              mixBlendMode: 'multiply',
            }}
          />
          <div
            aria-hidden
            className="absolute -top-24 -right-24 size-72 bg-primary/15 blur-3xl rounded-full"
          />
          <div
            aria-hidden
            className="absolute -bottom-24 -left-24 size-72 bg-primary/10 blur-3xl rounded-full"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 rounded-card"
            style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7), inset 0 -1px 0 rgba(0,0,0,0.04)' }}
          />

        <div className="relative p-6 md:p-10">
          <div className="flex items-center justify-between mb-5">
            <div className="inline-flex items-center gap-2 text-[11px] uppercase tracking-[0.18em] text-primary bg-gradient-to-r from-primary/12 to-primary/6 border border-primary/25 px-3.5 py-1.5 rounded-full font-semibold shadow-[0_0_20px_rgba(163,88,72,0.15)]">
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full rounded-full bg-primary opacity-75 animate-ping" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-primary" />
              </span>
              <Beaker size={12} /> Live demo · No account
            </div>
            <div className="hidden sm:flex items-center gap-1.5 text-[10px] uppercase tracking-[0.18em] text-muted font-medium">
              <ShieldCheck size={11} className="text-primary/70" />
              100% in your browser
            </div>
          </div>

          <div className="grid grid-cols-2 gap-1 rounded-xl border border-border bg-bg/70 p-1 mb-6" role="tablist" aria-label="Choose demo input">
            <button
              type="button"
              role="tab"
              aria-selected={demoMode === 'scan'}
              onClick={() => setDemoMode('scan')}
              className={`inline-flex items-center justify-center gap-2 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${demoMode === 'scan' ? 'bg-card text-ink shadow-sm' : 'text-muted hover:text-ink'}`}
            >
              <ScanBarcode size={15} /> Scan barcode
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={demoMode === 'paste'}
              onClick={() => setDemoMode('paste')}
              className={`inline-flex items-center justify-center gap-2 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${demoMode === 'paste' ? 'bg-card text-ink shadow-sm' : 'text-muted hover:text-ink'}`}
            >
              <Beaker size={15} /> Paste ingredients
            </button>
          </div>

          <h3 className="font-display text-4xl md:text-5xl mb-4 leading-[1.02] tracking-tight">
            {demoMode === 'scan' ? (
              <>Scan the barcode.<br /><span className="italic text-primary font-light">See what’s inside.</span></>
            ) : (
              <>Paste any INCI list.<br /><span className="italic text-primary font-light">See your match.</span></>
            )}
          </h3>
          <p className="text-muted text-base md:text-lg mb-5 max-w-[58ch] leading-relaxed">
            {demoMode === 'scan'
              ? 'Point Skintel at a product barcode. It finds the ingredient list, checks every ingredient, and tells you if it is a good match.'
              : 'Paste the ingredients from any product page or bottle to get the same personal verdict — no photo required.'}
          </p>

          <div className="flex flex-wrap items-center gap-x-5 gap-y-2 mb-6 text-[11px] uppercase tracking-[0.14em] text-muted/80 font-medium">
            <span className="inline-flex items-center gap-1.5"><Zap size={11} className="text-primary" /> Fast verdict</span>
            <span className="inline-flex items-center gap-1.5"><ShieldCheck size={11} className="text-primary" /> Private by default</span>
            <span className="inline-flex items-center gap-1.5"><Wand2 size={11} className="text-primary" /> 2,400+ markers</span>
          </div>

          {demoMode === 'scan' ? (
            <ShelfScanner
              selectedIndex={selectedProductIndex}
              flipped={productFlipped}
              stage={scanStage}
              scanCount={scanCount}
              onSelect={selectShelfProduct}
            />
          ) : (
            <div className="relative group">
              <textarea
                ref={textareaRef}
                value={input}
                onChange={(e) => setInput(e.target.value)}
                placeholder="Aqua, Glycerin, Niacinamide, Bisabolol, Fragrance..."
                rows={4}
                disabled={typingSample || scanning}
                className="w-full px-4 py-3.5 rounded-xl border border-border bg-card text-ink placeholder:text-muted/60 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all duration-300 ease-emil font-mono text-xs leading-relaxed resize-none disabled:opacity-90"
              />
              {scanning && <div className="absolute bottom-2 right-3 flex items-center gap-1.5 text-[10px] font-mono text-primary animate-pulse"><span className="size-1.5 rounded-full bg-primary animate-ping" />Parsing {scanCount} ingredients…</div>}
            </div>
          )}

          <div className="flex flex-wrap items-center gap-2 mt-4">
            <button
              type="button"
              onClick={demoMode === 'scan' ? scanSampleBarcode : () => triggerScan(input.trim())}
              disabled={(demoMode === 'scan' && selectedProductIndex === null) || (demoMode === 'paste' && !input.trim()) || scanning || typingSample}
              className="btn-primary active:scale-[0.96] transition-all duration-200 ease-emil disabled:opacity-50 group/btn"
            >
              {scanning
                ? <><ScanLine size={14} className="animate-pulse" /> Reading barcode…</>
                : demoMode === 'scan'
                  ? <><ScanBarcode size={14} /> {selectedProduct ? `Scan ${selectedProduct.shortName}` : 'Pick a product to scan'}</>
                  : <><Sparkles size={14} /> Analyze ingredients</>}
            </button>
            {demoMode === 'scan' && selectedProduct && !scanning && (
              <button type="button" onClick={resetShelf} className="btn-secondary active:scale-[0.96] transition-all duration-200 ease-emil">
                Back to shelf
              </button>
            )}
            {demoMode === 'paste' && (
              <button type="button" onClick={loadSample} disabled={scanning || typingSample} className="btn-secondary active:scale-[0.96] transition-all duration-200 ease-emil disabled:opacity-50">
                Try a sample
              </button>
            )}
            {demoMode === 'paste' && (result || input) && !scanning && !typingSample && (
              <button type="button" onClick={() => { setInput(''); setAnalyzed(null); setShowResult(false); }} className="text-sm text-muted hover:text-ink transition-colors duration-200 ease-emil px-2 py-1.5">Clear</button>
            )}
          </div>

          {result && showResult && (
            <div className="mt-7 space-y-3">
              {demoMode === 'scan' && (
                <ResultReveal delay={0}>
                  <div className="rounded-xl border border-border bg-bg/70 px-4 py-3 flex items-center justify-between gap-4">
                    <div>
                      <div className="text-[10px] uppercase tracking-[0.16em] text-primary font-semibold">Barcode found</div>
                      <div className="font-medium text-ink mt-1">{selectedProduct?.name}</div>
                      <div className="text-xs text-muted mt-0.5">{result.count} ingredients retrieved and checked</div>
                    </div>
                    <div className="size-10 rounded-full bg-good-bg text-good-fg flex items-center justify-center">
                      <ShieldCheck size={20} />
                    </div>
                  </div>
                </ResultReveal>
              )}
              <ResultReveal delay={0} variant="verdict">
                <div className={`transition-all duration-700 ${verdictGlow ? 'verdict-glow' : ''}`}>
                  <VerdictCard
                    verdict={result.verdict}
                    goodCount={result.buckets.good.length}
                    badCount={result.buckets.watchOut.length}
                    totalCount={result.count}
                  />
                </div>
              </ResultReveal>
              {result.buckets.watchOut.length > 0 && (
                <ResultReveal delay={120}>
                  <Bucket title="Watch out" tone="bad" rows={result.buckets.watchOut} />
                </ResultReveal>
              )}
              {result.buckets.good.length > 0 && (
                <ResultReveal delay={result.buckets.watchOut.length > 0 ? 240 : 120}>
                  <Bucket title="Good for your skin" tone="good" rows={result.buckets.good} />
                </ResultReveal>
              )}
              {result.buckets.rest.length > 0 && (
                <ResultReveal delay={360}>
                  <div className="flex items-center gap-2 px-1">
                    <span className="flex-1 h-px bg-border" />
                    <span className="inline-flex items-center gap-1.5 text-[11px] font-mono text-muted border border-border rounded-full px-3 py-1">
                      <span className="size-1.5 rounded-full bg-muted/40" />
                      {result.buckets.rest.length} more · no known issues
                    </span>
                    <span className="flex-1 h-px bg-border" />
                  </div>
                </ResultReveal>
              )}
              <ResultReveal delay={480}>
                <div className="border-t border-border pt-5 mt-2">
                  <p className="text-sm text-muted mb-4 leading-relaxed">
                    This demo only flags fragrance markers and known-good ingredients.
                    Sign up to build your <span className="text-ink font-medium">personal trigger map</span> — Skintel
                    learns from products <em>you</em> tag.
                  </p>
                  <Link
                    to="/login"
                    className="btn-primary active:scale-[0.96] transition-all duration-200 ease-emil inline-flex group/cta"
                  >
                    Build my trigger map
                    <ArrowRight
                      size={16}
                      className="group-hover/cta:translate-x-0.5 transition-transform duration-200"
                    />
                  </Link>
                </div>
              </ResultReveal>
            </div>
          )}
        </div>
        </div>
      </AnimatedBorder>

      <style>{`
        @property --demo-angle {
          syntax: '<angle>';
          initial-value: 0deg;
          inherits: false;
        }
        @keyframes demoAngle {
          to { --demo-angle: 360deg; }
        }
        @keyframes scanline {
          0% { transform: translateY(-100%); opacity: 0; }
          15% { opacity: 1; }
          85% { opacity: 1; }
          100% { transform: translateY(800%); opacity: 0; }
        }
        @keyframes scanlineCamera {
          0% { transform: translateY(-220%); opacity: 0; }
          15% { opacity: 1; }
          85% { opacity: 1; }
          100% { transform: translateY(420%); opacity: 0; }
        }
        @keyframes productLift {
          0% { opacity: 0; transform: translateY(95px) scale(0.72); }
          65% { opacity: 1; transform: translateY(-8px) scale(1.03); }
          100% { opacity: 1; transform: translateY(0) scale(1); }
        }
        @keyframes shelfScan {
          0% { transform: translateY(-80px); opacity: 0; }
          18% { opacity: 1; }
          82% { opacity: 1; }
          100% { transform: translateY(250px); opacity: 0; }
        }
        .animate-product-lift { animation: productLift 520ms cubic-bezier(0.22,1,0.36,1) both; }
        .animate-shelf-scan { animation: shelfScan 1.1s ease-in-out forwards; }
        @keyframes resultReveal {
          0% { opacity: 0; transform: translateY(18px) scale(0.97); filter: blur(4px); }
          60% { filter: blur(0); }
          100% { opacity: 1; transform: translateY(0) scale(1); filter: blur(0); }
        }
        @keyframes verdictPop {
          0% { opacity: 0; transform: translateY(10px) scale(0.94); filter: blur(6px); }
          55% { transform: translateY(-3px) scale(1.015); filter: blur(0); }
          75% { transform: translateY(1px) scale(0.998); }
          100% { opacity: 1; transform: translateY(0) scale(1); }
        }
        @keyframes glowPulse {
          0%, 100% { box-shadow: 0 0 0 0 rgba(163,88,72,0); }
          50% { box-shadow: 0 0 32px 4px rgba(163,88,72,0.35); }
        }
        .result-reveal { animation: resultReveal 550ms cubic-bezier(0.22,1,0.36,1) both; }
        .result-reveal-verdict { animation: verdictPop 700ms cubic-bezier(0.22,1,0.36,1) both; }
        .verdict-glow { animation: glowPulse 1.2s ease-in-out 1; border-radius: 12px; }
        @media (prefers-reduced-motion: reduce) {
          .animate-product-lift, .animate-shelf-scan { animation: none !important; }
        }
      `}</style>
    </div>
  );
}

function ResultReveal({ children, delay = 0, variant = 'default' }: { children: React.ReactNode; delay?: number; variant?: 'default' | 'verdict' }) {
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const t = window.setTimeout(() => setShown(true), delay);
    return () => window.clearTimeout(t);
  }, [delay]);
  const cls = shown
    ? variant === 'verdict' ? 'result-reveal-verdict' : 'result-reveal'
    : 'opacity-0 pointer-events-none';
  return <div className={cls}>{children}</div>;
}

function ProductSprite({ index, className = '' }: { index: number; className?: string }) {
  return (
    <div
      aria-hidden
      className={className}
      style={{
        backgroundImage: "url('/assets/skintel-products-sprite.png')",
        backgroundRepeat: 'no-repeat',
        backgroundSize: '300% 100%',
        backgroundPosition: index === 0 ? '0% 50%' : index === 1 ? '50% 50%' : '100% 50%',
      }}
    />
  );
}

function MiniBarcode({ code }: { code: string }) {
  return (
    <div className="rounded-md border border-ink/10 bg-white/90 px-2 py-2 shadow-sm">
      <div
        aria-hidden
        className="h-10 w-full"
        style={{ background: 'repeating-linear-gradient(90deg, #1e1a17 0 1px, transparent 1px 3px, #1e1a17 3px 5px, transparent 5px 7px, #1e1a17 7px 8px, transparent 8px 11px)' }}
      />
      <div className="mt-1 text-center font-mono text-[7px] tracking-[0.18em] text-muted">{code}</div>
    </div>
  );
}

function ShelfScanner({
  selectedIndex,
  flipped,
  stage,
  scanCount,
  onSelect,
}: {
  selectedIndex: number | null;
  flipped: boolean;
  stage: 'shelf' | 'picked' | 'scanning' | 'result';
  scanCount: number;
  onSelect: (index: number) => void;
}) {
  const product = selectedIndex === null ? null : SHELF_PRODUCTS[selectedIndex];

  return (
    <div className="rounded-2xl bg-ink p-3 sm:p-4 shadow-soft">
      <div className="relative isolate overflow-hidden rounded-xl min-h-[390px] sm:min-h-[430px] bg-[#ECE3D5]">
        <div aria-hidden className="absolute inset-0 bg-[radial-gradient(circle_at_50%_8%,rgba(255,255,255,0.9),transparent_42%),linear-gradient(180deg,#F7F0E6_0%,#E8DCCC_100%)]" />
        <div className="absolute inset-x-4 top-4 z-20 flex items-center justify-between text-[10px] uppercase tracking-[0.15em]">
          <span className="text-ink/65">{product ? 'Product picked up' : 'Choose a product'}</span>
          <span className="font-mono text-primary">{stage === 'scanning' ? `READING ${scanCount}/10` : product ? 'BACK LABEL' : '3 ON SHELF'}</span>
        </div>

        <div aria-hidden className="absolute inset-x-0 bottom-[106px] h-3 bg-[#B99A7B] shadow-[0_8px_18px_rgba(77,50,30,0.22)]" />
        <div aria-hidden className="absolute inset-x-0 bottom-[118px] h-px bg-white/80" />

        <div className={`absolute inset-x-4 bottom-[118px] grid grid-cols-3 items-end gap-1 transition-all duration-500 ${product ? 'opacity-30 scale-[0.96]' : 'opacity-100'}`}>
          {SHELF_PRODUCTS.map((item, index) => (
            <button
              key={item.name}
              type="button"
              aria-label={`Pick up ${item.name}`}
              aria-pressed={selectedIndex === index}
              onClick={() => onSelect(index)}
              disabled={stage === 'scanning'}
              className={`group relative flex h-[210px] items-end justify-center rounded-t-2xl outline-none transition-all duration-300 hover:-translate-y-3 focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-[#ECE3D5] ${selectedIndex === index ? 'opacity-0' : ''}`}
            >
              <ProductSprite index={index} className="h-[188px] w-[118px] max-w-full drop-shadow-[0_12px_10px_rgba(62,42,30,0.18)] transition-transform duration-300 group-hover:scale-[1.04]" />
              <span className="absolute -bottom-8 inset-x-0 text-center text-[9px] font-medium leading-tight text-ink/65">{item.shortName}</span>
            </button>
          ))}
        </div>

        {product && selectedIndex !== null && (
          <div className="absolute inset-x-0 top-12 z-10 flex justify-center [perspective:1000px]">
            <div className="animate-product-lift">
              <div
                className="relative h-[270px] w-[170px] transition-transform duration-700 ease-emil"
                style={{ transformStyle: 'preserve-3d', transform: `rotateY(${flipped ? 180 : 0}deg)` }}
              >
                <div className="absolute inset-0" style={{ backfaceVisibility: 'hidden' }}>
                  <ProductSprite
                    index={selectedIndex}
                    className="h-full w-full drop-shadow-[0_20px_18px_rgba(62,42,30,0.2)]"
                  />
                </div>
                <div
                  className={`absolute inset-0 flex flex-col justify-end overflow-hidden border border-white/70 p-4 shadow-[0_20px_28px_rgba(62,42,30,0.22)] ${product.shape}`}
                  style={{ background: product.back, backfaceVisibility: 'hidden', transform: 'rotateY(180deg)' }}
                >
                  <div className="absolute inset-x-5 top-6 space-y-1 opacity-60">
                    {[86, 100, 72, 92, 64].map((width) => <div key={width} className="h-1 rounded-full bg-ink/30" style={{ width: `${width}%` }} />)}
                  </div>
                  <div className="rounded-lg bg-card/85 p-2.5 backdrop-blur-sm">
                    <div className="mb-2 flex items-center justify-between text-[7px] uppercase tracking-[0.13em] text-muted">
                      <span>Back label</span><Barcode size={11} />
                    </div>
                    <MiniBarcode code={product.barcode} />
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {stage === 'scanning' && (
          <div aria-hidden className="absolute z-30 inset-x-[16%] top-16 h-16 bg-gradient-to-b from-transparent via-primary/55 to-transparent animate-shelf-scan" />
        )}

        <div className="absolute bottom-4 inset-x-4 z-20 flex items-center justify-between rounded-xl border border-white/60 bg-card/90 px-3 py-2.5 text-[10px] shadow-sm backdrop-blur-sm">
          <span className="text-muted">
            {stage === 'shelf' && 'Tap a bottle to pick it up'}
            {stage === 'picked' && (flipped ? 'Back label ready to scan' : 'Turning product around…')}
            {stage === 'scanning' && 'Reading barcode and fetching ingredients…'}
            {stage === 'result' && 'Ingredients found — verdict ready'}
          </span>
          <span className="font-mono text-primary">{stage === 'result' ? 'DONE' : stage === 'scanning' ? 'SCANNING' : 'READY'}</span>
        </div>
      </div>
    </div>
  );
}
