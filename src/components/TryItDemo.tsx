import { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, Beaker, Sparkles, ScanLine, Zap, ShieldCheck, Wand2 } from 'lucide-react';
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

const EMPTY_MAP: Map<string, Culprit> = new Map();

export function TryItDemo() {
  const [input, setInput] = useState('');
  const [analyzed, setAnalyzed] = useState<string | null>(null);
  const [scanning, setScanning] = useState(false);
  const [showResult, setShowResult] = useState(false);
  const [typingSample, setTypingSample] = useState(false);
  const [scanCount, setScanCount] = useState(0);
  const [verdictGlow, setVerdictGlow] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const result = useMemo(() => {
    if (!analyzed) return null;
    const parsed = parseInci(analyzed);
    if (parsed.length === 0) return null;
    const buckets = categorizeIngredients(parsed, EMPTY_MAP);
    const verdict = generateVerdict(buckets);
    return { buckets, verdict, count: parsed.length };
  }, [analyzed]);

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

          <h3 className="font-display text-4xl md:text-5xl mb-4 leading-[1.02] tracking-tight">
            Drop in <span className="relative inline-block">
              <span className="relative z-10">any label.</span>
              <span aria-hidden className="absolute inset-x-0 bottom-1 h-2 bg-primary/20 -z-0 rounded-sm" />
            </span>
            <br />
            <span className="italic text-primary font-light">Watch it light up.</span>
          </h3>
          <p className="text-muted text-base md:text-lg mb-5 max-w-[58ch] leading-relaxed">
            Skintel parses every ingredient, cross-checks the trigger database, and renders a verdict —
            <span className="text-ink font-medium"> in under a second.</span>
          </p>

          <div className="flex flex-wrap items-center gap-x-5 gap-y-2 mb-6 text-[11px] uppercase tracking-[0.14em] text-muted/80 font-medium">
            <span className="inline-flex items-center gap-1.5">
              <Zap size={11} className="text-primary" /> &lt; 1s parse
            </span>
            <span className="inline-flex items-center gap-1.5">
              <ShieldCheck size={11} className="text-primary" /> Zero uploads
            </span>
            <span className="inline-flex items-center gap-1.5">
              <Wand2 size={11} className="text-primary" /> 2,400+ markers
            </span>
          </div>

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
            {scanning && (
              <div
                aria-hidden
                className="pointer-events-none absolute inset-0 rounded-xl overflow-hidden"
              >
                <div
                  className="absolute inset-x-0 h-16 bg-gradient-to-b from-transparent via-primary/40 to-transparent"
                  style={{ animation: 'scanline 1.1s ease-in-out forwards' }}
                />
                <div
                  className="absolute inset-x-0 h-8 bg-gradient-to-b from-transparent via-primary/20 to-transparent"
                  style={{ animation: 'scanline 1.1s ease-in-out forwards', animationDelay: '0.15s' }}
                />
              </div>
            )}
            {scanning && (
              <div className="absolute bottom-2 right-3 flex items-center gap-1.5 text-[10px] font-mono text-primary animate-pulse">
                <span className="size-1.5 rounded-full bg-primary animate-ping" />
                Parsing {scanCount} ingredients…
              </div>
            )}
          </div>

          <div className="flex flex-wrap items-center gap-2 mt-4">
            <button
              type="button"
              onClick={() => triggerScan(input.trim())}
              disabled={!input.trim() || scanning || typingSample}
              className="btn-primary active:scale-[0.96] transition-all duration-200 ease-emil disabled:opacity-50 group/btn"
            >
              {scanning ? (
                <>
                  <ScanLine size={14} className="animate-pulse" /> Scanning…
                </>
              ) : (
                <>
                  <Sparkles size={14} className="group-hover/btn:rotate-12 transition-transform duration-300" />
                  Analyze
                </>
              )}
            </button>
            <button
              type="button"
              onClick={loadSample}
              disabled={scanning || typingSample}
              className="btn-secondary active:scale-[0.96] transition-all duration-200 ease-emil disabled:opacity-50"
            >
              Try a sample
            </button>
            {(result || input) && !scanning && !typingSample && (
              <button
                type="button"
                onClick={() => {
                  setInput('');
                  setAnalyzed(null);
                  setShowResult(false);
                }}
                className="text-sm text-muted hover:text-ink transition-colors duration-200 ease-emil px-2 py-1.5"
              >
                Clear
              </button>
            )}
          </div>

          {result && showResult && (
            <div className="mt-7 space-y-3">
              <ResultReveal delay={0} variant="verdict">
                <div className={`transition-all duration-700 ${verdictGlow ? 'verdict-glow' : ''}`}>
                  <VerdictCard verdict={result.verdict} />
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
                  <div className="text-xs text-muted px-1">
                    + {result.buckets.rest.length} more ingredients in everything else
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
