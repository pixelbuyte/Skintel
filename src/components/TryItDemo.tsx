import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { AlertTriangle, ArrowRight, Beaker, Check, ScanBarcode, ScanLine, Zap, ShieldCheck, Wand2 } from 'lucide-react';
import { AnimatedBorder, SparkleField } from './Tilt3D';
import { parseInci } from '@/lib/inci';
import {
  categorizeIngredients,
  generateVerdict,
  type BucketRow,
  type Culprit,
} from '@/lib/ingredient-knowledge';
import { VerdictCard } from './VerdictCard';
import { Bucket } from './Bucket';

const SHELF_PRODUCTS = [
  {
    name: 'Daily Barrier Moisturizer',
    shortName: 'moisturizer',
    barcode: '0 36000 29145 2',
    ingredients: 'Aqua, Glycerin, Niacinamide, Bisabolol, Coconut Alkanes, Ceramide NP, Panthenol, Squalane, Allantoin, Sodium Hyaluronate',
    triggers: [] as string[],
  },
  {
    name: 'Fragrance Rich Lotion',
    shortName: 'lotion',
    barcode: '8 52177 04261 9',
    ingredients: 'Aqua, Glycerin, Coconut Alkanes, Fragrance, Linalool, Limonene, Shea Butter, Phenoxyethanol, Citric Acid, Tocopherol',
    triggers: ['Fragrance', 'Linalool'],
  },
  {
    name: 'Calming Peptide Serum',
    shortName: 'serum',
    barcode: '6 11804 77320 5',
    ingredients: 'Aqua, Glycerin, Panthenol, Peptide Complex, Beta-Glucan, Centella Asiatica Extract, Ceramide NP, Sodium Hyaluronate, Phenoxyethanol, Citric Acid',
    triggers: [] as string[],
  },
] as const;

const EMPTY_MAP: Map<string, Culprit> = new Map();

export function TryItDemo() {
  const [demoMode, setDemoMode] = useState<'scan' | 'paste'>('scan');
  const [analyzed, setAnalyzed] = useState<string | null>(null);
  const [scanning, setScanning] = useState(false);
  const [selectedProductIndex, setSelectedProductIndex] = useState<number | null>(null);
  const [productFlipped, setProductFlipped] = useState(false);
  const [scanStage, setScanStage] = useState<'shelf' | 'picked' | 'scanning' | 'result'>('shelf');
  const [showResult, setShowResult] = useState(false);
  const [scanCount, setScanCount] = useState(0);
  const [verdictGlow, setVerdictGlow] = useState(false);
  const selectedProduct = selectedProductIndex === null ? null : SHELF_PRODUCTS[selectedProductIndex];

  const result = useMemo(() => {
    if (!analyzed) return null;
    const parsed = parseInci(analyzed);
    if (parsed.length === 0) return null;
    const verdictProduct = demoMode === 'scan' ? selectedProduct : SHELF_PRODUCTS[1];
    const culpritMap = verdictProduct
      ? new Map(verdictProduct.triggers.map((name) => [name.toLowerCase(), { name, risk: 'high' as const, badCount: 3 }]))
      : EMPTY_MAP;
    const buckets = categorizeIngredients(parsed, culpritMap);
    const verdict = generateVerdict(buckets);
    return { buckets, verdict, count: parsed.length };
  }, [analyzed, demoMode, selectedProduct]);

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

  function selectShelfProduct(index: number) {
    setSelectedProductIndex(index);
    setProductFlipped(false);
    setScanStage('picked');
    setAnalyzed(null);
    setShowResult(false);
    window.setTimeout(() => setProductFlipped(true), 360);
  }

  function resetShelf() {
    setSelectedProductIndex(null);
    setProductFlipped(false);
    setScanStage('shelf');
    setAnalyzed(null);
    setShowResult(false);
  }

  function scanSampleBarcode() {
    if (!selectedProduct) return;
    setScanStage('scanning');
    triggerScan(selectedProduct.ingredients);
  }

  function scanIngredientLabel() {
    triggerScan(SHELF_PRODUCTS[1].ingredients);
  }

  function switchDemoMode(mode: 'scan' | 'paste') {
    setDemoMode(mode);
    setAnalyzed(null);
    setShowResult(false);
    setVerdictGlow(false);
    setScanning(false);
    setScanCount(0);
  }

  return (
    <div className="relative" data-testid="try-it-demo">
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
              onClick={() => switchDemoMode('scan')}
              className={`inline-flex items-center justify-center gap-2 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${demoMode === 'scan' ? 'bg-card text-ink shadow-sm' : 'text-muted hover:text-ink'}`}
            >
              <ScanBarcode size={15} /> Scan barcode
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={demoMode === 'paste'}
              onClick={() => switchDemoMode('paste')}
              className={`inline-flex items-center justify-center gap-2 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${demoMode === 'paste' ? 'bg-card text-ink shadow-sm' : 'text-muted hover:text-ink'}`}
            >
              <ScanLine size={15} /> Scan ingredients
            </button>
          </div>

          <h3 className="font-display text-4xl md:text-5xl mb-4 leading-[1.02] tracking-tight">
            {demoMode === 'scan' ? (
              <>Scan the barcode.<br /><span className="italic text-primary font-light">See what’s inside.</span></>
            ) : (
              <>Scan the ingredients.<br /><span className="italic text-primary font-light">See your match.</span></>
            )}
          </h3>
          <p className="text-muted text-base md:text-lg mb-5 max-w-[58ch] leading-relaxed">
            {demoMode === 'scan'
              ? 'Point Skintel at a product barcode. It finds the ingredient list, checks every ingredient, and tells you if it is a good match.'
              : 'Point Skintel at the ingredient list on the back of a bottle. It reads the label, checks every ingredient, and returns the same personal verdict.'}
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
            <IngredientLabelScanner
              scanning={scanning}
              scanCount={scanCount}
              result={showResult && result ? {
                count: result.count,
                watchOut: result.buckets.watchOut,
                good: result.buckets.good,
                restCount: result.buckets.rest.length,
              } : null}
            />
          )}

          <div className="flex flex-wrap items-center gap-2 mt-4">
            <button
              type="button"
              onClick={demoMode === 'scan' ? scanSampleBarcode : scanIngredientLabel}
              disabled={(demoMode === 'scan' && selectedProductIndex === null) || scanning}
              className="btn-primary active:scale-[0.96] transition-all duration-200 ease-emil disabled:opacity-50 group/btn"
            >
              {scanning
                ? <><ScanLine size={14} className="animate-pulse" /> {demoMode === 'scan' ? 'Reading barcode…' : 'Reading ingredient label…'}</>
                : demoMode === 'scan'
                  ? <><ScanBarcode size={14} /> {selectedProduct ? `Scan ${selectedProduct.shortName}` : 'Pick a product to scan'}</>
                  : <><ScanLine size={14} /> {showResult ? 'Scan again' : 'Scan ingredient label'}</>}
            </button>
            {demoMode === 'scan' && selectedProduct && !scanning && (
              <button type="button" onClick={resetShelf} className="btn-secondary active:scale-[0.96] transition-all duration-200 ease-emil">
                Back to shelf
              </button>
            )}
          </div>

          {result && showResult && demoMode === 'scan' && (
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
        @keyframes ingredientScan {
          0% { transform: translateY(-24px); opacity: 0; }
          14% { opacity: 1; }
          86% { opacity: 1; }
          100% { transform: translateY(142px); opacity: 0; }
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

function ProductSprite({ index, side = 'front', className = '' }: { index: number; side?: 'front' | 'back'; className?: string }) {
  return (
    <div
      aria-hidden
      className={className}
      style={{
        backgroundImage: `url('${side === 'front' ? '/assets/skintel-products-sprite.png' : '/assets/skintel-products-back-sprite.png'}')`,
        backgroundRepeat: 'no-repeat',
        backgroundSize: '300% 100%',
        backgroundPosition: index === 0 ? '0% 50%' : index === 1 ? '50% 50%' : '100% 50%',
      }}
    />
  );
}

type InlineIngredientResult = {
  count: number;
  watchOut: BucketRow[];
  good: BucketRow[];
  restCount: number;
};

function IngredientLabelScanner({
  scanning,
  scanCount,
  result,
}: {
  scanning: boolean;
  scanCount: number;
  result: InlineIngredientResult | null;
}) {
  return (
    <div className="rounded-2xl bg-ink p-3 sm:p-4 shadow-soft" data-testid="ingredient-label-scanner">
      <div className="relative isolate overflow-hidden rounded-xl min-h-[390px] sm:min-h-[430px] bg-[#ECE3D5]">
        <div aria-hidden className="absolute inset-0 bg-[radial-gradient(circle_at_50%_8%,rgba(255,255,255,0.96),transparent_44%),linear-gradient(180deg,#F7F0E6_0%,#E8DCCC_100%)]" />

        <div className="absolute inset-x-4 top-4 z-20 flex items-center justify-between text-[10px] uppercase tracking-[0.15em]">
          <span className="text-ink/65">{result ? 'Scan complete' : 'Ingredient label in frame'}</span>
          <span className="font-mono text-primary">{scanning ? `OCR ${scanCount}/10` : result ? `${result.count} READ` : 'TEXT FOUND'}</span>
        </div>

        <div className={`absolute inset-x-5 sm:inset-x-8 top-11 bottom-[68px] z-10 flex transition-all duration-700 ease-emil ${result ? 'items-start justify-start gap-3 pt-3 sm:items-center sm:gap-6 sm:pt-0' : 'items-center justify-center'}`}>
          <div className={`shrink-0 transition-all duration-700 ease-emil ${result ? 'absolute left-0 top-3 h-[126px] w-[78px] sm:relative sm:left-auto sm:top-auto sm:h-[250px] sm:w-[158px]' : 'relative h-[300px] w-[190px] sm:h-[330px] sm:w-[210px]'}`}>
            <ProductSprite
              index={1}
              side="back"
              className="h-full w-full drop-shadow-[0_22px_18px_rgba(62,42,30,0.22)]"
            />
            <div
              aria-hidden
              className="absolute inset-x-[24%] top-[23%] bottom-[38%] overflow-hidden rounded-lg border border-primary/45 shadow-[0_0_0_1px_rgba(255,255,255,0.45),0_0_28px_rgba(163,88,72,0.14)]"
            >
              <div className={`absolute inset-x-0 top-0 h-10 bg-gradient-to-b from-transparent via-primary/55 to-transparent ${scanning ? 'animate-[ingredientScan_1.1s_ease-in-out_forwards]' : 'animate-[ingredientScan_2.8s_ease-in-out_infinite]'}`} />
            </div>
          </div>

          {result && (
            <div className="result-reveal ml-[88px] min-w-0 flex-1 rounded-2xl border border-white/70 bg-card/92 p-2.5 shadow-[0_18px_45px_rgba(70,48,32,0.14)] backdrop-blur-sm sm:ml-0 sm:p-4">
              <div className="flex items-end justify-between gap-3 border-b border-border/80 pb-2.5 mb-2.5">
                <div>
                  <div className="text-[8px] sm:text-[9px] uppercase tracking-[0.14em] sm:tracking-[0.17em] text-primary font-semibold">Ingredients found</div>
                  <div className="font-display text-lg sm:text-2xl leading-none mt-1">Your match</div>
                </div>
                <span className="hidden sm:block font-mono text-[9px] text-muted">{result.count} total</span>
              </div>

              {result.watchOut.length > 0 && (
                <div className="mb-2.5">
                  <div className="mb-1.5 flex items-center gap-1.5 whitespace-nowrap text-[8px] sm:text-[9px] uppercase tracking-[0.1em] sm:tracking-[0.14em] font-semibold text-bad-fg">
                    <AlertTriangle size={10} /> Watch out · {result.watchOut.length}
                  </div>
                  <div className="space-y-1">
                    {result.watchOut.slice(0, 2).map((row) => (
                      <div key={row.raw} className="flex items-center justify-between gap-2 rounded-lg border border-bad-fg/15 bg-bad-bg/65 px-2 py-1.5">
                        <span className="truncate text-[10px] sm:text-xs font-semibold text-ink">{row.raw}</span>
                        <span className="hidden sm:inline shrink-0 text-[8px] uppercase tracking-wide text-bad-fg">flagged</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div>
                <div className="mb-1.5 flex items-center gap-1.5 whitespace-nowrap text-[8px] sm:text-[9px] uppercase tracking-[0.1em] sm:tracking-[0.14em] font-semibold text-good-fg">
                  <Check size={10} strokeWidth={2.5} /> Good for you · {result.good.length}
                </div>
                <div className="space-y-1">
                  {result.good.slice(0, 3).map((row) => (
                    <div key={row.raw} className="flex items-center justify-between gap-2 rounded-lg border border-good-fg/15 bg-good-bg/65 px-2 py-1.5">
                      <span className="truncate text-[10px] sm:text-xs font-semibold text-ink">{row.raw}</span>
                      <span className="hidden sm:block truncate text-[9px] text-good-fg/80">{row.info?.benefit ?? 'good match'}</span>
                    </div>
                  ))}
                </div>
              </div>

              {result.restCount > 0 && (
                <div className="mt-2 text-[9px] font-mono text-muted">+ {result.restCount} more with no known issues</div>
              )}
            </div>
          )}
        </div>

        <div className="absolute bottom-4 inset-x-4 z-20 flex items-center justify-between rounded-xl border border-white/60 bg-card/90 px-3 py-2.5 text-[10px] shadow-sm backdrop-blur-sm">
          <span className="text-muted">
            {scanning
              ? `Reading ${scanCount || 1} ingredients from the label…`
              : result
                ? <><span className="sm:hidden">{result.count} ingredients · match ready</span><span className="hidden sm:inline">{result.count} ingredients read — personal match ready</span></>
                : 'Back label detected — ready to read'}
          </span>
          <span className="inline-flex items-center gap-1.5 font-mono text-primary">
            <ScanLine size={11} />
            <span className={result ? 'hidden sm:inline' : ''}>{scanning ? 'SCANNING' : result ? 'VERDICT READY' : 'OCR READY'}</span>
          </span>
        </div>
      </div>
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
                <div className="absolute inset-0" style={{ backfaceVisibility: 'hidden', transform: 'rotateY(180deg)' }}>
                  <ProductSprite
                    index={selectedIndex}
                    side="back"
                    className="h-full w-full drop-shadow-[0_20px_18px_rgba(62,42,30,0.22)]"
                  />
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
