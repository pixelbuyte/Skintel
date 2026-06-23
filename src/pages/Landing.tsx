import { Link } from 'react-router-dom';
import { useEffect, useState } from 'react';
import {
  ArrowRight,
  ChevronDown,
  ScanLine,
  ShieldCheck,
  Sparkles,
  FlaskConical,
  Check,
} from 'lucide-react';
import { TryItDemo } from '@/components/TryItDemo';
import { useInView } from '@/lib/useInView';
import { useFoundingCount } from '@/hooks/useFoundingCount';
import { Tilt3D } from '@/components/Tilt3D';

const FAQS = [
  {
    q: 'How does Skintel know what breaks me out?',
    a: "Tag each product 'worked' or 'broke me out' and paste its INCI list. We cross-reference ingredients to surface what only shows up in your breakouts. Patterns sharpen as you log more.",
  },
  {
    q: 'How many products do I need to log before it works?',
    a: 'Three to five is the sweet spot. You need at least two breakout products before Skintel can find common threads. The more honest tags you add, the cleaner the signal.',
  },
  {
    q: 'Do I need to scan a barcode or take photos?',
    a: 'No. Paste the ingredient list from any product page — Sephora, Ulta, the brand site, the back of the bottle. Skintel normalizes the names automatically. Barcode and label OCR are inside the Pro scanner if you want them.',
  },
  {
    q: 'Is this medical advice?',
    a: "No. Skintel surfaces correlations from products you tag — it's a tracking tool, not a diagnosis. For persistent or severe reactions, see a dermatologist.",
  },
  {
    q: 'Is my data private?',
    a: 'Every row is locked to your account via Postgres row-level security. We never sell your data or share it with brands. Export everything as JSON or wipe your account anytime from Settings.',
  },
  {
    q: 'What do I get for $20?',
    a: 'Six months of full Pro access — unlimited products and scans, barcode + label OCR scanner, routine builder, breakout journal, and AI verdicts. One payment, no subscription, no renewal.',
  },
];

const STEPS = [
  {
    n: '01',
    icon: <FlaskConical size={20} />,
    title: 'Log your routine',
    body: "Add the 3-5 products you're actually using. Paste the ingredient list, and Skintel parses the INCI so you don't have to.",
    detail: ['brand', 'product', 'outcome'],
  },
  {
    n: '02',
    icon: <Sparkles size={20} />,
    title: 'See the pattern',
    body: 'Skintel surfaces the ingredients showing up in your breakout products that never appear in your safe ones.',
    detail: ['bisabolol', 'coconut alkanes', 'linalool'],
  },
  {
    n: '03',
    icon: <ScanLine size={20} />,
    title: 'Check before you buy',
    body: 'Paste any INCI list — from a Sephora page, the back of a bottle, anywhere. Skintel checks every ingredient against your personal trigger map in seconds.',
    detail: ['watch out', 'good for you', 'everything else'],
  },
];

const MARQUEE = [
  { name: 'niacinamide', tone: 'good' },
  { name: 'bisabolol', tone: 'bad' },
  { name: 'glycerin', tone: 'good' },
  { name: 'fragrance', tone: 'bad' },
  { name: 'ceramide NP', tone: 'good' },
  { name: 'linalool', tone: 'bad' },
  { name: 'panthenol', tone: 'good' },
  { name: 'coconut alkanes', tone: 'bad' },
  { name: 'centella asiatica', tone: 'good' },
  { name: 'limonene', tone: 'bad' },
  { name: 'squalane', tone: 'good' },
  { name: 'sodium hyaluronate', tone: 'good' },
] as const;

type RevealVariant = 'up' | 'left' | 'right' | 'zoom' | 'tilt' | 'rise';

function FadeUp({
  children,
  delay = 0,
  variant = 'up',
}: {
  children: React.ReactNode;
  delay?: number;
  variant?: RevealVariant;
}) {
  const { ref, inView } = useInView<HTMLDivElement>({ threshold: 0.12 });
  return (
    <div
      ref={ref}
      className={`reveal reveal-${variant}${inView ? ' in-view' : ''}`}
      style={{ transitionDelay: inView ? `${delay}ms` : '0ms' }}
    >
      {children}
    </div>
  );
}

function AppleLogo({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 384 512" fill="currentColor" aria-hidden>
      <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z" />
    </svg>
  );
}

function AppStoreBadge({ subtitle = 'Coming to the' }: { subtitle?: string }) {
  return (
    <div className="inline-flex items-center gap-3 bg-ink text-bg px-5 py-3 rounded-2xl border border-bg/10 hover:border-bg/25 transition-colors duration-200">
      <AppleLogo size={28} />
      <div className="text-left leading-tight">
        <div className="text-[10px] uppercase tracking-[0.18em] opacity-80">{subtitle}</div>
        <div className="font-display text-xl leading-tight">App Store</div>
      </div>
    </div>
  );
}

function GooglePlayLogo({ size = 22 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 512 512" fill="currentColor" aria-hidden>
      <path d="M325.3 234.3L104.6 13l280.8 161.2-60.1 60.1zM47 0C34 6.8 25.3 19.2 25.3 35.3v441.3c0 16.1 8.7 28.5 21.7 35.3l256.6-256L47 0zm425.2 225.6l-58.9-34.1-65.7 64.5 65.7 64.5 60.1-34.1c18-14.3 18-46.5-1.2-60.8zM104.6 499l280.8-161.2-60.1-60.1L104.6 499z" />
    </svg>
  );
}

function PlayStoreBadge({ subtitle = 'Coming to' }: { subtitle?: string }) {
  return (
    <div className="inline-flex items-center gap-3 bg-ink text-bg px-5 py-3 rounded-2xl border border-bg/10 hover:border-bg/25 transition-colors duration-200">
      <GooglePlayLogo size={26} />
      <div className="text-left leading-tight">
        <div className="text-[10px] uppercase tracking-[0.18em] opacity-80">{subtitle}</div>
        <div className="font-display text-xl leading-tight">Google Play</div>
      </div>
    </div>
  );
}

type Scene =
  | 'scanner'
  | 'scanning'
  | 'analyzing'
  | 'verdict'
  | 'dashboard'
  | 'routine'
  | 'journal'
  | 'recommend';

function PhoneMockup() {
  const [scene, setScene] = useState<Scene>('scanner');

  useEffect(() => {
    const timeline: Array<[Scene, number]> = [
      ['scanner', 2000],
      ['scanning', 2200],
      ['analyzing', 1700],
      ['verdict', 3600],
      ['dashboard', 3400],
      ['routine', 3200],
      ['journal', 3200],
      ['recommend', 3400],
    ];
    let i = 0;
    let id: number;
    const step = () => {
      setScene(timeline[i][0]);
      id = window.setTimeout(() => {
        i = (i + 1) % timeline.length;
        step();
      }, timeline[i][1]);
    };
    step();
    return () => window.clearTimeout(id);
  }, []);

  return (
    <div className="relative mx-auto" style={{ maxWidth: 252 }}>
      {/* outer halo */}
      <div
        aria-hidden
        className="absolute -inset-12 bg-primary/22 blur-[68px] rounded-full pointer-events-none"
      />
      {/* drop shadow under phone */}
      <div
        aria-hidden
        className="absolute left-1/2 -translate-x-1/2 -bottom-6 w-3/4 h-6 bg-ink/40 blur-2xl rounded-full pointer-events-none"
      />

      {/* side buttons: left */}
      <div aria-hidden className="absolute -left-[3px] top-[14%] w-[3px] h-6 rounded-l-sm bg-gradient-to-r from-ink/90 to-ink/60 z-0" />
      <div aria-hidden className="absolute -left-[3px] top-[22%] w-[3px] h-10 rounded-l-sm bg-gradient-to-r from-ink/90 to-ink/60 z-0" />
      <div aria-hidden className="absolute -left-[3px] top-[33%] w-[3px] h-10 rounded-l-sm bg-gradient-to-r from-ink/90 to-ink/60 z-0" />
      {/* side button: right (power) */}
      <div aria-hidden className="absolute -right-[3px] top-[26%] w-[3px] h-14 rounded-r-sm bg-gradient-to-l from-ink/90 to-ink/60 z-0" />

      {/* phone body — titanium frame */}
      <div
        className="relative aspect-[9/19.5] rounded-[44px] p-[3px] z-10"
        style={{
          background:
            'linear-gradient(140deg, #2a2520 0%, #1a1614 18%, #0d0a08 32%, #1a1614 52%, #2a2520 70%, #0d0a08 100%)',
          boxShadow:
            '0 36px 70px -18px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.04) inset, 0 1px 0 0 rgba(255,255,255,0.08) inset, 0 -1px 0 0 rgba(0,0,0,0.5) inset',
        }}
      >
        {/* inner bezel ring */}
        <div className="relative aspect-[9/19.5] rounded-[41px] bg-ink p-[6px] overflow-hidden">
          {/* glass screen */}
          <div className="relative h-full w-full rounded-[35px] bg-bg overflow-hidden flex flex-col text-ink">
            {/* status bar: time + indicators */}
            <div className="relative h-[26px] px-5 pt-1.5 flex items-center justify-between text-ink z-10">
              <div className="font-display text-[10px] leading-none font-semibold">9:41</div>
              <div className="flex items-center gap-1">
                {/* signal bars */}
                <div className="flex items-end gap-[1px]">
                  <span className="w-[2px] h-[3px] bg-ink rounded-sm" />
                  <span className="w-[2px] h-[4px] bg-ink rounded-sm" />
                  <span className="w-[2px] h-[5px] bg-ink rounded-sm" />
                  <span className="w-[2px] h-[6px] bg-ink rounded-sm" />
                </div>
                {/* wifi */}
                <svg width="9" height="7" viewBox="0 0 16 12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M1 4c4-3.5 10-3.5 14 0" />
                  <path d="M3.5 6.5c2.5-2 6.5-2 9 0" />
                  <path d="M6 9c1-1 3-1 4 0" />
                  <circle cx="8" cy="11" r="0.5" fill="currentColor" />
                </svg>
                {/* battery */}
                <div className="flex items-center">
                  <div className="w-5 h-2.5 rounded-[2px] border border-ink/80 relative p-[1px]">
                    <div className="absolute inset-[1px] right-[5px] bg-ink rounded-[1px]" />
                  </div>
                  <div className="w-[1px] h-1 bg-ink/80 rounded-r-sm" />
                </div>
              </div>
            </div>

            {/* Dynamic Island */}
            <div
              aria-hidden
              className="absolute top-[7px] left-1/2 -translate-x-1/2 z-20"
              style={{
                width: 78,
                height: 22,
                borderRadius: 999,
                background: '#000',
                boxShadow: '0 0 0 1px rgba(255,255,255,0.04), 0 2px 6px rgba(0,0,0,0.4) inset',
              }}
            >
              {/* camera dot */}
              <div className="absolute right-2 top-1/2 -translate-y-1/2 size-2 rounded-full bg-[#0a0a14]">
                <div className="absolute inset-[2px] rounded-full bg-gradient-to-br from-[#1a2030] to-[#050510]" />
                <div className="absolute top-[1px] left-[1px] size-[2px] rounded-full bg-white/30" />
              </div>
              {/* face-id sensor dot */}
              <div className="absolute left-2 top-1/2 -translate-y-1/2 size-1 rounded-full bg-ink/80" />
            </div>

            {/* brand header (smaller now since status bar took top) */}
            <div className="px-3 pt-1 pb-1 flex items-center justify-between">
              <div className="font-display text-[11px] leading-none">
                Skintel<span className="text-primary">.</span>
              </div>
              <div className="flex items-center gap-1">
                <div className="text-[7px] uppercase tracking-wider text-muted leading-none font-semibold">Pro</div>
                <div className="size-4 rounded-full bg-gradient-to-br from-primary/30 to-primary/10 border border-border" />
              </div>
            </div>

            {/* scene area */}
            <div className="relative flex-1 min-h-0">
              <SceneScanner active={scene === 'scanner'} />
              <SceneScanning active={scene === 'scanning'} />
              <SceneAnalyzing active={scene === 'analyzing'} />
              <SceneVerdict active={scene === 'verdict'} />
              <SceneDashboard active={scene === 'dashboard'} />
              <SceneRoutine active={scene === 'routine'} />
              <SceneJournal active={scene === 'journal'} />
              <SceneRecommend active={scene === 'recommend'} />
            </div>

            {/* tab bar */}
            <div className="px-2.5 pb-1.5 pt-1.5 space-y-1">
              <PhoneTabBar scene={scene} />
            </div>

            {/* home indicator */}
            <div className="pb-1.5 flex items-center justify-center">
              <div className="h-[3px] w-20 rounded-full bg-ink/40" />
            </div>

            {/* screen glare overlay */}
            <div
              aria-hidden
              className="pointer-events-none absolute inset-0 rounded-[35px]"
              style={{
                background:
                  'linear-gradient(135deg, rgba(255,255,255,0.10) 0%, rgba(255,255,255,0) 22%, rgba(255,255,255,0) 78%, rgba(255,255,255,0.05) 100%)',
              }}
            />
            {/* top inner shadow under island */}
            <div
              aria-hidden
              className="pointer-events-none absolute top-0 inset-x-0 h-8 rounded-t-[35px]"
              style={{
                background: 'linear-gradient(180deg, rgba(0,0,0,0.06), transparent)',
              }}
            />
          </div>
        </div>

        {/* frame outer highlight stroke */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 rounded-[44px]"
          style={{
            boxShadow:
              '0 0 0 0.5px rgba(255,255,255,0.18) inset, 0 0 0 1.5px rgba(0,0,0,0.6)',
          }}
        />
      </div>
    </div>
  );
}

function SceneWrap({ active, children }: { active: boolean; children: React.ReactNode }) {
  return (
    <div
      className={`absolute inset-0 px-2.5 pb-2 flex flex-col transition-all duration-500 ease-emil ${
        active ? 'opacity-100 translate-y-0 pointer-events-auto' : 'opacity-0 translate-y-1 pointer-events-none'
      }`}
    >
      {children}
    </div>
  );
}

function SceneScanner({ active }: { active: boolean }) {
  return (
    <SceneWrap active={active}>
      <div className="text-[7px] uppercase tracking-wider text-muted/70 leading-none px-0.5 mb-1.5">
        Scanner
      </div>
      <div className="relative flex-1 rounded-lg bg-ink overflow-hidden">
        <div
          aria-hidden
          className="absolute inset-0"
          style={{
            background:
              'radial-gradient(circle at 50% 40%, rgba(163,88,72,0.18), transparent 60%), repeating-linear-gradient(45deg, rgba(255,255,255,0.02) 0 6px, transparent 6px 12px)',
          }}
        />
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="relative size-[88px]">
            <div className="absolute -top-1 -left-1 size-3 border-t-2 border-l-2 border-primary rounded-tl" />
            <div className="absolute -top-1 -right-1 size-3 border-t-2 border-r-2 border-primary rounded-tr" />
            <div className="absolute -bottom-1 -left-1 size-3 border-b-2 border-l-2 border-primary rounded-bl" />
            <div className="absolute -bottom-1 -right-1 size-3 border-b-2 border-r-2 border-primary rounded-br" />
            <div className="absolute inset-2 rounded bg-card/5 border border-bg/10" />
          </div>
        </div>
        <div className="absolute bottom-2 inset-x-2 text-center">
          <div className="font-mono text-[7px] text-primary uppercase tracking-wider animate-pulse">
            Align barcode
          </div>
        </div>
      </div>
      <div className="mt-1.5 rounded-md bg-primary text-card flex items-center justify-center py-1 font-medium text-[8.5px]">
        Tap to scan
      </div>
    </SceneWrap>
  );
}

function SceneScanning({ active }: { active: boolean }) {
  return (
    <SceneWrap active={active}>
      <div className="text-[7px] uppercase tracking-wider text-primary leading-none px-0.5 mb-1.5">
        Scanning…
      </div>
      <div className="relative flex-1 rounded-lg bg-ink overflow-hidden">
        <div aria-hidden className="absolute inset-0 bg-gradient-to-b from-transparent via-primary/5 to-transparent" />
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="relative">
            <div className="flex items-end gap-[1.5px] h-12 px-2 bg-bg/95 rounded">
              {[3, 1, 4, 2, 1, 5, 1, 3, 2, 4, 1, 2, 5, 1, 3, 2, 1, 4, 2, 1].map((w, i) => (
                <span key={i} className="bg-ink h-full" style={{ width: w }} />
              ))}
            </div>
            <div className="text-center font-mono text-[7px] text-muted mt-1">8 904781 234567</div>
          </div>
        </div>
        {active && (
          <div
            aria-hidden
            className="absolute inset-x-0 h-1 bg-primary shadow-[0_0_12px_rgba(163,88,72,0.9)]"
            style={{ animation: 'sceneScan 1.6s ease-in-out infinite' }}
          />
        )}
        <div className="absolute -top-px -left-px size-2.5 border-t-2 border-l-2 border-primary" />
        <div className="absolute -top-px -right-px size-2.5 border-t-2 border-r-2 border-primary" />
        <div className="absolute -bottom-px -left-px size-2.5 border-b-2 border-l-2 border-primary" />
        <div className="absolute -bottom-px -right-px size-2.5 border-b-2 border-r-2 border-primary" />
      </div>
      <div className="mt-1.5 rounded-md bg-card border border-primary/30 flex items-center justify-between px-2 py-1">
        <span className="font-mono text-[7px] text-muted uppercase">Reading EAN-13</span>
        <span className="flex gap-0.5">
          <span className="size-1 rounded-full bg-primary animate-pulse" />
          <span className="size-1 rounded-full bg-primary animate-pulse" style={{ animationDelay: '120ms' }} />
          <span className="size-1 rounded-full bg-primary animate-pulse" style={{ animationDelay: '240ms' }} />
        </span>
      </div>
    </SceneWrap>
  );
}

function SceneAnalyzing({ active }: { active: boolean }) {
  return (
    <SceneWrap active={active}>
      <div className="text-[7px] uppercase tracking-wider text-primary leading-none px-0.5 mb-1.5">
        Drunk Elephant B-Hydra
      </div>
      <div className="relative flex-1 rounded-lg bg-card border border-border p-2 overflow-hidden">
        <div className="flex items-center gap-2 mb-2">
          <div className="relative size-7">
            <div className="absolute inset-0 rounded-full border-2 border-primary/15" />
            <div
              className="absolute inset-0 rounded-full border-2 border-primary border-r-transparent"
              style={{ animation: 'demoSpin 1s linear infinite' }}
            />
          </div>
          <div className="flex-1">
            <div className="font-display text-[10px] leading-none">Analyzing INCI</div>
            <div className="text-[7px] text-muted mt-0.5">17 ingredients</div>
          </div>
        </div>
        <div className="space-y-0.5">
          {['Aqua', 'Glycerin', 'Niacinamide', 'Bisabolol', 'Coconut Alkanes', 'Linalool', 'Ceramide NP', 'Panthenol'].map((ing, i) => (
            <div
              key={ing}
              className="font-mono text-[7.5px] text-ink/70 leading-tight opacity-0"
              style={active ? { animation: `streamIn 200ms ease-out forwards`, animationDelay: `${i * 140}ms` } : undefined}
            >
              › {ing}
            </div>
          ))}
        </div>
      </div>
    </SceneWrap>
  );
}

function SceneVerdict({ active }: { active: boolean }) {
  return (
    <SceneWrap active={active}>
      <div className="rounded-lg bg-bad-bg/70 border border-bad-fg/15 px-2 py-1.5 mb-1.5">
        <div className="flex items-center justify-between">
          <div className="font-display text-[11px] text-bad-fg leading-none">2 triggers found</div>
          <div className="text-[7px] font-mono text-bad-fg/70">SKIP</div>
        </div>
        <div className="text-[8px] text-bad-fg/80 leading-tight mt-0.5">B-Hydra Intensive Hydration</div>
      </div>

      <div className="text-[7px] uppercase tracking-wider text-muted/70 leading-none px-0.5 mb-1">
        Watch out
      </div>
      <div className="space-y-1 mb-1.5">
        {[
          ['Bisabolol', '3×'],
          ['Coconut Alkanes', '3×'],
          ['Linalool', '2×'],
        ].map(([n, c], i) => (
          <div
            key={n}
            className="flex items-center justify-between rounded-md bg-bad-bg/60 border border-bad-fg/15 px-1.5 py-0.5 opacity-0"
            style={active ? { animation: 'streamIn 250ms ease-out forwards', animationDelay: `${i * 80}ms` } : undefined}
          >
            <span className="font-mono text-[8px]">{n}</span>
            <span className="text-[7px] font-mono text-bad-fg/80">{c}</span>
          </div>
        ))}
      </div>

      <div className="text-[7px] uppercase tracking-wider text-muted/70 leading-none px-0.5 mb-1">
        Good for you
      </div>
      <div className="space-y-1 flex-1">
        {[
          ['Niacinamide', 'barrier'],
          ['Glycerin', 'humectant'],
          ['Ceramide NP', 'barrier'],
        ].map(([n, t], i) => (
          <div
            key={n}
            className="flex items-center justify-between rounded-md bg-good-bg/60 border border-good-fg/15 px-1.5 py-0.5 opacity-0"
            style={active ? { animation: 'streamIn 250ms ease-out forwards', animationDelay: `${320 + i * 80}ms` } : undefined}
          >
            <span className="font-mono text-[8px]">{n}</span>
            <span className="text-[7px] text-good-fg/80">{t}</span>
          </div>
        ))}
      </div>
    </SceneWrap>
  );
}

function PhoneTabBar({ scene }: { scene: Scene }) {
  const tab =
    scene === 'scanner' || scene === 'scanning' || scene === 'analyzing'
      ? 'scan'
      : scene === 'verdict'
        ? 'scan'
        : scene === 'dashboard' || scene === 'recommend'
          ? 'home'
          : scene === 'routine'
            ? 'routine'
            : 'journal';
  const tabs: Array<{ id: string; label: string; icon: React.ReactNode }> = [
    {
      id: 'home',
      label: 'Home',
      icon: (
        <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 12l9-9 9 9" />
          <path d="M5 10v10h14V10" />
        </svg>
      ),
    },
    {
      id: 'scan',
      label: 'Scan',
      icon: (
        <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M4 7V4h3" />
          <path d="M17 4h3v3" />
          <path d="M20 17v3h-3" />
          <path d="M7 20H4v-3" />
          <line x1="4" y1="12" x2="20" y2="12" />
        </svg>
      ),
    },
    {
      id: 'routine',
      label: 'Routine',
      icon: (
        <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="12" cy="12" r="9" />
          <path d="M12 7v5l3 2" />
        </svg>
      ),
    },
    {
      id: 'journal',
      label: 'Journal',
      icon: (
        <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M4 4h14a2 2 0 0 1 2 2v14" />
          <path d="M4 4v16h14" />
          <path d="M8 8h8M8 12h8M8 16h5" />
        </svg>
      ),
    },
  ];
  return (
    <div className="flex items-center justify-around rounded-lg bg-card border border-border py-1 px-1">
      {tabs.map((t) => {
        const active = t.id === tab;
        return (
          <div
            key={t.id}
            className={`flex flex-col items-center gap-0.5 px-1.5 py-0.5 rounded-md transition-all duration-300 ${
              active ? 'text-primary bg-primary/10' : 'text-muted/60'
            }`}
          >
            {t.icon}
            <span className="text-[6px] uppercase tracking-wider leading-none font-medium">{t.label}</span>
          </div>
        );
      })}
    </div>
  );
}

function SceneDashboard({ active }: { active: boolean }) {
  return (
    <SceneWrap active={active}>
      <div className="flex items-center justify-between mb-1.5 px-0.5">
        <div>
          <div className="text-[7px] uppercase tracking-wider text-muted/70 leading-none">Today</div>
          <div className="font-display text-[11px] leading-tight">Your skin map</div>
        </div>
        <div className="size-5 rounded-full bg-primary/15 flex items-center justify-center text-primary">
          <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M9.94 14.34l-3.18-3.18-1.41 1.41 4.59 4.59 9.36-9.36-1.41-1.41z" />
          </svg>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-1 mb-1.5">
        {[
          ['12', 'Products', 'text-ink'],
          ['3', 'Triggers', 'text-bad-fg'],
          ['9', 'Safe', 'text-good-fg'],
        ].map(([n, l, c], i) => (
          <div
            key={l}
            className="rounded-md bg-card border border-border px-1 py-1 text-center opacity-0"
            style={active ? { animation: 'streamIn 240ms ease-out forwards', animationDelay: `${i * 80}ms` } : undefined}
          >
            <div className={`font-display text-[12px] leading-none ${c}`}>{n}</div>
            <div className="text-[6.5px] uppercase tracking-wider text-muted leading-none mt-0.5">{l}</div>
          </div>
        ))}
      </div>

      <div className="text-[7px] uppercase tracking-wider text-muted/70 leading-none px-0.5 mb-1">
        Top triggers
      </div>
      <div className="space-y-0.5 flex-1">
        {[
          ['Bisabolol', '5×'],
          ['Coconut Alkanes', '4×'],
          ['Linalool', '3×'],
          ['Limonene', '2×'],
        ].map(([n, c], i) => (
          <div
            key={n}
            className="flex items-center justify-between rounded-md bg-bad-bg/40 border border-bad-fg/15 px-1.5 py-0.5 opacity-0"
            style={active ? { animation: 'streamIn 220ms ease-out forwards', animationDelay: `${280 + i * 70}ms` } : undefined}
          >
            <span className="font-mono text-[8px]">{n}</span>
            <span className="text-[7px] font-mono text-bad-fg/80">{c}</span>
          </div>
        ))}
      </div>
    </SceneWrap>
  );
}

function SceneRoutine({ active }: { active: boolean }) {
  return (
    <SceneWrap active={active}>
      <div className="flex items-center justify-between mb-1.5 px-0.5">
        <div className="font-display text-[11px] leading-none">Routine</div>
        <div className="text-[7px] font-mono text-muted uppercase">Sun · 8:42a</div>
      </div>

      <div className="rounded-lg bg-card border border-border p-1.5 mb-1">
        <div className="flex items-center justify-between mb-1">
          <div className="flex items-center gap-1">
            <div className="size-3 rounded-full bg-primary/20 flex items-center justify-center text-primary">
              <svg width="6" height="6" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="5" /></svg>
            </div>
            <span className="text-[8px] font-medium uppercase tracking-wider">AM</span>
          </div>
          <span className="text-[7px] font-mono text-good-fg">3/3</span>
        </div>
        <div className="space-y-0.5">
          {['Gentle cleanser', 'Niacinamide serum', 'SPF 50'].map((step, i) => (
            <div
              key={step}
              className="flex items-center gap-1 opacity-0"
              style={active ? { animation: 'streamIn 220ms ease-out forwards', animationDelay: `${i * 90}ms` } : undefined}
            >
              <div className="size-2 rounded-full bg-good-fg/80 flex items-center justify-center">
                <svg width="5" height="5" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round">
                  <polyline points="5 13 9 17 19 7" />
                </svg>
              </div>
              <span className="text-[7.5px] text-ink/80 leading-tight">{step}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="rounded-lg bg-card border border-border p-1.5 flex-1">
        <div className="flex items-center justify-between mb-1">
          <div className="flex items-center gap-1">
            <div className="size-3 rounded-full bg-ink/80 flex items-center justify-center text-card">
              <svg width="6" height="6" viewBox="0 0 24 24" fill="currentColor"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" /></svg>
            </div>
            <span className="text-[8px] font-medium uppercase tracking-wider">PM</span>
          </div>
          <span className="text-[7px] font-mono text-primary">1/3</span>
        </div>
        <div className="space-y-0.5">
          {[
            ['Oil cleanser', true],
            ['Retinol', false],
            ['Ceramide cream', false],
          ].map(([step, done], i) => (
            <div
              key={String(step)}
              className="flex items-center gap-1 opacity-0"
              style={active ? { animation: 'streamIn 220ms ease-out forwards', animationDelay: `${320 + i * 90}ms` } : undefined}
            >
              <div className={`size-2 rounded-full border ${done ? 'bg-good-fg/80 border-good-fg/80' : 'border-muted/40'}`} />
              <span className={`text-[7.5px] leading-tight ${done ? 'text-ink/80' : 'text-muted'}`}>{String(step)}</span>
            </div>
          ))}
        </div>
      </div>
    </SceneWrap>
  );
}

function SceneJournal({ active }: { active: boolean }) {
  return (
    <SceneWrap active={active}>
      <div className="flex items-center justify-between mb-1.5 px-0.5">
        <div className="font-display text-[11px] leading-none">Journal</div>
        <div className="size-4 rounded-full bg-primary text-card flex items-center justify-center">
          <svg width="7" height="7" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round">
            <line x1="12" y1="5" x2="12" y2="19" />
            <line x1="5" y1="12" x2="19" y2="12" />
          </svg>
        </div>
      </div>

      <div
        className="rounded-lg bg-card border border-border p-1.5 mb-1 opacity-0"
        style={active ? { animation: 'streamIn 280ms ease-out forwards' } : undefined}
      >
        <div className="flex items-start gap-1.5">
          <div className="size-8 rounded bg-gradient-to-br from-primary/30 via-primary/10 to-bg border border-border flex items-center justify-center text-primary">
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="5" width="18" height="14" rx="2" />
              <circle cx="12" cy="12" r="3" />
            </svg>
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between">
              <div className="text-[8px] font-medium leading-none">Today</div>
              <div className="text-[6.5px] font-mono uppercase tracking-wider text-bad-fg bg-bad-bg/60 px-1 py-0.5 rounded">Flare</div>
            </div>
            <div className="text-[7px] text-muted mt-0.5 leading-tight">Cheek + jawline · day 2</div>
            <div className="flex flex-wrap gap-0.5 mt-0.5">
              {['itchy', 'red'].map((t) => (
                <span key={t} className="text-[6px] font-mono uppercase px-1 py-px rounded bg-bg border border-border">
                  {t}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>

      {[
        ['Fri', 'clear', 'good'],
        ['Thu', 'clear', 'good'],
        ['Wed', 'small bump', 'mid'],
      ].map(([d, n, tone], i) => (
        <div
          key={String(d)}
          className={`flex items-center justify-between rounded-md px-1.5 py-0.5 mb-0.5 opacity-0 ${
            tone === 'good' ? 'bg-good-bg/40 border border-good-fg/15' : 'bg-card border border-border'
          }`}
          style={active ? { animation: 'streamIn 220ms ease-out forwards', animationDelay: `${200 + i * 90}ms` } : undefined}
        >
          <span className="font-mono text-[7px] text-muted uppercase">{d}</span>
          <span className="text-[7.5px] text-ink/80">{n}</span>
        </div>
      ))}
    </SceneWrap>
  );
}

function SceneRecommend({ active }: { active: boolean }) {
  return (
    <SceneWrap active={active}>
      <div className="text-[7px] uppercase tracking-wider text-primary leading-none px-0.5 mb-1.5">
        Should I buy this?
      </div>

      <div className="rounded-lg bg-card border border-border p-1.5 mb-1.5">
        <div className="flex items-center gap-1.5">
          <div className="size-8 rounded bg-gradient-to-br from-primary/25 to-bg border border-border" />
          <div className="flex-1 min-w-0">
            <div className="font-display text-[9px] leading-tight">CeraVe AM Lotion</div>
            <div className="text-[7px] text-muted">Moisturizer · $14</div>
          </div>
        </div>
      </div>

      <div
        className="rounded-lg bg-good-bg/60 border border-good-fg/20 px-1.5 py-1 mb-1 opacity-0"
        style={active ? { animation: 'streamIn 260ms ease-out forwards' } : undefined}
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1">
            <div className="size-2.5 rounded-full bg-good-fg flex items-center justify-center">
              <svg width="6" height="6" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round">
                <polyline points="5 13 9 17 19 7" />
              </svg>
            </div>
            <div className="font-display text-[9.5px] text-good-fg leading-none">Safe for you</div>
          </div>
          <div className="text-[6.5px] font-mono text-good-fg/80 uppercase">0 triggers</div>
        </div>
        <div className="text-[7px] text-good-fg/80 leading-tight mt-0.5">Ceramides + niacinamide. SPF 30.</div>
      </div>

      <div className="text-[7px] uppercase tracking-wider text-muted/70 leading-none px-0.5 mb-1">
        Why
      </div>
      <div className="space-y-0.5 flex-1">
        {[
          ['Ceramide NP', 'barrier'],
          ['Niacinamide', 'calms'],
          ['No fragrance', 'safe'],
        ].map(([n, t], i) => (
          <div
            key={n}
            className="flex items-center justify-between rounded-md bg-good-bg/40 border border-good-fg/15 px-1.5 py-0.5 opacity-0"
            style={active ? { animation: 'streamIn 220ms ease-out forwards', animationDelay: `${260 + i * 80}ms` } : undefined}
          >
            <span className="font-mono text-[8px]">{n}</span>
            <span className="text-[7px] text-good-fg/80">{t}</span>
          </div>
        ))}
      </div>
    </SceneWrap>
  );
}

function ComingSoonWaitlist() {
  const { remaining, total } = useFoundingCount();
  const [email, setEmail] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [joined, setJoined] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    const clean = email.trim().toLowerCase();
    if (!clean) return;
    setSubmitting(true);
    try {
      let ref: string | null = null;
      try { ref = localStorage.getItem('skintel_ref'); } catch { /* storage unavailable */ }
      const res = await fetch('/api/waitlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: clean, source: ref ? `landing:${ref}` : 'landing' }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.error ?? 'Signup failed');
      setJoined(true);
    } catch (e: any) {
      setErr(e?.message ?? 'Something went wrong');
    } finally {
      setSubmitting(false);
    }
  }

  const seatsRemaining = typeof remaining === 'number' ? remaining : null;
  const pctLeft =
    seatsRemaining !== null ? Math.max(0, Math.min(100, (seatsRemaining / total) * 100)) : 100;

  return (
    <div className="relative overflow-hidden rounded-[32px] bg-ink text-bg shadow-[0_40px_80px_-30px_rgba(0,0,0,0.5)]">
      <div
        aria-hidden
        className="absolute inset-0 opacity-[0.04]"
        style={{
          backgroundImage:
            "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/></filter><rect width='100%25' height='100%25' filter='url(%23n)'/></svg>\")",
        }}
      />
      <div
        aria-hidden
        className="absolute -top-40 -left-40 size-[480px] bg-primary/30 blur-[120px] rounded-full"
      />
      <div
        aria-hidden
        className="absolute -bottom-40 -right-40 size-[520px] bg-primary/20 blur-[140px] rounded-full"
      />

      <div className="relative grid lg:grid-cols-[1.2fr_1fr] gap-10 lg:gap-16 p-6 sm:p-12 lg:p-16 items-center">
        <div>
          <div className="inline-flex items-center gap-2.5 bg-bg/10 backdrop-blur border border-bg/15 px-3.5 py-1.5 rounded-full mb-6">
            <AppleLogo size={13} />
            <span className="text-bg/40">·</span>
            <GooglePlayLogo size={14} />
            <span className="text-xs uppercase tracking-[0.18em] font-medium ml-1">
              Coming Soon · iOS &amp; Android
            </span>
          </div>

          <h2 className="font-display text-[2.5rem] sm:text-5xl lg:text-[3.75rem] leading-[1.02] tracking-tight mb-5">
            Skintel mobile.
            <br />
            <span className="italic text-primary">Launching this summer.</span>
          </h2>

          <p className="text-bg/70 text-lg max-w-[52ch] leading-relaxed mb-8">
            Scan any product at the store. Live trigger alerts on every label.
            Be first in line — or lock in <span className="text-bg font-semibold">6 months of Pro for just $20</span>{' '}
            before the founding spots are gone.
          </p>

          <div className="mb-8">
            <div className="flex items-baseline justify-between mb-2">
              <span className="text-xs uppercase tracking-[0.16em] text-bg/60 font-medium">
                Founding member spots
              </span>
              <span className="text-sm font-display">
                {seatsRemaining !== null ? (
                  <>
                    <span className="text-primary font-semibold">{seatsRemaining}</span>
                    <span className="text-bg/50"> / {total} left</span>
                  </>
                ) : (
                  <span className="text-bg/50">{total} total</span>
                )}
              </span>
            </div>
            <div className="h-1.5 w-full rounded-full bg-bg/10 overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-primary to-primary/60 rounded-full transition-[width] duration-700 ease-emil"
                style={{ width: `${pctLeft}%` }}
              />
            </div>
          </div>

          {!joined ? (
            <form onSubmit={submit} className="flex flex-col sm:flex-row gap-3 mb-5">
              <input
                type="email"
                required
                autoComplete="email"
                placeholder="your@email.com"
                className="flex-1 px-4 py-3.5 rounded-xl bg-bg/10 backdrop-blur border border-bg/20 text-bg placeholder:text-bg/40 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={submitting}
              />
              <button
                type="submit"
                disabled={submitting}
                className="px-6 py-3.5 rounded-xl bg-bg text-ink font-medium hover:bg-bg/90 active:scale-[0.97] transition-all duration-150 ease-emil disabled:opacity-60 whitespace-nowrap inline-flex items-center justify-center gap-2"
              >
                {submitting ? 'Joining…' : 'Notify me at launch'}
                {!submitting && <ArrowRight size={16} />}
              </button>
            </form>
          ) : (
            <div className="rounded-xl bg-primary/15 border border-primary/30 p-5 mb-5">
              <div className="font-display text-xl mb-1">✓ You're on the list.</div>
              <div className="text-sm text-bg/80">
                We'll email you the moment Skintel hits the App Store + Google Play.
                Want 6 months of Pro before the price goes up?
              </div>
            </div>
          )}

          {err && (
            <div className="text-sm text-bad-fg mb-4" role="alert">
              {err}
            </div>
          )}

          <div className="flex items-center gap-4 flex-wrap pt-2">
            <Link
              to="/pricing#founding"
              className="inline-flex items-center gap-2 px-6 py-3.5 rounded-xl bg-primary text-card font-semibold hover:bg-primary-hover active:scale-[0.97] transition-all duration-150 ease-emil shadow-[0_10px_30px_-10px_rgba(163,88,72,0.6)]"
            >
              Lock in 6 months — $20 <ArrowRight size={16} />
            </Link>
            <div className="flex items-center gap-2 text-xs text-bg/60">
              <ShieldCheck size={13} />
              One-time payment · 6 months of Pro
            </div>
          </div>

          <div className="mt-6 pt-6 md:mt-10 md:pt-8 border-t border-bg/10 flex items-center gap-3 flex-wrap">
            <AppStoreBadge />
            <PlayStoreBadge />
            <div className="text-xs text-bg/50 max-w-[24ch] leading-relaxed ml-1">
              Pre-launch waitlist.
              <br />
              Web stays live forever.
            </div>
          </div>
        </div>

        <div className="relative hidden lg:block">
          <PhoneMockup />
        </div>
      </div>
    </div>
  );
}

function ScrollProgress() {
  const [p, setP] = useState(0);
  useEffect(() => {
    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const h = document.documentElement;
        const max = h.scrollHeight - h.clientHeight;
        setP(max > 0 ? Math.min(1, h.scrollTop / max) : 0);
      });
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('scroll', onScroll);
    };
  }, []);
  return <div className="scroll-progress" style={{ ['--p' as any]: p }} aria-hidden />;
}

function useParallaxRoot() {
  useEffect(() => {
    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        document.documentElement.style.setProperty('--scrollY', String(window.scrollY));
      });
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('scroll', onScroll);
    };
  }, []);
}

export default function Landing() {
  const [openFaq, setOpenFaq] = useState<number | null>(0);
  const [scrolled, setScrolled] = useState(false);
  useParallaxRoot();

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  // channel attribution: ?ref=tt|reddit|x|… survives into waitlist + signup
  useEffect(() => {
    try {
      const ref = new URLSearchParams(window.location.search).get('ref');
      if (ref) localStorage.setItem('skintel_ref', ref.slice(0, 40));
    } catch { /* storage unavailable (private mode) — skip attribution */ }
  }, []);

  return (
    <div className="min-h-[100dvh] bg-bg text-ink overflow-x-hidden relative">
      <ScrollProgress />
      <div aria-hidden className="pointer-events-none fixed inset-0 bg-grain opacity-[0.03] mix-blend-multiply z-0" />

      <header
        className={`sticky top-0 z-30 transition-colors duration-300 ease-emil ${
          scrolled ? 'bg-bg/85 backdrop-blur-xl border-b border-border/70' : 'bg-transparent'
        }`}
      >
        <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
          <Link to="/" className="font-display text-2xl leading-none">
            Skintel<span className="text-primary">.</span>
          </Link>
          <nav className="flex items-center gap-1 text-sm">
            <Link
              to="/pricing"
              className="px-3 py-2 text-muted hover:text-ink transition-colors duration-200 ease-emil rounded-lg"
            >
              Pricing
            </Link>
            <Link
              to="/login"
              className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
            >
              Start free <ArrowRight size={14} />
            </Link>
          </nav>
        </div>
      </header>

      <section className="relative max-w-6xl mx-auto px-6 pt-8 md:pt-20 pb-12 md:pb-28">
        <div className="grid lg:grid-cols-[1.15fr_1fr] gap-10 lg:gap-16 items-center">
          <div className="animate-rise-in" style={{ animationDelay: '40ms' }}>
            <div className="inline-flex items-center gap-2 text-xs uppercase tracking-[0.14em] text-primary bg-primary/8 border border-primary/15 px-3 py-1.5 rounded-full mb-7">
              <span className="relative flex h-1.5 w-1.5">
                <span className="absolute inline-flex h-full w-full rounded-full bg-primary animate-breathe" />
                <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-primary" />
              </span>
              Personal ingredient intelligence
            </div>

            <h1 className="font-display text-[2.75rem] sm:text-6xl lg:text-[4.25rem] leading-[1.02] tracking-tight mb-6">
              Stop guessing why
              <br />
              your skin <span className="italic text-primary">broke out.</span>
            </h1>

            <p className="text-lg text-muted max-w-[60ch] mb-8 leading-relaxed">
              One hidden ingredient is usually behind it. Log the products you already use, tag
              what broke you out, and Skintel names your personal triggers — so you never buy
              them again.
            </p>

            <div className="flex items-center gap-3 flex-wrap">
              <Link
                to="/login"
                className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
              >
                Find my triggers — free <ArrowRight size={16} />
              </Link>
              <a
                href="#demo"
                className="btn-secondary active:scale-[0.97] transition-transform duration-150 ease-emil"
              >
                Try the live demo ↓
              </a>
            </div>

            <div className="mt-10 flex items-center gap-5 text-xs text-muted flex-wrap">
              <div className="flex items-center gap-1.5">
                <ShieldCheck size={14} className="text-primary/80" />
                Private by default
              </div>
              <div className="h-3 w-px bg-border" />
              <div>First verdict in under a minute</div>
              <div className="h-3 w-px bg-border" />
              <div>No card to start</div>
            </div>
          </div>

          <div className="relative animate-rise-in" style={{ animationDelay: '180ms' }}>
            <div
              aria-hidden
              className="absolute -inset-6 bg-primary/8 blur-3xl rounded-[40px] -z-10"
            />
            <div className="card p-5 sm:p-6 shadow-soft relative overflow-hidden">
              <div
                aria-hidden
                className="pointer-events-none absolute inset-0 rounded-card"
                style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }}
              />
              <div className="flex items-center justify-between mb-4">
                <div className="text-xs uppercase tracking-[0.14em] text-muted font-medium">
                  Live scan
                </div>
                <div className="font-mono text-[10px] text-muted">eucerin · gel cream</div>
              </div>

              <div className="rounded-2xl bg-bad-bg/70 border border-bad-fg/15 p-4 mb-4">
                <div className="font-display text-xl text-bad-fg leading-tight">
                  2 of your triggers found.
                </div>
                <div className="text-xs text-bad-fg/80 mt-1">
                  Skip this one. Both ingredients showed up in your last 3 breakouts.
                </div>
              </div>

              <div className="space-y-3">
                <div>
                  <div className="text-[10px] uppercase tracking-[0.14em] font-medium text-bad-fg mb-2">
                    Watch out · 2
                  </div>
                  <div className="space-y-1.5">
                    {['Bisabolol', 'Coconut Alkanes'].map((row, i) => (
                      <div
                        key={row}
                        className="flex items-center justify-between rounded-xl bg-bad-bg/60 border border-bad-fg/15 px-3 py-2 animate-rise-in"
                        style={{ animationDelay: `${320 + i * 80}ms` }}
                      >
                        <span className="font-mono text-xs">{row}</span>
                        <span className="text-[10px] text-bad-fg/80">in 3 breakouts</span>
                      </div>
                    ))}
                  </div>
                </div>

                <div>
                  <div className="text-[10px] uppercase tracking-[0.14em] font-medium text-good-fg mb-2">
                    Good for your skin · 3
                  </div>
                  <div className="space-y-1.5">
                    {[
                      ['Niacinamide', 'barrier · brightening'],
                      ['Glycerin', 'humectant'],
                      ['Ceramide NP', 'barrier'],
                    ].map(([name, benefit], i) => (
                      <div
                        key={name}
                        className="flex items-center justify-between rounded-xl bg-good-bg/60 border border-good-fg/15 px-3 py-2 animate-rise-in"
                        style={{ animationDelay: `${500 + i * 80}ms` }}
                      >
                        <span className="font-mono text-xs">{name}</span>
                        <span className="text-[10px] text-good-fg/80">{benefit}</span>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="flex items-center justify-between pt-1 text-xs text-muted">
                  <span>+ 11 more in everything else</span>
                  <ChevronDown size={14} />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="demo" className="max-w-3xl mx-auto px-6 pb-10 md:pb-24 scroll-mt-24">
        <FadeUp>
          <TryItDemo />
        </FadeUp>
      </section>

      {/* ── STATS / FEAR SECTION ── */}
      <section className="py-12 md:py-32 px-6 border-y border-border bg-card/20">
        <div className="max-w-6xl mx-auto">
          <FadeUp>
            <div className="inline-flex items-center gap-2 text-[11px] uppercase tracking-[0.22em] text-primary font-semibold mb-6">
              <span className="h-px w-8 bg-primary/40" /> The problem nobody talks about
            </div>
            <h2 className="font-display text-4xl md:text-6xl leading-[0.95] tracking-tight mb-4 max-w-3xl">
              Your skin isn't broken.<br />
              <span className="text-primary italic">Your routine is fighting itself.</span>
            </h2>
            <p className="text-muted text-lg max-w-2xl mb-10 md:mb-16">
              Most people spend years switching products, cutting out actives, going fragrance-free — and still breaking out. The real culprit is almost always one ingredient hiding across multiple products.
            </p>
          </FadeUp>

          <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-6 mb-10 md:mb-16">
            {[
              {
                stat: '50M',
                label: 'Americans deal with acne every year',
                sub: 'American Academy of Dermatology',
                color: 'text-bad-fg',
              },
              {
                stat: '168',
                label: 'Unique ingredients the average person applies daily',
                sub: 'Across cleanser, toner, serum, moisturizer, SPF',
                color: 'text-primary',
              },
              {
                stat: '$400+',
                label: 'Spent on products that don\'t work before finding what does',
                sub: 'U.S. skincare consumer survey avg.',
                color: 'text-bad-fg',
              },
              {
                stat: '1 in 3',
                label: 'People can\'t identify which product caused their reaction',
                sub: 'Because the same ingredient is in multiple products',
                color: 'text-primary',
              },
            ].map((s) => (
              <FadeUp key={s.stat}>
                <div className="card p-4 sm:p-6 h-full flex flex-col gap-3">
                  <span className={`font-display text-4xl sm:text-5xl md:text-6xl tabular-nums ${s.color}`}>{s.stat}</span>
                  <p className="text-sm font-medium leading-snug">{s.label}</p>
                  <p className="text-xs text-muted mt-auto hidden sm:block">{s.sub}</p>
                </div>
              </FadeUp>
            ))}
          </div>

          <FadeUp>
            <div className="card p-6 md:p-12 border-primary/20 bg-primary/5 max-w-4xl">
              <p className="font-display text-2xl md:text-3xl leading-snug mb-4">
                "The average breakout product and the average 'safe' product share <span className="text-primary">12 ingredients in common</span> — which means without tracking, you'll never find the one that's actually doing it."
              </p>
              <p className="text-muted text-sm">That's what Skintel solves. Not with generic databases. With <strong>your</strong> data.</p>
              <Link to="/login" className="btn-primary inline-flex items-center gap-2 mt-6">
                Find my triggers — free <ArrowRight size={14} />
              </Link>
            </div>
          </FadeUp>
        </div>
      </section>

      {/* ── INGREDIENT REALITY STRIP ── */}
      <section className="py-10 md:py-24 px-6 bg-bg">
        <div className="max-w-6xl mx-auto">
          <FadeUp>
            <div className="inline-flex items-center gap-2 text-[11px] uppercase tracking-[0.22em] text-muted font-semibold mb-8">
              <span className="h-px w-8 bg-border" /> Ingredient reality check
            </div>
          </FadeUp>
          <div className="grid grid-cols-2 md:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
            {[
              {
                pct: '67%',
                fact: 'of skincare products contain fragrance',
                context: 'It\'s the #1 cause of allergic contact dermatitis in the US — and it hides under 50+ different names on labels.',
                tone: 'bad',
              },
              {
                pct: '40%+',
                fact: 'of "natural" products contain coconut-derived ingredients',
                context: 'Coconut alkanes, coco-caprylate, caprylic/capric triglyceride — all comedogenic for many skin types. All marketed as gentle.',
                tone: 'bad',
              },
              {
                pct: '6 weeks',
                fact: 'average time to notice a skin reaction',
                context: 'By the time you realize something\'s wrong, you\'ve usually added 2–3 more products. Now you don\'t know which one did it.',
                tone: 'bad',
              },
              {
                pct: '12+',
                fact: 'names parabens can appear under on a single label',
                context: 'Methylparaben, ethylparaben, propylparaben, butylparaben — same family, different names. Easy to miss if you\'re not tracking.',
                tone: 'neutral',
              },
              {
                pct: '85%',
                fact: 'of breakout cases involve an ingredient the person already owned',
                context: 'It\'s rarely the new product. It\'s the old one you never questioned — used daily, assumed safe.',
                tone: 'bad',
              },
              {
                pct: '0',
                fact: 'FDA-required compatibility testing between skincare products',
                context: 'Brands test their products alone. Nobody tests what happens when you layer 5 of them. Your skin does that experiment every morning.',
                tone: 'neutral',
              },
            ].map((item, i) => (
              <FadeUp key={item.pct + i} delay={i * 60}>
                <div className={`card p-4 md:p-6 h-full flex flex-col gap-3 border-l-2 ${item.tone === 'bad' ? 'border-l-bad-fg/50' : 'border-l-border'}`}>
                  <span className={`font-display text-3xl md:text-4xl tabular-nums ${item.tone === 'bad' ? 'text-bad-fg' : 'text-muted'}`}>
                    {item.pct}
                  </span>
                  <p className="font-medium text-sm leading-snug">{item.fact}</p>
                  <p className="text-xs text-muted leading-relaxed mt-auto hidden md:block">{item.context}</p>
                </div>
              </FadeUp>
            ))}
          </div>
        </div>
      </section>

      <section
        aria-label="Ingredients ticker"
        className="border-y border-border bg-card/40 overflow-hidden"
      >
        <div className="relative py-5 group">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-y-0 left-0 w-24 bg-gradient-to-r from-bg to-transparent z-10"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-y-0 right-0 w-24 bg-gradient-to-l from-bg to-transparent z-10"
          />
          <div className="flex gap-3 whitespace-nowrap will-change-transform animate-marquee group-hover:[animation-play-state:paused]">
            {[...MARQUEE, ...MARQUEE, ...MARQUEE].map((m, i) => (
              <span
                key={i}
                className={`font-mono text-xs px-3 py-1 rounded-full border ${
                  m.tone === 'good'
                    ? 'bg-good-bg/40 border-good-fg/15 text-good-fg/90'
                    : 'bg-bad-bg/40 border-bad-fg/15 text-bad-fg/90'
                }`}
              >
                {m.name}
              </span>
            ))}
          </div>
        </div>
      </section>

      <section className="relative max-w-6xl mx-auto px-6 py-12 md:py-32">
        <div
          aria-hidden
          className="pointer-events-none absolute -top-10 -left-20 size-72 bg-primary/8 blur-3xl rounded-full parallax-slow"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute bottom-10 -right-20 size-72 bg-primary/8 blur-3xl rounded-full parallax-med"
        />

        <FadeUp>
          <div className="max-w-2xl mb-10 md:mb-24">
            <div className="inline-flex items-center gap-2 text-[11px] uppercase tracking-[0.22em] text-primary font-semibold mb-4">
              <span className="h-px w-8 bg-primary/40" /> How it works
            </div>
            <h2 className="font-display text-5xl md:text-7xl leading-[0.95] tracking-tight">
              Three steps.
              <br />
              <span className="italic font-light text-primary">Zero detective work.</span>
            </h2>
          </div>
        </FadeUp>

        <ol className="relative space-y-10 md:space-y-28">
          <div
            aria-hidden
            className="hidden md:block absolute left-[60px] top-4 bottom-4 w-px bg-gradient-to-b from-transparent via-primary/30 to-transparent"
          />

          {STEPS.map((s, i) => (
            <FadeUp key={s.n} delay={i * 80} variant={i % 2 === 0 ? 'left' : 'right'}>
              <li className="group relative grid md:grid-cols-[120px_1fr_minmax(0,360px)] gap-x-10 gap-y-6 items-start">
                <div className="relative flex items-baseline gap-3 md:block">
                  <div className="relative">
                    <div
                      className="font-display text-7xl md:text-8xl leading-none bg-clip-text text-transparent transition-all duration-500 ease-emil group-hover:scale-105"
                      style={{
                        backgroundImage:
                          'linear-gradient(135deg, rgba(163,88,72,0.9) 0%, rgba(163,88,72,0.25) 60%, rgba(163,88,72,0.05) 100%)',
                      }}
                    >
                      {s.n}
                    </div>
                    <div
                      aria-hidden
                      className="absolute inset-0 font-display text-7xl md:text-8xl leading-none text-primary/5 select-none translate-x-1 translate-y-1 -z-10"
                    >
                      {s.n}
                    </div>
                  </div>
                  <div className="md:mt-3 inline-flex items-center justify-center size-9 rounded-full bg-primary/10 border border-primary/20 text-primary shadow-[0_0_20px_rgba(163,88,72,0.15)] group-hover:bg-primary group-hover:text-card transition-all duration-400 ease-emil">
                    {s.icon}
                  </div>
                </div>

                <div className="max-w-[55ch] md:pt-3">
                  <h3 className="font-display text-3xl md:text-4xl mb-4 leading-[1.05] tracking-tight">
                    {s.title}
                  </h3>
                  <p className="text-muted text-base md:text-lg leading-relaxed">{s.body}</p>
                </div>

                <div className="md:pt-3">
                  <div className="relative card p-5 overflow-hidden bg-gradient-to-br from-card to-bg/50 border-primary/10 transition-all duration-500 ease-emil group-hover:border-primary/30 group-hover:shadow-[0_20px_60px_-20px_rgba(163,88,72,0.4)] group-hover:-translate-y-1">
                    <div
                      aria-hidden
                      className="absolute -top-12 -right-12 size-32 bg-primary/10 blur-2xl rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-500"
                    />
                    <div className="relative">
                      <div className="text-[10px] uppercase tracking-[0.2em] text-muted/70 font-semibold mb-3">
                        Example
                      </div>
                      <ul className="space-y-2">
                        {s.detail.map((d, di) => (
                          <li
                            key={d}
                            className="flex items-center gap-3 font-mono text-xs"
                            style={{ transitionDelay: `${di * 60}ms` }}
                          >
                            <span className="relative flex h-1.5 w-1.5">
                              <span className="absolute inline-flex h-full w-full rounded-full bg-primary/40 group-hover:animate-ping" />
                              <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-primary" />
                            </span>
                            <span className="text-ink/80 group-hover:text-ink transition-colors duration-300">
                              {d}
                            </span>
                          </li>
                        ))}
                      </ul>
                    </div>
                  </div>
                </div>
              </li>
            </FadeUp>
          ))}
        </ol>
      </section>

      <section id="founding" className="max-w-6xl mx-auto px-6 py-10 md:py-12 scroll-mt-24">
        <FadeUp>
          <ComingSoonWaitlist />
        </FadeUp>
      </section>

      {/* ── $20 FOUNDING DEAL ── */}
      <section className="max-w-6xl mx-auto px-6 py-10 md:py-24">
        <FadeUp>
          <div className="max-w-2xl mb-8 md:mb-16">
            <div className="text-xs uppercase tracking-[0.18em] text-muted font-medium mb-3">
              Founding member offer
            </div>
            <h2 className="font-display text-4xl md:text-5xl leading-tight mb-4">
              Everything unlocked.
              <br />
              <span className="text-primary italic">$20, once.</span>
            </h2>
            <p className="text-muted text-lg max-w-[52ch] leading-relaxed">
              6 months of full Pro access — unlimited scans, AI verdicts, routine builder — locked in before founding spots run out.
            </p>
          </div>
        </FadeUp>

        <FadeUp delay={100}>
          <Tilt3D max={3} lift={6} shine={false} className="max-w-2xl">
            <div className="card p-8 md:p-10 relative overflow-hidden border-primary/30 shadow-soft">
              <div aria-hidden className="absolute -top-20 -right-20 size-64 bg-primary/10 blur-3xl rounded-full" />
              <div aria-hidden className="absolute -bottom-20 -left-20 size-56 bg-primary/6 blur-3xl rounded-full" />
              <div aria-hidden className="pointer-events-none absolute inset-0 rounded-card" style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }} />

              <div className="relative">
                <div className="inline-flex items-center gap-1.5 text-[10px] uppercase tracking-[0.18em] px-2.5 py-1 rounded-full mb-5 font-semibold border text-primary bg-primary/10 border-primary/25 shadow-[0_0_18px_rgba(163,88,72,0.15)]">
                  <Sparkles size={10} />
                  Limited founding offer · 500 spots
                </div>

                <div className="flex items-baseline gap-4 mb-3">
                  <div className="font-display text-7xl leading-none text-primary">$20</div>
                  <div>
                    <div className="text-sm font-medium line-through text-muted/60">$54 regular</div>
                    <div className="text-sm text-muted">6 months of Pro · one payment</div>
                  </div>
                </div>

                <div className="relative mb-7 pl-4 py-2 rounded-r-lg border-l-2 border-primary bg-gradient-to-r from-primary/10 to-transparent">
                  <span aria-hidden className="absolute -left-[6px] top-2 size-2.5 rounded-full bg-primary shadow-[0_0_10px_rgba(163,88,72,0.6)]" />
                  <p className="text-[15px] text-ink/85 italic leading-snug font-serif max-w-[40ch]">
                    "Lock in before the app drops. Founding members get in first — and keep this price forever."
                  </p>
                </div>

                <div className="grid sm:grid-cols-2 gap-2.5 mb-8">
                  {[
                    'Unlimited products + scans',
                    'Full barcode + label OCR scanner',
                    'Routine builder + breakout journal',
                    'AI verdicts on every new launch',
                    'Personal trigger map, kept private',
                    'Founding badge + early iOS access',
                  ].map((f) => (
                    <div key={f} className="flex items-center gap-3 text-sm">
                      <span className="relative shrink-0 size-5">
                        <span aria-hidden className="absolute inset-0 rounded-md rotate-45 bg-gradient-to-br from-primary to-primary-hover shadow-[0_4px_14px_-2px_rgba(163,88,72,0.55)]" />
                        <span className="relative z-10 flex items-center justify-center h-full w-full text-card">
                          <Check size={11} strokeWidth={3.5} />
                        </span>
                      </span>
                      <span className="text-ink/85 leading-snug">{f}</span>
                    </div>
                  ))}
                </div>

                <div className="flex flex-col sm:flex-row gap-3 items-start">
                  <Link
                    to="/pricing#founding"
                    className="btn-primary active:scale-[0.97] hover:scale-[1.02] transition-transform duration-150 ease-emil"
                  >
                    Lock in 6 months — $20 <ArrowRight size={14} />
                  </Link>
                  <div className="flex items-center gap-2 text-xs text-muted sm:self-center">
                    <ShieldCheck size={13} className="text-primary/70" />
                    One-time · no subscription · no renewal
                  </div>
                </div>
              </div>
            </div>
          </Tilt3D>
        </FadeUp>
      </section>

      <section className="max-w-3xl mx-auto px-6 py-10 md:py-24">
        <FadeUp>
          <div className="mb-10">
            <div className="text-xs uppercase tracking-[0.18em] text-muted font-medium mb-3">
              Questions
            </div>
            <h2 className="font-display text-4xl md:text-5xl leading-tight">Good ones, mostly.</h2>
          </div>
        </FadeUp>

        <div className="divide-y divide-border border-y border-border">
          {FAQS.map((f, i) => {
            const open = openFaq === i;
            return (
              <div key={i}>
                <button
                  className="w-full py-5 flex items-start gap-4 text-left group min-h-11"
                  onClick={() => setOpenFaq(open ? null : i)}
                  aria-expanded={open}
                >
                  <span className="font-display text-lg md:text-xl flex-1 leading-snug">
                    {f.q}
                  </span>
                  <ChevronDown
                    size={20}
                    className={`text-muted shrink-0 mt-1 transition-transform duration-300 ease-emil ${
                      open ? 'rotate-180 text-primary' : 'group-hover:text-ink'
                    }`}
                  />
                </button>
                <div
                  className="grid transition-[grid-template-rows] duration-400 ease-emil"
                  style={{ gridTemplateRows: open ? '1fr' : '0fr' }}
                >
                  <div className="overflow-hidden">
                    <p className="text-muted text-base leading-relaxed pb-5 pr-8">{f.a}</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      <footer className="max-w-6xl mx-auto px-6 py-12 border-t border-border text-sm text-muted relative">
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-8 mb-10">
          <div className="sm:col-span-2 md:col-span-1">
            <Link to="/" className="font-display text-2xl text-ink leading-none">
              Skintel<span className="text-primary">.</span>
            </Link>
            <p className="text-muted text-sm mt-3 max-w-[28ch] leading-relaxed">
              Personal ingredient intelligence. Built for people whose skin keeps secrets.
            </p>
          </div>
          <div>
            <div className="text-ink font-medium mb-3">Product</div>
            <ul className="space-y-2">
              <li>
                <Link to="/pricing" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Pricing
                </Link>
              </li>
              <li>
                <Link to="/roadmap" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Roadmap
                </Link>
              </li>
              <li>
                <Link to="/login" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Sign in
                </Link>
              </li>
            </ul>
          </div>
          <div>
            <div className="text-ink font-medium mb-3">Company</div>
            <ul className="space-y-2">
              <li>
                <Link to="/about" className="hover:text-ink transition-colors duration-200 ease-emil">
                  About
                </Link>
              </li>
              <li>
                <Link to="/contact" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Contact
                </Link>
              </li>
            </ul>
          </div>
          <div>
            <div className="text-ink font-medium mb-3">Legal</div>
            <ul className="space-y-2">
              <li>
                <Link to="/privacy" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Privacy
                </Link>
              </li>
              <li>
                <Link to="/terms" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Terms
                </Link>
              </li>
            </ul>
          </div>
        </div>
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 pt-6 border-t border-border">
          <span>© {new Date().getFullYear()} Skintel. All rights reserved.</span>
          <span className="text-xs">Not medical advice. Patterns, not prescriptions.</span>
        </div>
      </footer>
    </div>
  );
}
