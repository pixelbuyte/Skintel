import { Link } from 'react-router-dom';
import { useEffect, useRef, useState } from 'react';
import {
  ArrowRight,
  AlertTriangle,
  ChevronDown,
  ScanLine,
  ShieldCheck,
  Sparkles,
  FlaskConical,
  Check,
  Play,
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
    q: 'Monthly or yearly?',
    a: 'Pro is $9 a month, or $79 a year. The yearly plan saves you two months. Cancel anytime in either — access continues through the current period.',
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

type DemoKey =
  | 'counter'
  | 'pulse'
  | 'verdict'
  | 'download'
  | 'infinity'
  | 'scan'
  | 'calendar'
  | 'check'
  | 'savings'
  | 'mail'
  | 'key'
  | 'lock'
  | 'shield'
  | 'sparkle'
  | 'star'
  | 'dashboard'
  | 'routine'
  | 'journal'
  | 'recommend'
  | 'add-product'
  | 'history'
  | 'login';

type Feature = { text: string; demo: DemoKey };

const PRICING: ReadonlyArray<{
  id: string;
  name: string;
  tagline: string;
  price: string;
  cadence: string;
  blurb: string;
  features: ReadonlyArray<Feature>;
  tour?: ReadonlyArray<Feature>;
  cta: string;
  href: string;
  highlight: boolean;
}> = [
  {
    id: 'free',
    name: 'Free',
    tagline: 'Forever free · no card',
    price: '$0',
    cadence: 'forever',
    blurb: 'Find your first trigger ingredient before your next breakout. Nothing to lose.',
    features: [
      { text: 'Log up to 5 products', demo: 'counter' },
      { text: 'Personal trigger detection', demo: 'pulse' },
      { text: 'Instant INCI verdicts', demo: 'verdict' },
      { text: 'Export your data — yours always', demo: 'download' },
    ],
    tour: [
      { text: 'One-tap sign in', demo: 'login' },
      { text: 'Personal dashboard', demo: 'dashboard' },
      { text: 'Add products in seconds', demo: 'add-product' },
    ],
    cta: 'Start free →',
    href: '/login',
    highlight: false,
  },
  {
    id: 'pro-monthly',
    name: 'Pro',
    tagline: 'Most popular · 30-day trial',
    price: '$9',
    cadence: '/ month',
    blurb:
      "Less than the serum you're about to regret. Scan anything, anywhere, before you swipe the card.",
    features: [
      { text: 'Unlimited products + scans', demo: 'infinity' },
      { text: 'Full barcode + label OCR scanner', demo: 'scan' },
      { text: 'Routine builder + breakout journal', demo: 'calendar' },
      { text: 'AI verdicts on every new launch', demo: 'sparkle' },
      { text: 'Personal trigger map, kept private', demo: 'shield' },
      { text: 'Cancel anytime — no questions', demo: 'check' },
    ],
    tour: [
      { text: 'Smart dashboard with patterns', demo: 'dashboard' },
      { text: 'AM / PM routine builder', demo: 'routine' },
      { text: 'Breakout journal w/ photos', demo: 'journal' },
      { text: 'AI recommender for new launches', demo: 'recommend' },
      { text: 'Full scan history archive', demo: 'history' },
    ],
    cta: 'Upgrade to Pro',
    href: '/pricing#pro-monthly',
    highlight: true,
  },
  {
    id: 'pro-yearly',
    name: 'Pro Yearly',
    tagline: 'Smartest pick · save $29',
    price: '$79',
    cadence: '/ year',
    blurb:
      'Two months on the house. For people done playing skincare roulette every single month.',
    features: [
      { text: 'Everything in Pro', demo: 'star' },
      { text: '2 months free — that\'s $29 saved', demo: 'savings' },
      { text: 'Priority email support (<24h)', demo: 'mail' },
      { text: 'Early access to new scanners', demo: 'key' },
      { text: 'Locked-in pricing forever', demo: 'lock' },
    ],
    tour: [
      { text: 'Smart dashboard with patterns', demo: 'dashboard' },
      { text: 'AM / PM routine builder', demo: 'routine' },
      { text: 'Breakout journal w/ photos', demo: 'journal' },
      { text: 'AI recommender for new launches', demo: 'recommend' },
      { text: 'Full scanner + barcode + OCR', demo: 'scan' },
      { text: 'Full scan history archive', demo: 'history' },
    ],
    cta: 'Save 2 months',
    href: '/pricing#pro-yearly',
    highlight: false,
  },
];

function FeatureDemo({ kind, active = true }: { kind: DemoKey; active?: boolean }) {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    if (!active) return;
    const id = window.setInterval(() => setTick((t) => t + 1), 900);
    return () => window.clearInterval(id);
  }, [active]);

  switch (kind) {
    case 'counter': {
      const n = (tick % 6);
      return (
        <div className="flex items-center gap-0.5">
          {[0, 1, 2, 3, 4].map((i) => (
            <span
              key={i}
              className={`size-1.5 rounded-full transition-colors duration-300 ${
                i < n ? 'bg-primary' : 'bg-primary/20'
              }`}
            />
          ))}
          <span className="ml-1 font-mono text-[10px] text-primary tabular-nums">{n}/5</span>
        </div>
      );
    }
    case 'pulse':
      return (
        <div className="flex items-center gap-1.5">
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full rounded-full bg-bad-fg animate-ping opacity-75" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-bad-fg" />
          </span>
          <span className="font-mono text-[9px] text-bad-fg uppercase tracking-wider">trigger</span>
        </div>
      );
    case 'verdict': {
      const states = ['safe', 'watch', 'safe'];
      const state = states[tick % states.length];
      return (
        <span
          className={`font-mono text-[9px] uppercase tracking-wider px-1.5 py-0.5 rounded transition-colors duration-500 ${
            state === 'safe' ? 'bg-good-bg text-good-fg' : 'bg-bad-bg text-bad-fg'
          }`}
        >
          {state}
        </span>
      );
    }
    case 'download':
      return (
        <span className="inline-flex items-center justify-center size-5 rounded-md bg-primary/10 text-primary overflow-hidden">
          <svg
            width="11"
            height="11"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            style={{ animation: 'demoBob 1.4s ease-in-out infinite' }}
          >
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
        </span>
      );
    case 'infinity':
      return (
        <span className="font-display text-base text-primary leading-none" style={{ animation: 'demoPulse 1.8s ease-in-out infinite' }}>
          ∞
        </span>
      );
    case 'scan':
      return (
        <span className="relative inline-block w-10 h-3.5 rounded bg-ink/90 overflow-hidden">
          <span
            aria-hidden
            className="absolute inset-y-0 w-1.5 bg-primary/80 shadow-[0_0_8px_rgba(163,88,72,0.8)]"
            style={{ animation: 'scanSweep 1.4s ease-in-out infinite' }}
          />
          <span aria-hidden className="absolute inset-y-0.5 left-1 right-1 flex gap-[1px]">
            {[2, 4, 1, 3, 2, 5, 2, 3, 1, 4, 2, 3].map((w, i) => (
              <span key={i} className="bg-bg/40" style={{ width: w }} />
            ))}
          </span>
        </span>
      );
    case 'calendar': {
      const dot = tick % 3;
      return (
        <div className="grid grid-cols-7 gap-[2px]">
          {Array.from({ length: 14 }).map((_, i) => (
            <span
              key={i}
              className={`size-1 rounded-[1px] transition-colors duration-500 ${
                i === 3 + dot || i === 9 ? 'bg-primary' : 'bg-primary/15'
              }`}
            />
          ))}
        </div>
      );
    }
    case 'check':
      return (
        <span
          className="inline-flex items-center justify-center size-5 rounded-full bg-good-bg text-good-fg"
          style={{ animation: 'demoPulse 2.2s ease-in-out infinite' }}
        >
          <Check size={11} strokeWidth={3} />
        </span>
      );
    case 'savings':
      return (
        <div className="flex gap-[2px]">
          {Array.from({ length: 12 }).map((_, i) => (
            <span
              key={i}
              className={`h-3 w-1 rounded-[1px] ${
                i >= 10 ? 'bg-primary shadow-[0_0_6px_rgba(163,88,72,0.6)]' : 'bg-primary/20'
              }`}
            />
          ))}
        </div>
      );
    case 'mail':
      return (
        <span
          className="inline-flex items-center justify-center size-5 rounded-md bg-primary/10 text-primary relative"
          style={{ animation: 'demoBob 1.6s ease-in-out infinite' }}
        >
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="2" y="4" width="20" height="16" rx="2" />
            <polyline points="22,6 12,13 2,6" />
          </svg>
          <span className="absolute -top-0.5 -right-0.5 size-1.5 rounded-full bg-bad-fg" />
        </span>
      );
    case 'key':
      return (
        <span
          className="inline-flex items-center justify-center size-5 rounded-md bg-primary/10 text-primary"
          style={{ animation: 'demoSpin 4s linear infinite' }}
        >
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4" />
          </svg>
        </span>
      );
    case 'lock':
      return (
        <span className="inline-flex items-center justify-center size-5 rounded-md bg-primary/10 text-primary">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
            <path d="M7 11V7a5 5 0 0 1 10 0v4" />
          </svg>
        </span>
      );
    case 'shield':
      return (
        <span
          className="inline-flex items-center justify-center size-5 rounded-md bg-good-bg text-good-fg"
          style={{ animation: 'demoPulse 2s ease-in-out infinite' }}
        >
          <ShieldCheck size={11} />
        </span>
      );
    case 'sparkle':
      return (
        <span
          className="inline-flex items-center justify-center size-5 rounded-md bg-primary/10 text-primary"
          style={{ animation: 'demoSparkle 1.6s ease-in-out infinite' }}
        >
          <Sparkles size={11} />
        </span>
      );
    case 'star':
      return (
        <span
          className="font-display text-sm text-primary leading-none"
          style={{ animation: 'demoSparkle 2s ease-in-out infinite' }}
        >
          ★
        </span>
      );
    default:
      return null;
  }
}

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

// Kept for reuse in future sections; not currently rendered.
export function PhoneMockup() {
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
  const [foundingInterest, setFoundingInterest] = useState(true);
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
        body: JSON.stringify({
          email: clean,
          source: foundingInterest
            ? ref
              ? `landing:founding-3mo:${ref}`
              : 'landing:founding-3mo'
            : ref
              ? `landing:${ref}`
              : 'landing',
        }),
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
            Join the early-access list, then get first dibs on the{' '}
            <span className="text-bg font-semibold">$20 / 3-month Pro founding deal</span> when invitations open.
          </p>

          <div className="mb-8">
            <div className="flex items-baseline justify-between mb-2">
              <span className="text-xs uppercase tracking-[0.16em] text-bg/60 font-medium">
                Founding invitations
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
            <form onSubmit={submit} className="mb-5">
              <div className="flex flex-col sm:flex-row gap-3">
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
              </div>
              <label className="mt-4 flex items-start gap-3 cursor-pointer text-sm text-bg/75">
                <input
                  type="checkbox"
                  checked={foundingInterest}
                  onChange={(e) => setFoundingInterest(e.target.checked)}
                  className="mt-1 size-4 rounded border-bg/30 bg-bg/10 text-primary focus:ring-primary/50"
                />
                <span>
                  I want first access to the <strong className="text-bg">$20 / 3-month Pro founding deal</strong>.
                  <span className="block text-xs text-bg/50 mt-1">No payment today. We’ll email you before it opens.</span>
                </span>
              </label>
            </form>
          ) : (
            <div className="rounded-xl bg-primary/15 border border-primary/30 p-5 mb-5">
              <div className="font-display text-xl mb-1">✓ You're on the list.</div>
              <div className="text-sm text-bg/80">
                We'll email you the moment Skintel hits the App Store + Google Play.
                {foundingInterest && ' You’ll also get the $20 / 3-month founding invitation first.'}
              </div>
            </div>
          )}

          {err && (
            <div className="text-sm text-bad-fg mb-4" role="alert">
              {err}
            </div>
          )}

          <div className="flex items-center gap-2 text-xs text-bg/60 pt-2">
              <ShieldCheck size={13} />
              Launch-list signup · no card required
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

function BigDemo({ kind }: { kind: DemoKey }) {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const id = window.setInterval(() => setTick((t) => t + 1), 800);
    return () => window.clearInterval(id);
  }, []);

  switch (kind) {
    case 'counter': {
      const n = (tick % 6);
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="font-display text-7xl text-primary tabular-nums" style={{ textShadow: '0 0 30px rgba(163,88,72,0.4)' }}>
            {n}<span className="text-primary/30">/5</span>
          </div>
          <div className="flex items-center gap-2">
            {[0, 1, 2, 3, 4].map((i) => (
              <span
                key={i}
                className={`h-2 w-10 rounded-full transition-all duration-500 ${
                  i < n ? 'bg-primary shadow-[0_0_12px_rgba(163,88,72,0.7)]' : 'bg-primary/15'
                }`}
              />
            ))}
          </div>
          <div className="font-mono text-xs text-muted">Product slots filling</div>
        </div>
      );
    }
    case 'pulse':
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="relative size-32 flex items-center justify-center">
            <span className="absolute inset-0 rounded-full bg-bad-fg/20 animate-ping" />
            <span className="absolute inset-3 rounded-full bg-bad-fg/30 animate-pulse" />
            <span className="relative size-16 rounded-full bg-bad-fg flex items-center justify-center font-display text-2xl text-card">!</span>
          </div>
          <div className="text-center">
            <div className="font-mono text-xs uppercase tracking-[0.2em] text-bad-fg mb-1">Trigger detected</div>
            <div className="font-display text-2xl">Bisabolol</div>
            <div className="text-sm text-muted">Appears in 3 of your breakouts</div>
          </div>
        </div>
      );
    case 'verdict': {
      const states = [
        { label: 'safe', cls: 'bg-good-bg text-good-fg' },
        { label: 'watch', cls: 'bg-bad-bg text-bad-fg' },
        { label: 'safe', cls: 'bg-good-bg text-good-fg' },
        { label: 'safe', cls: 'bg-good-bg text-good-fg' },
      ];
      const cur = states[tick % states.length];
      return (
        <div className="flex flex-col items-center gap-4">
          <div className={`inline-flex items-center gap-2 px-6 py-3 rounded-full font-mono text-lg uppercase tracking-[0.2em] transition-all duration-500 ${cur.cls}`}>
            <span className="size-2 rounded-full bg-current" />
            {cur.label}
          </div>
          <div className="font-mono text-xs text-muted">Niacinamide · Glycerin · Bisabolol</div>
        </div>
      );
    }
    case 'download':
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="relative size-24">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" className="size-24 text-primary" style={{ animation: 'demoBob 1.4s ease-in-out infinite' }}>
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
              <polyline points="7 10 12 15 17 10" />
              <line x1="12" y1="15" x2="12" y2="3" />
            </svg>
          </div>
          <div className="font-mono text-xs uppercase tracking-[0.2em] text-primary">skintel-export.json</div>
          <div className="text-sm text-muted text-center max-w-[28ch]">Your full history, downloadable anytime</div>
        </div>
      );
    case 'infinity': {
      const visibleCount = Math.min((tick % 8) + 1, 6);
      const products = [
        { name: 'CeraVe Moisturizing Cream', verdict: 'safe', safe: true },
        { name: 'The Ordinary Niacinamide', verdict: 'safe', safe: true },
        { name: 'Glow Recipe Watermelon', verdict: 'skip', safe: false },
        { name: 'Drunk Elephant B-Hydra', verdict: 'skip', safe: false },
        { name: 'Cosrx Snail 96 Essence', verdict: 'safe', safe: true },
        { name: 'La Roche-Posay Toleriane', verdict: 'safe', safe: true },
      ];
      return (
        <div className="w-full max-w-[300px] mx-auto">
          <div className="flex items-center justify-between mb-2.5">
            <div className="font-mono text-[10px] text-muted uppercase tracking-wider">Your library</div>
            <div className="flex items-baseline gap-1">
              <span className="font-display text-xl text-primary tabular-nums" style={{ textShadow: '0 0 16px rgba(163,88,72,0.5)' }}>{visibleCount}</span>
              <span className="font-mono text-[10px] text-primary/40">/ ∞</span>
            </div>
          </div>
          <div className="space-y-1.5">
            {products.slice(0, visibleCount).map((p, i) => (
              <div
                key={p.name}
                className={`flex items-center gap-2.5 rounded-xl border px-3 py-2 ${p.safe ? 'bg-good-bg/30 border-good-fg/15' : 'bg-bad-bg/30 border-bad-fg/15'}`}
                style={i === visibleCount - 1 ? { animation: 'cardSlide 320ms cubic-bezier(0.22,1,0.36,1) forwards' } : undefined}
              >
                <div className={`size-6 rounded-lg flex items-center justify-center text-[10px] shrink-0 ${p.safe ? 'bg-good-fg/15 text-good-fg' : 'bg-bad-fg/15 text-bad-fg'}`}>
                  {p.safe ? '✓' : '!'}
                </div>
                <span className="font-mono text-[10px] flex-1 truncate">{p.name}</span>
                <span className={`font-mono text-[8px] uppercase tracking-wider px-1.5 py-0.5 rounded ${p.safe ? 'text-good-fg bg-good-fg/10' : 'text-bad-fg bg-bad-fg/10'}`}>
                  {p.verdict}
                </span>
              </div>
            ))}
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-3 text-center">
            No product limit — ever
          </div>
        </div>
      );
    }
    case 'scan': {
      // 6 phases: 0-2 = barcode mode, 3-5 = photo OCR mode
      const totalPhase = Math.floor(tick / 2) % 6;
      const isOcrMode = totalPhase >= 3;
      const scanPhase = totalPhase % 3; // 0=viewfinder, 1=processing, 2=results
      const scanIngredients = [
        { name: 'Aqua', safe: true }, { name: 'Glycerin', safe: true },
        { name: 'Niacinamide', safe: true }, { name: 'Bisabolol', safe: false },
        { name: 'Fragrance', safe: false },
      ];
      const ocrLines = ['Aqua, Glycerin, Niacinamide,', 'Bisabolol, Cetearyl Alcohol,', 'Fragrance, Panthenol...'];
      return (
        <div className="w-full max-w-[280px] mx-auto">
          {/* mode toggle pill */}
          <div className="flex items-center justify-center gap-1 mb-2">
            <span className={`font-mono text-[9px] uppercase tracking-wider px-2.5 py-1 rounded-full transition-all duration-400 ${!isOcrMode ? 'bg-primary text-card' : 'text-muted'}`}>
              Barcode
            </span>
            <span className="text-muted/40 text-[10px]">·</span>
            <span className={`font-mono text-[9px] uppercase tracking-wider px-2.5 py-1 rounded-full transition-all duration-400 ${isOcrMode ? 'bg-primary text-card' : 'text-muted'}`}>
              Photo OCR
            </span>
          </div>

          <div
            key={`scan-${isOcrMode}`}
            className="relative rounded-2xl overflow-hidden border transition-all duration-500"
            style={{
              background: scanPhase === 0 ? '#060606' : 'var(--card)',
              borderColor: scanPhase === 0 ? 'rgba(163,88,72,0.35)' : 'var(--border)',
              height: 200,
            }}
          >
            {/* ── BARCODE MODE ── */}
            {!isOcrMode && scanPhase === 0 && (
              <>
                <svg className="absolute inset-6 pointer-events-none" viewBox="0 0 100 100" fill="none">
                  <path d="M5 22 L5 5 L22 5" stroke="rgba(163,88,72,0.85)" strokeWidth="3" strokeLinecap="round" />
                  <path d="M78 5 L95 5 L95 22" stroke="rgba(163,88,72,0.85)" strokeWidth="3" strokeLinecap="round" />
                  <path d="M5 78 L5 95 L22 95" stroke="rgba(163,88,72,0.85)" strokeWidth="3" strokeLinecap="round" />
                  <path d="M95 78 L95 95 L78 95" stroke="rgba(163,88,72,0.85)" strokeWidth="3" strokeLinecap="round" />
                </svg>
                <div className="absolute inset-x-8 top-1/2 -translate-y-1/2 flex items-end justify-center gap-[3px] h-12">
                  {[2,1,3,1,2,4,1,2,3,1,4,2,1,3,2,1,3,1,2,4,1,2].map((w, i) => (
                    <span key={i} className="rounded-[1px]" style={{ width: w * 2.5, height: '100%', background: 'rgba(255,255,255,0.12)' }} />
                  ))}
                </div>
                <div aria-hidden className="absolute inset-x-0 h-0.5" style={{ background: 'rgba(163,88,72,0.9)', boxShadow: '0 0 14px 4px rgba(163,88,72,0.7)', animation: 'sceneScan 1.4s ease-in-out infinite' }} />
                <div className="absolute bottom-3 inset-x-0 flex justify-center">
                  <span className="font-mono text-[9px] uppercase tracking-widest text-primary/70 flex items-center gap-1.5">
                    <span className="size-1.5 rounded-full bg-primary animate-ping" />
                    Scan barcode
                  </span>
                </div>
              </>
            )}
            {!isOcrMode && scanPhase === 1 && (
              <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 p-4" style={{ animation: 'streamIn 300ms ease-out forwards' }}>
                <div className="size-11 rounded-full bg-good-bg flex items-center justify-center">
                  <Check size={22} className="text-good-fg" strokeWidth={3} />
                </div>
                <div className="font-display text-sm">Product found</div>
                <div className="font-mono text-xs text-primary">CeraVe Moisturizing Cream</div>
                <div className="font-mono text-[9px] text-muted">EAN · 8 904781 234567</div>
                <div className="w-32 h-1 rounded-full bg-border overflow-hidden mt-1">
                  <div className="h-full bg-primary rounded-full" style={{ animation: 'loadBar 0.7s ease-out forwards' }} />
                </div>
              </div>
            )}

            {/* ── PHOTO OCR MODE ── */}
            {isOcrMode && scanPhase === 0 && (
              <>
                <svg className="absolute inset-6 pointer-events-none" viewBox="0 0 100 100" fill="none">
                  <path d="M5 22 L5 5 L22 5" stroke="rgba(163,88,72,0.85)" strokeWidth="3" strokeLinecap="round" />
                  <path d="M78 5 L95 5 L95 22" stroke="rgba(163,88,72,0.85)" strokeWidth="3" strokeLinecap="round" />
                  <path d="M5 78 L5 95 L22 95" stroke="rgba(163,88,72,0.85)" strokeWidth="3" strokeLinecap="round" />
                  <path d="M95 78 L95 95 L78 95" stroke="rgba(163,88,72,0.85)" strokeWidth="3" strokeLinecap="round" />
                </svg>
                {/* ingredient text visible in camera */}
                <div className="absolute inset-8 flex flex-col justify-center gap-1.5">
                  {ocrLines.map((line, i) => (
                    <div key={i} className="font-mono text-[9px] text-white/30 leading-tight">{line}</div>
                  ))}
                </div>
                {/* horizontal sweep line (text OCR style) */}
                <div aria-hidden className="absolute inset-x-0 h-0.5" style={{ background: 'rgba(163,88,72,0.7)', boxShadow: '0 0 12px 3px rgba(163,88,72,0.5)', animation: 'sceneScan 1.6s ease-in-out infinite' }} />
                <div className="absolute bottom-3 inset-x-0 flex justify-center">
                  <span className="font-mono text-[9px] uppercase tracking-widest text-primary/70 flex items-center gap-1.5">
                    <span className="size-1.5 rounded-full bg-primary animate-ping" />
                    Reading label…
                  </span>
                </div>
              </>
            )}
            {isOcrMode && scanPhase === 1 && (
              <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 p-4" style={{ animation: 'streamIn 300ms ease-out forwards' }}>
                <div className="size-11 rounded-full bg-primary/15 flex items-center justify-center text-primary">
                  <ScanLine size={22} className="animate-pulse" />
                </div>
                <div className="font-display text-sm">Text extracted</div>
                <div className="font-mono text-[9px] text-muted text-center max-w-[22ch]">Aqua, Glycerin, Niacinamide, Bisabolol…</div>
                <div className="w-32 h-1 rounded-full bg-border overflow-hidden mt-1">
                  <div className="h-full bg-primary rounded-full" style={{ animation: 'loadBar 0.9s ease-out forwards' }} />
                </div>
              </div>
            )}

            {/* ── SHARED RESULTS (phase 2) ── */}
            {scanPhase === 2 && (
              <div className="absolute inset-0 flex flex-col p-3 gap-1.5" style={{ animation: 'streamIn 250ms ease-out forwards' }}>
                <div className="flex items-center justify-between mb-0.5">
                  <div className="font-mono text-[9px] text-muted uppercase tracking-wider">{isOcrMode ? 'Label scan' : 'CeraVe Moisturizing'}</div>
                  <div className="font-mono text-[8px] px-1.5 py-0.5 rounded bg-unsure-bg text-unsure-fg uppercase">Caution</div>
                </div>
                {scanIngredients.map((ing, i) => (
                  <div
                    key={ing.name}
                    className={`flex items-center gap-2 rounded-md px-2 py-1 opacity-0 ${ing.safe ? 'bg-good-bg/30' : 'bg-bad-bg/40'}`}
                    style={{ animation: `streamIn 240ms ease-out ${i * 70}ms forwards` }}
                  >
                    <span className={`size-1.5 rounded-full shrink-0 ${ing.safe ? 'bg-good-fg' : 'bg-bad-fg'}`} />
                    <span className="font-mono text-[10px] flex-1">{ing.name}</span>
                    {!ing.safe && <span className="font-mono text-[8px] text-bad-fg uppercase">trigger</span>}
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-2.5 text-center">
            {scanPhase === 0
              ? isOcrMode ? 'Snap the ingredients list' : 'Point at any barcode'
              : scanPhase === 1
              ? isOcrMode ? 'AI reads the text' : 'Decoded in 0.3s'
              : 'Full breakdown instantly'}
          </div>
        </div>
      );
    }
    case 'calendar': {
      const today = tick % 28;
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="grid grid-cols-7 gap-1.5">
            {Array.from({ length: 28 }).map((_, i) => (
              <span
                key={i}
                className={`size-6 rounded-md flex items-center justify-center font-mono text-[10px] transition-colors duration-500 ${
                  i === today ? 'bg-primary text-card shadow-[0_0_14px_rgba(163,88,72,0.6)]' : i % 5 === 0 ? 'bg-bad-bg/40 text-bad-fg' : i % 3 === 0 ? 'bg-good-bg/40 text-good-fg' : 'bg-primary/5'
                }`}
              >
                {i + 1}
              </span>
            ))}
          </div>
          <div className="font-mono text-xs uppercase tracking-[0.2em] text-muted">Routine + journal</div>
        </div>
      );
    }
    case 'check':
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="size-24 rounded-full bg-good-bg flex items-center justify-center" style={{ animation: 'demoPulse 1.8s ease-in-out infinite' }}>
            <Check size={56} className="text-good-fg" strokeWidth={3} />
          </div>
          <div className="font-display text-2xl">Cancel anytime</div>
          <div className="text-sm text-muted text-center max-w-[28ch]">One tap. No questions. No "are you sure" gauntlet.</div>
        </div>
      );
    case 'savings':
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="grid grid-cols-12 gap-1">
            {Array.from({ length: 12 }).map((_, i) => (
              <span
                key={i}
                className={`h-10 w-3 rounded-sm ${
                  i >= 10 ? 'bg-primary shadow-[0_0_10px_rgba(163,88,72,0.7)]' : 'bg-primary/20'
                }`}
              />
            ))}
          </div>
          <div className="flex items-baseline gap-2">
            <div className="font-display text-5xl text-primary">$29</div>
            <div className="text-sm text-muted">saved per year</div>
          </div>
          <div className="font-mono text-xs uppercase tracking-[0.2em] text-muted">2 months on the house</div>
        </div>
      );
    case 'mail':
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="relative size-24 rounded-2xl bg-primary/10 flex items-center justify-center" style={{ animation: 'demoBob 1.6s ease-in-out infinite' }}>
            <svg width="60" height="60" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" className="text-primary">
              <rect x="2" y="4" width="20" height="16" rx="2" />
              <polyline points="22,6 12,13 2,6" />
            </svg>
            <span className="absolute -top-1.5 -right-1.5 inline-flex items-center justify-center size-6 rounded-full bg-bad-fg text-card font-mono text-xs">1</span>
          </div>
          <div className="font-display text-xl">Priority support</div>
          <div className="font-mono text-xs uppercase tracking-[0.2em] text-primary">Reply within 24h</div>
        </div>
      );
    case 'key':
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="size-24 rounded-2xl bg-primary/10 flex items-center justify-center text-primary" style={{ animation: 'demoSpin 4s linear infinite' }}>
            <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4" />
            </svg>
          </div>
          <div className="font-display text-xl">Early access</div>
          <div className="text-sm text-muted text-center max-w-[28ch]">First in line for every new scanner we ship</div>
        </div>
      );
    case 'lock':
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="relative size-24 rounded-2xl bg-primary/10 flex items-center justify-center text-primary">
            <svg width="60" height="60" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
              <path d="M7 11V7a5 5 0 0 1 10 0v4" />
            </svg>
          </div>
          <div className="font-display text-2xl">$79 <span className="text-base text-muted">/ year, forever</span></div>
          <div className="font-mono text-xs uppercase tracking-[0.2em] text-muted text-center max-w-[32ch]">No renewal hikes. No grandfather drama.</div>
        </div>
      );
    case 'shield':
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="size-24 rounded-full bg-good-bg flex items-center justify-center" style={{ animation: 'demoPulse 2s ease-in-out infinite' }}>
            <ShieldCheck size={56} className="text-good-fg" />
          </div>
          <div className="font-display text-xl">Your data, locked tight</div>
          <div className="font-mono text-xs uppercase tracking-[0.2em] text-muted">Row-level encrypted · never sold</div>
        </div>
      );
    case 'sparkle': {
      const thinking = tick % 6 < 2;
      const VERDICT_TEXT = 'Bisabolol triggered 3 of your last 5 flare-ups. This product contains it — skip.';
      const revealPct = tick % 6 === 2 ? 0.35 : tick % 6 === 3 ? 0.7 : tick % 6 >= 4 ? 1 : 0;
      const revealLen = Math.floor(VERDICT_TEXT.length * revealPct);
      return (
        <div className="w-full max-w-[280px] mx-auto">
          <div className="rounded-2xl bg-card border border-border p-4 shadow-soft">
            <div className="flex items-center gap-2 mb-3">
              <div className="size-7 rounded-full bg-primary/15 flex items-center justify-center text-primary shrink-0" style={thinking ? { animation: 'demoSparkle 1.2s ease-in-out infinite' } : undefined}>
                <Sparkles size={13} />
              </div>
              <div className="font-display text-sm flex-1">AI Verdict</div>
              {thinking ? (
                <div className="flex gap-1">
                  {[0, 1, 2].map((i) => (
                    <span key={i} className="size-1.5 rounded-full bg-primary/60" style={{ animation: `dotBounce 0.9s ease-in-out ${i * 0.18}s infinite` }} />
                  ))}
                </div>
              ) : revealPct >= 1 ? (
                <span className="font-mono text-[8px] uppercase tracking-wider px-1.5 py-0.5 rounded bg-bad-bg text-bad-fg">Skip</span>
              ) : null}
            </div>
            {thinking ? (
              <div className="space-y-2">
                <div className="h-2.5 rounded-full" style={{ background: 'rgba(163,88,72,0.1)', animation: 'shimmerLoad 1.1s ease-in-out infinite' }} />
                <div className="h-2.5 rounded-full w-4/5" style={{ background: 'rgba(163,88,72,0.08)', animation: 'shimmerLoad 1.1s ease-in-out 0.15s infinite' }} />
                <div className="h-2.5 rounded-full w-3/5" style={{ background: 'rgba(163,88,72,0.06)', animation: 'shimmerLoad 1.1s ease-in-out 0.3s infinite' }} />
              </div>
            ) : (
              <div className="text-[11px] leading-relaxed text-ink/90 min-h-[52px]">
                {VERDICT_TEXT.slice(0, revealLen)}
                {revealPct < 1 && <span className="inline-block w-0.5 h-3 bg-primary ml-0.5 align-middle animate-pulse" />}
              </div>
            )}
            {revealPct >= 1 && (
              <div className="mt-3 pt-2 border-t border-border flex items-center gap-2">
                <div className="size-5 rounded-full bg-bad-bg flex items-center justify-center shrink-0">
                  <AlertTriangle size={10} className="text-bad-fg" />
                </div>
                <span className="font-mono text-[9px] text-bad-fg/80">2 triggers in your personal map</span>
              </div>
            )}
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-3 text-center">
            Personalized to your trigger history
          </div>
        </div>
      );
    }
    case 'star':
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="font-display text-[120px] text-primary leading-none" style={{ animation: 'demoSparkle 1.8s ease-in-out infinite' }}>
            ★
          </div>
          <div className="font-display text-2xl">Everything in Pro</div>
          <div className="font-mono text-xs uppercase tracking-[0.2em] text-muted">Plus the extras below</div>
        </div>
      );
    case 'login':
      return (
        <div className="w-full max-w-[280px] mx-auto">
          <div className="rounded-2xl bg-card border border-border p-4 shadow-soft">
            <div className="font-display text-lg mb-1">Welcome back</div>
            <div className="text-xs text-muted mb-3">One tap. No password games.</div>
            <div className="relative mb-2">
              <input
                readOnly
                value="you@skin.tel"
                className="w-full px-3 py-2 rounded-lg border border-border bg-bg text-xs font-mono"
              />
              <span className="absolute right-2 top-1/2 -translate-y-1/2 size-1.5 rounded-full bg-primary animate-pulse" />
            </div>
            <div className="rounded-lg bg-primary text-card py-2 text-center text-xs font-medium mb-2">
              Send magic link →
            </div>
            <div className="flex items-center gap-2 my-2">
              <span className="flex-1 h-px bg-border" />
              <span className="text-[9px] text-muted uppercase tracking-wider">or</span>
              <span className="flex-1 h-px bg-border" />
            </div>
            <div className="rounded-lg bg-ink text-bg py-2 text-center text-xs font-medium flex items-center justify-center gap-2">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" /></svg>
              Continue with Google
            </div>
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-3 text-center">
            No accounts to manage
          </div>
        </div>
      );
    case 'dashboard':
      return (
        <div className="w-full max-w-[300px] mx-auto">
          <div className="rounded-2xl bg-card border border-border p-3 shadow-soft">
            <div className="flex items-center justify-between mb-3">
              <div>
                <div className="text-[9px] text-muted uppercase tracking-wider">Pattern</div>
                <div className="font-display text-base leading-tight">3 triggers locked in</div>
              </div>
              <div className="size-7 rounded-full bg-primary/15 flex items-center justify-center text-primary">
                <Sparkles size={13} />
              </div>
            </div>
            <div className="grid grid-cols-3 gap-1.5 mb-3">
              <div className="rounded-md bg-bad-bg/60 p-1.5">
                <div className="font-display text-base text-bad-fg leading-none">7</div>
                <div className="text-[8px] text-bad-fg/80 uppercase tracking-wider">breakouts</div>
              </div>
              <div className="rounded-md bg-good-bg/60 p-1.5">
                <div className="font-display text-base text-good-fg leading-none">12</div>
                <div className="text-[8px] text-good-fg/80 uppercase tracking-wider">safe</div>
              </div>
              <div className="rounded-md bg-primary/10 p-1.5">
                <div className="font-display text-base text-primary leading-none">19</div>
                <div className="text-[8px] text-primary/80 uppercase tracking-wider">logged</div>
              </div>
            </div>
            <div className="space-y-1">
              {[
                { name: 'Bisabolol', cls: 'bg-bad-bg/60 text-bad-fg', tag: '3 breakouts' },
                { name: 'Niacinamide', cls: 'bg-good-bg/60 text-good-fg', tag: 'barrier' },
                { name: 'Coconut Alkanes', cls: 'bg-bad-bg/60 text-bad-fg', tag: '3 breakouts' },
              ].map((row, i) => (
                <div
                  key={row.name}
                  className={`flex items-center justify-between rounded px-2 py-1 opacity-0 ${row.cls}`}
                  style={{ animation: 'streamIn 300ms ease-out forwards', animationDelay: `${i * 80}ms` }}
                >
                  <span className="font-mono text-[10px]">{row.name}</span>
                  <span className="text-[8px]">{row.tag}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-3 text-center">
            Patterns at a glance
          </div>
        </div>
      );
    case 'routine':
      return (
        <div className="w-full max-w-[300px] mx-auto">
          <div className="rounded-2xl bg-card border border-border p-3 shadow-soft space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1.5">
                <span className="size-2 rounded-full bg-primary" />
                <span className="font-mono text-[10px] uppercase tracking-wider text-primary">AM</span>
              </div>
              <span className="text-[9px] text-muted">4 steps</span>
            </div>
            <div className="space-y-1">
              {['Cleanser', 'Niacinamide serum', 'Moisturizer', 'SPF 50'].map((s, i) => (
                <div
                  key={s}
                  className="flex items-center gap-2 rounded-md bg-bg/60 px-2 py-1 opacity-0"
                  style={{ animation: 'streamIn 250ms ease-out forwards', animationDelay: `${i * 60}ms` }}
                >
                  <span className="font-mono text-[8px] text-muted">0{i + 1}</span>
                  <span className="text-[10px] flex-1">{s}</span>
                  <Check size={10} className="text-good-fg" />
                </div>
              ))}
            </div>
            <div className="h-px bg-border my-1" />
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1.5">
                <span className="size-2 rounded-full bg-ink" />
                <span className="font-mono text-[10px] uppercase tracking-wider text-ink">PM</span>
              </div>
              <span className="text-[9px] text-muted">5 steps</span>
            </div>
            <div className="space-y-1">
              {['Double cleanse', 'Retinol', 'Peptide serum', 'Moisturizer', 'Sleep mask'].map((s, i) => (
                <div
                  key={s}
                  className="flex items-center gap-2 rounded-md bg-bg/60 px-2 py-1 opacity-0"
                  style={{ animation: 'streamIn 250ms ease-out forwards', animationDelay: `${300 + i * 60}ms` }}
                >
                  <span className="font-mono text-[8px] text-muted">0{i + 1}</span>
                  <span className="text-[10px] flex-1">{s}</span>
                  <Check size={10} className="text-good-fg" />
                </div>
              ))}
            </div>
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-3 text-center">
            Drag-to-reorder routine builder
          </div>
        </div>
      );
    case 'journal':
      return (
        <div className="w-full max-w-[280px] mx-auto">
          <div className="rounded-2xl bg-card border border-border p-3 shadow-soft">
            <div className="flex items-center justify-between mb-2">
              <div className="font-display text-base leading-tight">Tuesday</div>
              <div className="font-mono text-[9px] text-muted uppercase tracking-wider">May 23</div>
            </div>
            <div className="relative aspect-[5/3] rounded-lg mb-2 overflow-hidden bg-gradient-to-br from-bad-bg via-primary/20 to-good-bg">
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="size-12 rounded-full bg-bg/80 backdrop-blur flex items-center justify-center">
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-primary">
                    <circle cx="12" cy="12" r="3" />
                    <path d="M5 7h2.5l1.5-2h6l1.5 2H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z" />
                  </svg>
                </div>
              </div>
              <div className="absolute top-1.5 right-1.5 inline-flex items-center gap-1 bg-bad-fg text-card px-1.5 py-0.5 rounded text-[8px] uppercase tracking-wider">
                <span className="size-1 rounded-full bg-card animate-pulse" />
                Flare
              </div>
            </div>
            <div className="space-y-1">
              <div className="text-[10px] text-ink/80 leading-snug">
                Cheek + jaw. Skipped retinol last night. Tried new SPF.
              </div>
              <div className="flex flex-wrap gap-1 mt-1.5">
                {['#cheek', '#jaw', '#new-spf'].map((t) => (
                  <span key={t} className="font-mono text-[8px] bg-primary/10 text-primary px-1.5 py-0.5 rounded">
                    {t}
                  </span>
                ))}
              </div>
            </div>
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-3 text-center">
            Photos · notes · auto tags
          </div>
        </div>
      );
    case 'recommend':
      return (
        <div className="w-full max-w-[280px] mx-auto">
          <div className="rounded-2xl bg-card border border-border p-3 shadow-soft">
            <div className="flex items-center gap-2 mb-3">
              <div className="size-7 rounded-full bg-primary/15 flex items-center justify-center text-primary" style={{ animation: 'demoSparkle 1.6s ease-in-out infinite' }}>
                <Sparkles size={13} />
              </div>
              <div className="flex-1">
                <div className="font-display text-sm leading-none">Should I buy this?</div>
                <div className="text-[9px] text-muted">Glow Recipe Watermelon Toner</div>
              </div>
            </div>
            <div className="rounded-lg bg-bad-bg/70 border border-bad-fg/20 p-2 mb-2">
              <div className="flex items-center justify-between mb-0.5">
                <div className="font-display text-sm text-bad-fg">Skip it</div>
                <div className="font-mono text-[9px] text-bad-fg/80 uppercase">87% match</div>
              </div>
              <div className="text-[9px] text-bad-fg/80 leading-snug">
                Contains 2 of your trigger ingredients
              </div>
            </div>
            <div className="space-y-1">
              <div className="text-[9px] uppercase tracking-wider text-muted">Try instead</div>
              {['Cosrx AHA/BHA Toner', 'Beauty of Joseon Glow', 'Naturium Mandelic'].map((p, i) => (
                <div
                  key={p}
                  className="flex items-center justify-between rounded-md bg-good-bg/40 px-2 py-1 opacity-0"
                  style={{ animation: 'streamIn 280ms ease-out forwards', animationDelay: `${300 + i * 80}ms` }}
                >
                  <span className="text-[10px]">{p}</span>
                  <span className="font-mono text-[8px] text-good-fg uppercase">safe</span>
                </div>
              ))}
            </div>
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-3 text-center">
            AI verdict + smart alternatives
          </div>
        </div>
      );
    case 'add-product':
      return (
        <div className="w-full max-w-[280px] mx-auto">
          <div className="rounded-2xl bg-card border border-border p-3 shadow-soft">
            <div className="font-display text-base mb-2">Add product</div>
            <div className="space-y-2">
              <div>
                <div className="text-[9px] uppercase tracking-wider text-muted mb-0.5">Brand</div>
                <div className="rounded-md bg-bg/60 px-2 py-1.5 font-mono text-[10px]">
                  The Ordinary
                </div>
              </div>
              <div>
                <div className="text-[9px] uppercase tracking-wider text-muted mb-0.5">Product</div>
                <div className="rounded-md bg-bg/60 px-2 py-1.5 font-mono text-[10px]">
                  Niacinamide 10% + Zinc
                </div>
              </div>
              <div>
                <div className="text-[9px] uppercase tracking-wider text-muted mb-0.5">Outcome</div>
                <div className="grid grid-cols-3 gap-1">
                  {[
                    { label: 'safe', cls: 'bg-good-bg/60 text-good-fg ring-1 ring-good-fg/40' },
                    { label: 'meh', cls: 'bg-bg/60 text-muted' },
                    { label: 'break', cls: 'bg-bg/60 text-muted' },
                  ].map((b) => (
                    <span key={b.label} className={`text-center rounded-md py-1 font-mono text-[9px] uppercase tracking-wider ${b.cls}`}>
                      {b.label}
                    </span>
                  ))}
                </div>
              </div>
              <div className="rounded-md bg-primary text-card py-1.5 text-center text-[10px] font-medium" style={{ animation: 'demoPulse 1.6s ease-in-out infinite' }}>
                Save + analyze
              </div>
            </div>
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-3 text-center">
            Logged in under 10 seconds
          </div>
        </div>
      );
    case 'history':
      return (
        <div className="w-full max-w-[280px] mx-auto">
          <div className="rounded-2xl bg-card border border-border p-3 shadow-soft">
            <div className="flex items-center justify-between mb-2">
              <div className="font-display text-base">Scan history</div>
              <div className="font-mono text-[9px] text-muted">142 total</div>
            </div>
            <div className="space-y-1">
              {[
                { name: 'Drunk Elephant B-Hydra', tag: 'skip', cls: 'bg-bad-bg/60 text-bad-fg', when: '2m ago' },
                { name: 'Beauty of Joseon Glow', tag: 'safe', cls: 'bg-good-bg/60 text-good-fg', when: '1h ago' },
                { name: 'Cosrx AHA/BHA Toner', tag: 'safe', cls: 'bg-good-bg/60 text-good-fg', when: 'Yesterday' },
                { name: 'Glow Recipe Watermelon', tag: 'skip', cls: 'bg-bad-bg/60 text-bad-fg', when: '3d ago' },
                { name: 'Naturium Mandelic', tag: 'safe', cls: 'bg-good-bg/60 text-good-fg', when: '4d ago' },
              ].map((row, i) => (
                <div
                  key={row.name}
                  className="flex items-center gap-2 rounded-md bg-bg/40 px-2 py-1 opacity-0"
                  style={{ animation: 'streamIn 240ms ease-out forwards', animationDelay: `${i * 70}ms` }}
                >
                  <span className={`text-[8px] font-mono uppercase tracking-wider px-1.5 py-0.5 rounded ${row.cls}`}>
                    {row.tag}
                  </span>
                  <span className="text-[10px] flex-1 truncate">{row.name}</span>
                  <span className="font-mono text-[8px] text-muted">{row.when}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-muted mt-3 text-center">
            Every verdict, forever searchable
          </div>
        </div>
      );
    default:
      return null;
  }
}

function PlanDemoModal({ planId, onClose }: { planId: string; onClose: () => void }) {
  const plan = PRICING.find((p) => p.id === planId);
  const all = plan ? [...plan.features, ...(plan.tour ?? [])] : [];
  const [idx, setIdx] = useState(0);

  useEffect(() => {
    setIdx(0);
  }, [planId]);

  useEffect(() => {
    if (!plan || all.length === 0) return;
    const id = window.setInterval(() => {
      setIdx((i) => (i + 1) % all.length);
    }, 3200);
    return () => window.clearInterval(id);
  }, [plan, all.length]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  if (!plan) return null;
  const current = all[idx] ?? plan.features[0];
  const isTour = idx >= plan.features.length;

  return (
    <div
      className="fixed inset-0 z-[80] flex items-center justify-center p-4"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
    >
      <div className="absolute inset-0 bg-ink/80 backdrop-blur-xl" style={{ animation: 'modalFade 300ms ease-out' }} />
      <div
        className="relative w-full max-w-md card overflow-hidden shadow-[0_40px_80px_-20px_rgba(0,0,0,0.5)]"
        onClick={(e) => e.stopPropagation()}
        style={{ animation: 'modalRise 380ms cubic-bezier(0.22,1,0.36,1)' }}
      >
        <div
          aria-hidden
          className="absolute -top-24 -right-24 size-64 bg-primary/15 blur-3xl rounded-full"
        />
        <div
          aria-hidden
          className="absolute -bottom-24 -left-24 size-64 bg-primary/10 blur-3xl rounded-full"
        />

        <div className="relative px-6 pt-6 pb-4 flex items-start justify-between border-b border-border">
          <div>
            <div className="text-[10px] uppercase tracking-[0.2em] text-primary font-semibold mb-1">
              {plan.tagline}
            </div>
            <div className="font-display text-2xl leading-none">{plan.name}</div>
            <div className="flex items-baseline gap-1.5 mt-1">
              <span className="font-display text-2xl text-primary">{plan.price}</span>
              <span className="text-xs text-muted">{plan.cadence}</span>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="size-9 rounded-full bg-bg hover:bg-card border border-border flex items-center justify-center text-muted hover:text-ink transition-colors"
            aria-label="Close"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>

        <div className="relative px-6 py-8 min-h-[320px] flex flex-col items-center justify-center text-center">
          <div className="font-mono text-[10px] uppercase tracking-[0.22em] text-muted/70 mb-1">
            {isTour ? 'Inside the app' : 'Feature'} {idx + 1} of {all.length}
          </div>
          <div className="font-display text-xl mb-6 max-w-[28ch]">{current.text}</div>
          <div key={`${planId}-${idx}`} style={{ animation: 'modalRise 400ms cubic-bezier(0.22,1,0.36,1)' }}>
            <BigDemo kind={current.demo} />
          </div>
        </div>

        <div className="relative px-6 pb-6 pt-4 border-t border-border">
          <div className="flex items-center justify-center gap-1.5 mb-4">
            {all.map((_, i) => {
              const tourDot = i >= plan.features.length;
              return (
                <button
                  key={i}
                  type="button"
                  onClick={() => setIdx(i)}
                  className={`h-1.5 rounded-full transition-all duration-300 ${
                    i === idx
                      ? tourDot
                        ? 'w-8 bg-gradient-to-r from-primary to-primary/60'
                        : 'w-8 bg-primary'
                      : tourDot
                        ? 'w-1.5 bg-primary/30 hover:bg-primary/50'
                        : 'w-1.5 bg-primary/20 hover:bg-primary/40'
                  }`}
                  aria-label={`Show ${tourDot ? 'tour' : 'feature'} ${i + 1}`}
                />
              );
            })}
          </div>
          <Link
            to={plan.href}
            className="btn-primary w-full active:scale-[0.985] transition-transform duration-150"
            onClick={onClose}
          >
            {plan.cta} <ArrowRight size={14} />
          </Link>
        </div>
      </div>
    </div>
  );
}

function ScrollPlayedPromo() {
  const containerRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const [playCount, setPlayCount] = useState(0);
  const [showReplay, setShowReplay] = useState(false);

  useEffect(() => {
    const container = containerRef.current;
    const video = videoRef.current;
    if (!container || !video) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !showReplay && video.paused) {
          void video.play().catch(() => undefined);
        } else if (!entry.isIntersecting && !video.paused) {
          video.pause();
        }
      },
      { threshold: 0.55 },
    );

    observer.observe(container);
    return () => observer.disconnect();
  }, [showReplay]);

  function handleEnded() {
    const video = videoRef.current;
    if (!video) return;

    setPlayCount((current) => {
      const next = current + 1;
      if (next < 3) {
        video.currentTime = 0;
        void video.play().catch(() => undefined);
      } else {
        setShowReplay(true);
      }
      return next;
    });
  }

  function watchAgain() {
    const video = videoRef.current;
    if (!video) return;
    setShowReplay(false);
    setPlayCount(2);
    video.currentTime = 0;
    void video.play().catch(() => undefined);
  }

  return (
    <div ref={containerRef} className="relative mx-auto w-full max-w-[300px] overflow-hidden rounded-[30px] border border-border bg-bg shadow-soft">
      <video
        ref={videoRef}
        className="block w-full h-auto"
        muted
        playsInline
        preload="metadata"
        poster="/skintel-promo-v2-cover.png"
        onEnded={handleEnded}
        aria-label="Skintel app walkthrough showing product verdicts, label scanning, and personal trigger matches"
      >
        <source src="/skintel-promo-v2.mp4" type="video/mp4" />
      </video>
      {showReplay && (
        <div className="absolute inset-0 flex items-center justify-center bg-ink/55 backdrop-blur-[2px]">
          <button type="button" onClick={watchAgain} className="btn-primary shadow-soft">
            <Play size={15} fill="currentColor" /> Watch again
          </button>
        </div>
      )}
      <span className="sr-only" aria-live="polite">
        {showReplay ? 'Video finished after three plays.' : `Video play ${Math.min(playCount + 1, 3)} of 3.`}
      </span>
    </div>
  );
}

export default function Landing() {
  const [openFaq, setOpenFaq] = useState<number | null>(0);
  const [demoPlan, setDemoPlan] = useState<string | null>(null);
  const [scrolled, setScrolled] = useState(false);
  const { remaining, total } = useFoundingCount();
  const soldOut = typeof remaining === 'number' && remaining <= 0;
  useParallaxRoot();

  const [showBar, setShowBar] = useState(false);
  useEffect(() => {
    const onScroll = () => {
      setScrolled(window.scrollY > 8);
      setShowBar(window.scrollY > 480);
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  // channel attribution: ?ref=tt|reddit|x|… survives into waitlist + checkout
  const [checkoutHref, setCheckoutHref] = useState('/api/checkout-founding');
  useEffect(() => {
    try {
      const urlRef = new URLSearchParams(window.location.search).get('ref');
      if (urlRef) localStorage.setItem('skintel_ref', urlRef.slice(0, 40));
      const ref = urlRef ?? localStorage.getItem('skintel_ref');
      if (ref) setCheckoutHref(`/api/checkout-founding?ref=${encodeURIComponent(ref.slice(0, 40))}`);
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
        <div className="max-w-6xl mx-auto px-4 sm:px-6 py-3 sm:py-4 flex items-center justify-between">
          <Link to="/" className="font-display text-2xl leading-none">
            Skintel<span className="text-primary">.</span>
          </Link>
          <nav className="flex items-center gap-1 text-sm">
            <a
              href="#founding"
              className="px-3 py-2 text-muted hover:text-ink transition-colors duration-200 ease-emil rounded-lg hidden sm:block"
            >
              Waitlist
            </a>
            <a
              href={checkoutHref}
              className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
            >
              Claim $20 deal <ArrowRight size={14} />
            </a>
          </nav>
        </div>
      </header>

      <section className="relative max-w-6xl mx-auto px-4 sm:px-6 pt-6 sm:pt-8 md:pt-20 pb-8 sm:pb-12 md:pb-28">
        <div className="grid lg:grid-cols-[1.15fr_1fr] gap-8 lg:gap-16 items-center">
          <div className="animate-rise-in" style={{ animationDelay: '40ms' }}>
            <div className="inline-flex items-center gap-2 text-[10px] sm:text-xs uppercase tracking-[0.12em] sm:tracking-[0.14em] text-primary bg-primary/8 border border-primary/15 px-3 py-1.5 rounded-full mb-5 sm:mb-7">
              <span className="relative flex h-1.5 w-1.5">
                <span className="absolute inline-flex h-full w-full rounded-full bg-primary animate-breathe" />
                <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-primary" />
              </span>
              Personal ingredient intelligence
            </div>

            <h1 className="font-display text-[2.45rem] sm:text-6xl lg:text-[4.25rem] leading-[1.02] tracking-tight mb-4 sm:mb-6">
              Stop guessing why
              <br />
              your skin <span className="italic text-primary">broke out.</span>
            </h1>

            <p className="text-base sm:text-lg text-muted max-w-[60ch] mb-6 sm:mb-8 leading-relaxed">
              One hidden ingredient is usually behind it. Log the products you already use, tag
              what broke you out, and Skintel names your personal triggers — so you never buy
              them again.
            </p>

            <div className="grid grid-cols-1 min-[390px]:grid-cols-2 sm:flex items-center gap-3">
              {soldOut ? (
                <Link
                  to="/login"
                  className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
                >
                  Start free <ArrowRight size={16} />
                </Link>
              ) : (
                <a
                  href={checkoutHref}
                  className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
                >
                  Get 6 months of Pro — $20 <ArrowRight size={16} />
                </a>
              )}
              <a
                href="#founding"
                className="btn-secondary active:scale-[0.97] transition-transform duration-150 ease-emil"
              >
                Join the waitlist
              </a>
            </div>

            <div className="mt-6 sm:mt-10 flex items-center gap-3 sm:gap-5 text-[11px] sm:text-xs text-muted flex-wrap">
              {!soldOut && (
                <>
                  <div className="flex items-center gap-1.5 text-primary font-medium">
                    <span className="relative flex h-1.5 w-1.5">
                      <span className="absolute inline-flex h-full w-full rounded-full bg-primary animate-breathe" />
                      <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-primary" />
                    </span>
                    {typeof remaining === 'number'
                      ? `${remaining} of ${total} founding seats left`
                      : 'Founding seats are limited'}
                  </div>
                  <div className="h-3 w-px bg-border" />
                </>
              )}
              <div className="flex items-center gap-1.5">
                <ShieldCheck size={14} className="text-primary/80" />
                14-day refund
              </div>
              <div className="hidden sm:block h-3 w-px bg-border" />
              <div className="hidden sm:block">No auto-renew · pay once</div>
            </div>
          </div>

          <div className="relative animate-rise-in hidden sm:block" style={{ animationDelay: '180ms' }}>
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

      <section id="demo" className="max-w-3xl mx-auto px-4 sm:px-6 pb-8 sm:pb-10 md:pb-24 scroll-mt-24">
        <FadeUp>
          <TryItDemo />
        </FadeUp>
      </section>

      <section id="walkthrough" className="max-w-5xl mx-auto px-4 sm:px-6 pb-10 sm:pb-14 md:pb-24 scroll-mt-24">
        <FadeUp>
          <div className="card overflow-hidden shadow-soft p-5 sm:p-8 md:p-10">
            <div className="grid md:grid-cols-[1fr_320px] gap-7 md:gap-12 items-center">
              <div>
                <div className="text-[10px] sm:text-xs uppercase tracking-[0.16em] text-primary mb-4">
                  See Skintel in 15 seconds
                </div>
                <h2 className="font-display text-3xl sm:text-5xl leading-[1.05] mb-4">
                  Know what <span className="italic text-primary">touches</span> your skin.
                </h2>
                <p className="text-sm sm:text-base text-muted leading-relaxed mb-6 max-w-[48ch]">
                  Scan a label, see your personal match, and catch repeat trigger ingredients
                  before another product reaches your shelf.
                </p>
                <div className="grid gap-3 text-sm mb-6">
                  {[
                    'Personal verdicts for every product',
                    'Repeat-trigger insights from your own history',
                    'Private skin map that improves as you log',
                  ].map((feature) => (
                    <div key={feature} className="flex items-center gap-3">
                      <span className="size-5 rounded-full bg-good-bg text-good-fg inline-flex items-center justify-center shrink-0">
                        <Check size={12} strokeWidth={2.5} />
                      </span>
                      <span>{feature}</span>
                    </div>
                  ))}
                </div>
                <a href="#founding" className="btn-primary inline-flex active:scale-[0.97] transition-transform duration-150 ease-emil">
                  Join the waitlist <ArrowRight size={16} />
                </a>
              </div>

              <ScrollPlayedPromo />
            </div>
          </div>
        </FadeUp>
      </section>

      {/* ── FOUNDING OFFER ── */}
      {!soldOut && (
        <section id="offer" className="max-w-4xl mx-auto px-4 sm:px-6 pb-10 sm:pb-14 md:pb-24 scroll-mt-24">
          <FadeUp>
            <div className="card relative overflow-hidden p-6 sm:p-10 shadow-soft border-primary/25">
              <div
                aria-hidden
                className="pointer-events-none absolute -top-24 -right-24 h-64 w-64 rounded-full bg-primary/10 blur-3xl"
              />
              <div className="grid md:grid-cols-[1.2fr_1fr] gap-8 items-center relative">
                <div>
                  <div className="inline-flex items-center gap-2 text-[10px] sm:text-xs uppercase tracking-[0.14em] text-primary bg-primary/8 border border-primary/15 px-3 py-1.5 rounded-full mb-4">
                    <Sparkles size={12} />
                    Founding offer · one batch only
                  </div>
                  <h2 className="font-display text-3xl sm:text-4xl leading-tight mb-3">
                    6 months of Pro for <span className="text-primary">$20.</span>
                    <br />
                    Then it&rsquo;s gone.
                  </h2>
                  <p className="text-muted text-sm sm:text-base leading-relaxed mb-5 max-w-[48ch]">
                    Everything in Pro — unlimited products, the full INCI scanner, your personal
                    trigger map. Pay once. No subscription, no auto-renew. Regular price after
                    the founding batch: <span className="line-through">$79/year</span>.
                  </p>
                  <div className="flex flex-col min-[390px]:flex-row items-stretch min-[390px]:items-center gap-3">
                    <a
                      href={checkoutHref}
                      className="btn-primary justify-center active:scale-[0.97] transition-transform duration-150 ease-emil"
                    >
                      Claim my seat — $20 <ArrowRight size={16} />
                    </a>
                    <div className="text-[11px] sm:text-xs text-muted flex items-center gap-1.5 justify-center">
                      <ShieldCheck size={14} className="text-primary/80" />
                      14-day money-back guarantee
                    </div>
                  </div>
                </div>

                <div className="rounded-2xl bg-bg/60 border border-border p-5">
                  <div className="flex items-baseline justify-between mb-2">
                    <span className="text-xs uppercase tracking-[0.14em] text-muted font-medium">
                      Seats claimed
                    </span>
                    <span className="font-mono text-sm">
                      {typeof remaining === 'number' ? `${total - remaining} / ${total}` : `— / ${total}`}
                    </span>
                  </div>
                  <div className="h-2 rounded-full bg-border overflow-hidden mb-4">
                    <div
                      className="h-full rounded-full bg-primary transition-[width] duration-700 ease-emil"
                      style={{
                        width:
                          typeof remaining === 'number'
                            ? `${Math.max(2, Math.min(100, ((total - remaining) / total) * 100))}%`
                            : '2%',
                      }}
                    />
                  </div>
                  <ul className="space-y-2 text-sm">
                    {[
                      'Unlimited tracked products',
                      'Full INCI scanner — paste, snap, barcode',
                      'Personal trigger map',
                      'Founding badge + early iOS access',
                    ].map((f) => (
                      <li key={f} className="flex items-start gap-2 text-ink/90">
                        <Check size={15} className="text-primary shrink-0 mt-0.5" />
                        {f}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>
          </FadeUp>
        </section>
      )}

      {/* ── STATS / FEAR SECTION ── */}
      <section className="py-10 sm:py-12 md:py-32 px-4 sm:px-6 border-y border-border bg-card/20">
        <div className="max-w-6xl mx-auto">
          <FadeUp>
            <div className="inline-flex items-center gap-2 text-[11px] uppercase tracking-[0.22em] text-primary font-semibold mb-6">
              <span className="h-px w-8 bg-primary/40" /> The problem nobody talks about
            </div>
            <h2 className="font-display text-[2.15rem] sm:text-4xl md:text-6xl leading-[0.98] md:leading-[0.95] tracking-tight mb-4 max-w-3xl">
              Your skin isn't broken.<br />
              <span className="text-primary italic">Your routine is fighting itself.</span>
            </h2>
            <p className="text-muted text-base sm:text-lg max-w-2xl mb-8 sm:mb-10 md:mb-16">
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
            ].map((s, i) => (
              <div key={s.stat} className={i > 1 ? 'hidden sm:block' : ''}>
              <FadeUp>
                <div className="card p-4 sm:p-6 h-full flex flex-col gap-3">
                  <span className={`font-display text-4xl sm:text-5xl md:text-6xl tabular-nums ${s.color}`}>{s.stat}</span>
                  <p className="text-sm font-medium leading-snug">{s.label}</p>
                  <p className="text-xs text-muted mt-auto hidden sm:block">{s.sub}</p>
                </div>
              </FadeUp>
              </div>
            ))}
          </div>

          <div className="hidden md:block">
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
        </div>
      </section>

      {/* ── INGREDIENT REALITY STRIP ── */}
      <section className="hidden md:block py-10 md:py-24 px-6 bg-bg">
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
        className="hidden md:block border-y border-border bg-card/40 overflow-hidden"
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

      <section className="relative max-w-6xl mx-auto px-4 sm:px-6 py-10 sm:py-12 md:py-32">
        <div
          aria-hidden
          className="pointer-events-none absolute -top-10 -left-20 size-72 bg-primary/8 blur-3xl rounded-full parallax-slow"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute bottom-10 -right-20 size-72 bg-primary/8 blur-3xl rounded-full parallax-med"
        />

        <FadeUp>
          <div className="max-w-2xl mb-8 sm:mb-10 md:mb-24">
            <div className="inline-flex items-center gap-2 text-[11px] uppercase tracking-[0.22em] text-primary font-semibold mb-4">
              <span className="h-px w-8 bg-primary/40" /> How it works
            </div>
            <h2 className="font-display text-[2.6rem] sm:text-5xl md:text-7xl leading-[0.98] md:leading-[0.95] tracking-tight">
              Three steps.
              <br />
              <span className="italic font-light text-primary">Zero detective work.</span>
            </h2>
          </div>
        </FadeUp>

        <ol className="relative space-y-7 sm:space-y-10 md:space-y-28">
          <div
            aria-hidden
            className="hidden md:block absolute left-[60px] top-4 bottom-4 w-px bg-gradient-to-b from-transparent via-primary/30 to-transparent"
          />

          {STEPS.map((s, i) => (
            <FadeUp key={s.n} delay={i * 80} variant={i % 2 === 0 ? 'left' : 'right'}>
              <li className="group relative grid grid-cols-[56px_1fr] md:grid-cols-[120px_1fr_minmax(0,360px)] gap-x-4 md:gap-x-10 gap-y-4 md:gap-y-6 items-start">
                <div className="relative flex items-baseline gap-3 md:block">
                  <div className="relative">
                    <div
                      className="font-display text-5xl sm:text-7xl md:text-8xl leading-none bg-clip-text text-transparent transition-all duration-500 ease-emil group-hover:scale-105"
                      style={{
                        backgroundImage:
                          'linear-gradient(135deg, rgba(163,88,72,0.9) 0%, rgba(163,88,72,0.25) 60%, rgba(163,88,72,0.05) 100%)',
                      }}
                    >
                      {s.n}
                    </div>
                    <div
                      aria-hidden
                      className="absolute inset-0 font-display text-5xl sm:text-7xl md:text-8xl leading-none text-primary/5 select-none translate-x-1 translate-y-1 -z-10"
                    >
                      {s.n}
                    </div>
                  </div>
                  <div className="hidden md:inline-flex md:mt-3 items-center justify-center size-9 rounded-full bg-primary/10 border border-primary/20 text-primary shadow-[0_0_20px_rgba(163,88,72,0.15)] group-hover:bg-primary group-hover:text-card transition-all duration-400 ease-emil">
                    {s.icon}
                  </div>
                </div>

                <div className="max-w-[55ch] md:pt-3">
                  <h3 className="font-display text-2xl sm:text-3xl md:text-4xl mb-2 sm:mb-4 leading-[1.05] tracking-tight">
                    {s.title}
                  </h3>
                  <p className="text-muted text-sm sm:text-base md:text-lg leading-relaxed">{s.body}</p>
                </div>

                <div className="hidden md:block md:pt-3">
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

      <section id="founding" className="max-w-6xl mx-auto px-4 sm:px-6 py-8 sm:py-10 md:py-12 scroll-mt-24">
        <FadeUp>
          <ComingSoonWaitlist />
        </FadeUp>
      </section>

      <section className="max-w-6xl mx-auto px-4 sm:px-6 py-10 md:py-24">
        <FadeUp>
          <div className="max-w-2xl mb-8 md:mb-12">
            <div className="text-xs uppercase tracking-[0.18em] text-muted font-medium mb-3">
              Pricing
            </div>
            <h2 className="font-display text-4xl md:text-5xl leading-tight mb-4">
              One plan. Less than
              <br />
              the serum you just regretted.
            </h2>
            <p className="text-muted text-lg max-w-[52ch] leading-relaxed">
              Start free, upgrade when you want the full scanner. No annual lock-in.
            </p>
          </div>
        </FadeUp>

        <div className="grid md:grid-cols-3 gap-5">
          {PRICING.map((p, i) => (
            <div key={p.id} className={p.highlight ? '' : 'hidden md:block'}>
            <FadeUp delay={i * 80}>
              <Tilt3D max={4} lift={6} shine={false} className="h-full">
              <div
                className={`card p-7 h-full relative overflow-hidden flex flex-col transition-shadow duration-300 ease-emil hover:shadow-[0_30px_60px_-20px_rgba(163,88,72,0.25)] ${
                  p.highlight ? 'border-primary/30 shadow-soft' : ''
                }`}
              >
                {p.highlight && (
                  <div
                    aria-hidden
                    className="absolute -top-12 -right-12 size-44 bg-primary/8 blur-3xl rounded-full"
                  />
                )}
                <div
                  aria-hidden
                  className="pointer-events-none absolute inset-0 rounded-card"
                  style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }}
                />
                <div className="relative flex-1">
                  <div
                    className={`inline-flex items-center gap-1.5 text-[10px] uppercase tracking-[0.18em] px-2.5 py-1 rounded-full mb-4 font-semibold border ${
                      p.highlight
                        ? 'text-primary bg-primary/10 border-primary/25 shadow-[0_0_18px_rgba(163,88,72,0.15)]'
                        : 'text-muted/80 bg-bg/60 border-border'
                    }`}
                  >
                    {p.highlight && <Sparkles size={10} />}
                    {p.tagline}
                  </div>
                  <div className="font-display text-2xl mb-3 leading-none">{p.name}</div>
                  <div className="flex items-baseline gap-2 mb-3">
                    <div
                      className={`font-display text-6xl leading-none ${
                        p.highlight ? 'text-primary' : 'text-ink'
                      }`}
                    >
                      {p.price}
                    </div>
                    <div className="text-muted text-sm font-medium">{p.cadence}</div>
                  </div>
                  <div
                    className={`relative mb-6 pl-4 py-2 rounded-r-lg border-l-2 ${
                      p.highlight
                        ? 'border-primary bg-gradient-to-r from-primary/10 to-transparent'
                        : 'border-primary/40 bg-gradient-to-r from-primary/5 to-transparent'
                    }`}
                  >
                    <span
                      aria-hidden
                      className="absolute -left-[6px] top-2 size-2.5 rounded-full bg-primary shadow-[0_0_10px_rgba(163,88,72,0.6)]"
                    />
                    <p className="text-[15px] text-ink/85 italic leading-snug font-serif max-w-[34ch]">
                      "{p.blurb}"
                    </p>
                  </div>

                  <ul className="space-y-3 mb-6 text-sm">
                    {p.features.map((f, fi) => (
                      <li
                        key={f.text}
                        className="flex items-center gap-3 group/feat"
                        style={{ transitionDelay: `${fi * 40}ms` }}
                      >
                        <span
                          className={`relative shrink-0 size-5 transition-all duration-300 group-hover/feat:scale-110 ${
                            p.highlight ? 'rotate-[8deg]' : ''
                          }`}
                        >
                          <span
                            aria-hidden
                            className={`absolute inset-0 rounded-md rotate-45 transition-all duration-300 ${
                              p.highlight
                                ? 'bg-gradient-to-br from-primary to-primary-hover shadow-[0_4px_14px_-2px_rgba(163,88,72,0.55)]'
                                : 'bg-gradient-to-br from-primary/15 to-primary/5 border border-primary/25 group-hover/feat:from-primary group-hover/feat:to-primary-hover group-hover/feat:border-transparent group-hover/feat:shadow-[0_4px_14px_-2px_rgba(163,88,72,0.45)]'
                            }`}
                          />
                          <span
                            className={`relative z-10 flex items-center justify-center h-full w-full transition-colors duration-300 ${
                              p.highlight
                                ? 'text-card'
                                : 'text-primary group-hover/feat:text-card'
                            }`}
                          >
                            <Check size={11} strokeWidth={3.5} />
                          </span>
                        </span>
                        <span className="text-ink/85 leading-snug group-hover/feat:text-ink transition-colors duration-200 flex-1">
                          {f.text}
                        </span>
                        <span className="shrink-0 opacity-90 group-hover/feat:opacity-100 transition-opacity">
                          <FeatureDemo kind={f.demo} />
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>

                <div className="space-y-2 relative z-20" style={{ transform: 'translateZ(40px)' }}>
                  <Link
                    to={p.href}
                    className={`${
                      p.highlight ? 'btn-primary' : 'btn-secondary'
                    } w-full active:scale-[0.97] hover:scale-[1.02] transition-transform duration-150 ease-emil relative cursor-pointer`}
                  >
                    {p.cta} <ArrowRight size={14} />
                  </Link>
                  <button
                    type="button"
                    onClick={() => setDemoPlan(p.id)}
                    className="w-full inline-flex items-center justify-center gap-2 text-xs uppercase tracking-[0.18em] font-semibold text-primary hover:text-primary-hover hover:scale-[1.03] active:scale-[0.97] transition-all duration-200 ease-emil py-2 group/demo cursor-pointer relative"
                  >
                    <span className="relative flex h-1.5 w-1.5">
                      <span className="absolute inline-flex h-full w-full rounded-full bg-primary animate-ping opacity-75" />
                      <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-primary" />
                    </span>
                    See it in action
                    <ArrowRight size={12} className="group-hover/demo:translate-x-0.5 transition-transform duration-200" />
                  </button>
                </div>
              </div>
              </Tilt3D>
            </FadeUp>
            </div>
          ))}
        </div>
        <Link to="/pricing" className="btn-secondary w-full mt-4 md:hidden">
          Compare all plans <ArrowRight size={14} />
        </Link>
      </section>

      {demoPlan && (
        <PlanDemoModal planId={demoPlan} onClose={() => setDemoPlan(null)} />
      )}

      <section className="max-w-3xl mx-auto px-4 sm:px-6 py-10 md:py-24">
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
              <div key={i} className={i > 3 ? 'hidden sm:block' : ''}>
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

      <footer className="max-w-6xl mx-auto px-4 sm:px-6 py-10 sm:py-12 border-t border-border text-sm text-muted relative">
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
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 pt-6 border-t border-border pb-24 sm:pb-0">
          <span>© {new Date().getFullYear()} Skintel. All rights reserved.</span>
          <span className="text-xs">Not medical advice. Patterns, not prescriptions.</span>
        </div>
      </footer>

      {/* ── STICKY MOBILE CTA ── */}
      <div
        className={`sm:hidden fixed bottom-0 inset-x-0 z-40 transition-transform duration-300 ease-emil ${
          showBar ? 'translate-y-0' : 'translate-y-full'
        }`}
      >
        <div
          className="bg-bg/95 backdrop-blur-xl border-t border-border px-4 pt-3 flex items-center gap-3"
          style={{ paddingBottom: 'calc(0.75rem + env(safe-area-inset-bottom))' }}
        >
          <div className="flex-1 min-w-0">
            <div className="text-sm font-medium leading-tight">
              {soldOut ? 'Founding batch sold out' : '6 months of Pro — $20'}
            </div>
            <div className="text-[11px] text-muted truncate">
              {soldOut
                ? 'Join the waitlist for launch'
                : typeof remaining === 'number'
                  ? `${remaining} of ${total} seats left · no auto-renew`
                  : 'Limited founding seats · no auto-renew'}
            </div>
          </div>
          {soldOut ? (
            <a href="#founding" className="btn-primary shrink-0 active:scale-[0.97] transition-transform duration-150 ease-emil">
              Waitlist <ArrowRight size={14} />
            </a>
          ) : (
            <a href={checkoutHref} className="btn-primary shrink-0 active:scale-[0.97] transition-transform duration-150 ease-emil">
              Claim <ArrowRight size={14} />
            </a>
          )}
        </div>
      </div>
    </div>
  );
}
