import { useEffect, useState } from 'react';
import { Check, AlertTriangle, ChevronDown, Droplets, Shield, Leaf, Zap, FlaskConical } from 'lucide-react';
import type { BucketRow } from '@/lib/ingredient-knowledge';

type Tone = 'bad' | 'good' | 'muted';

// per-tone color tokens
const CFG: Record<Tone, {
  header: string;
  accent: string;
  orb1: string; orb2: string;
  border: string;
  spin1: string; spin2: string; spin3: string;
  badgeBg: string; badgeFg: string;
  iconBg: string; iconFg: string;
  metaCls: string;
}> = {
  good: {
    header: 'text-good-fg',
    accent: 'rgba(34,197,94,',
    orb1: 'rgba(34,197,94,0.12)', orb2: 'rgba(16,185,129,0.08)',
    border: 'rgba(34,197,94,0.25)',
    spin1: 'rgba(34,197,94,0)', spin2: 'rgba(34,197,94,0.6)', spin3: 'rgba(167,243,208,0.8)',
    badgeBg: 'rgba(34,197,94,0.12)', badgeFg: '#16a34a',
    iconBg: 'rgba(34,197,94,0.12)', iconFg: '#16a34a',
    metaCls: 'text-good-fg',
  },
  bad: {
    header: 'text-bad-fg',
    accent: 'rgba(239,68,68,',
    orb1: 'rgba(239,68,68,0.12)', orb2: 'rgba(220,38,38,0.08)',
    border: 'rgba(239,68,68,0.25)',
    spin1: 'rgba(239,68,68,0)', spin2: 'rgba(239,68,68,0.6)', spin3: 'rgba(252,165,165,0.8)',
    badgeBg: 'rgba(239,68,68,0.12)', badgeFg: '#dc2626',
    iconBg: 'rgba(239,68,68,0.12)', iconFg: '#dc2626',
    metaCls: 'text-bad-fg',
  },
  muted: {
    header: 'text-ink',
    accent: 'rgba(120,120,120,',
    orb1: 'rgba(120,120,120,0.06)', orb2: 'rgba(80,80,80,0.04)',
    border: 'rgba(120,120,120,0.2)',
    spin1: 'rgba(120,120,120,0)', spin2: 'rgba(120,120,120,0.3)', spin3: 'rgba(200,200,200,0.4)',
    badgeBg: 'rgba(120,120,120,0.1)', badgeFg: '#888',
    iconBg: 'rgba(120,120,120,0.1)', iconFg: '#888',
    metaCls: 'text-muted',
  },
};

function ingredientIcon(name: string): React.ReactNode {
  const n = name.toLowerCase();
  if (n.includes('hyaluron') || n.includes('glycer') || n.includes('aqua')) return <Droplets size={14} />;
  if (n.includes('ceramide') || n.includes('panthenol') || n.includes('squalane')) return <Shield size={14} />;
  if (n.includes('niacinamide') || n.includes('vitamin') || n.includes('retinol')) return <Zap size={14} />;
  if (n.includes('bisabolol') || n.includes('centella') || n.includes('aloe')) return <Leaf size={14} />;
  if (n.includes('fragrance') || n.includes('parfum') || n.includes('linalool') || n.includes('limonene')) return <AlertTriangle size={14} />;
  return <FlaskConical size={14} />;
}

// unique id per Row instance for scoped CSS
let _uid = 0;

function Row({ row, tone, index }: { row: BucketRow; tone: Tone; index: number }) {
  const [uid] = useState(() => ++_uid);
  const [shown, setShown] = useState(false);
  const cfg = CFG[tone];

  useEffect(() => {
    const t = setTimeout(() => setShown(true), index * 70);
    return () => clearTimeout(t);
  }, [index]);

  let meta: string | null = null;
  if (row.culprit) meta = `found in ${row.culprit.badCount} of your breakouts`;
  else if (row.info && tone === 'good') meta = row.info.benefit;
  else if (row.isFragrance) meta = 'common irritant';
  else if (row.info) meta = row.info.benefit;

  const spinId = `row-spin-${uid}`;

  return (
    <>
      <style>{`
        @property --${spinId} {
          syntax: '<angle>';
          initial-value: 0deg;
          inherits: false;
        }
        @keyframes ${spinId}-anim {
          to { --${spinId}: 360deg; }
        }
        .${spinId}-el {
          animation: ${spinId}-anim ${7 + (index % 3)}s linear infinite;
        }
        @keyframes shimmer-${uid} {
          0% { transform: translateX(-120%) skewX(-12deg); }
          100% { transform: translateX(220%) skewX(-12deg); }
        }
        .shimmer-${uid} {
          animation: shimmer-${uid} 3.5s ease-in-out ${index * 0.4}s infinite;
        }
        @keyframes orb-${uid} {
          0%, 100% { transform: scale(1) translate(0,0); opacity: 0.7; }
          50% { transform: scale(1.3) translate(4px,-4px); opacity: 1; }
        }
        .orb-${uid} {
          animation: orb-${uid} ${4 + index}s ease-in-out infinite;
        }
      `}</style>

      <div
        className="relative overflow-hidden rounded-2xl cursor-default"
        style={{
          opacity: shown ? 1 : 0,
          transform: shown ? 'translateY(0) scale(1)' : 'translateY(12px) scale(0.96)',
          transition: `opacity 450ms cubic-bezier(0.22,1,0.36,1) ${index * 70}ms, transform 450ms cubic-bezier(0.22,1,0.36,1) ${index * 70}ms`,
          background: 'var(--card)',
          border: `1px solid ${cfg.border}`,
        }}
      >
        {/* rotating conic border glow */}
        <div
          className={`pointer-events-none absolute -inset-px rounded-2xl ${spinId}-el`}
          style={{
            background: `conic-gradient(from var(--${spinId}, 0deg), ${cfg.spin1} 0%, ${cfg.spin2} 20%, ${cfg.spin3} 30%, ${cfg.spin2} 40%, ${cfg.spin1} 60%, ${cfg.spin1} 100%)`,
            filter: 'blur(5px)',
            opacity: 0.6,
          }}
        />

        {/* ambient orbs */}
        <div className={`pointer-events-none absolute -top-6 -right-6 size-20 rounded-full orb-${uid}`}
          style={{ background: cfg.orb1, filter: 'blur(20px)' }} />
        <div className={`pointer-events-none absolute -bottom-6 -left-6 size-16 rounded-full orb-${uid}`}
          style={{ background: cfg.orb2, filter: 'blur(16px)', animationDelay: '2s' }} />

        {/* shimmer sweep */}
        <div className={`pointer-events-none absolute inset-0 shimmer-${uid}`}
          style={{ background: `linear-gradient(105deg, transparent 40%, ${cfg.accent}0.08) 50%, transparent 60%)`, width: '60%' }} />

        {/* card content */}
        <div className="relative flex items-center gap-3 px-4 py-3.5" style={{ background: 'rgba(var(--card-rgb, 20,20,20), 0.85)', backdropFilter: 'blur(4px)' }}>
          {/* icon */}
          <div
            className="shrink-0 size-9 rounded-xl flex items-center justify-center"
            style={{
              background: cfg.iconBg,
              color: cfg.iconFg,
              transform: shown ? 'scale(1)' : 'scale(0.4)',
              opacity: shown ? 1 : 0,
              transition: `transform 500ms cubic-bezier(0.34,1.56,0.64,1) ${index * 70 + 100}ms, opacity 300ms ease ${index * 70 + 100}ms`,
            }}
          >
            {ingredientIcon(row.raw)}
          </div>

          {/* text block */}
          <div className="flex-1 min-w-0">
            <div className="text-sm font-semibold leading-tight text-ink truncate">{row.raw}</div>
            {meta && (
              <div
                className={`text-xs mt-0.5 leading-snug ${cfg.metaCls}`}
                style={{
                  opacity: shown ? 0.8 : 0,
                  transition: `opacity 400ms ease ${index * 70 + 220}ms`,
                }}
              >
                {meta}
              </div>
            )}
          </div>

          {/* badge */}
          <div
            className="shrink-0 flex items-center gap-1 text-[10px] font-bold px-2.5 py-1 rounded-full"
            style={{
              background: cfg.badgeBg,
              color: cfg.badgeFg,
              opacity: shown ? 1 : 0,
              transform: shown ? 'scale(1)' : 'scale(0.6)',
              transition: `opacity 350ms ease ${index * 70 + 280}ms, transform 400ms cubic-bezier(0.34,1.56,0.64,1) ${index * 70 + 280}ms`,
            }}
          >
            {tone === 'good' ? <Check size={9} strokeWidth={3} /> : tone === 'bad' ? <AlertTriangle size={9} strokeWidth={2.5} /> : null}
            <span>{tone === 'good' ? 'safe' : tone === 'bad' ? 'watch' : '—'}</span>
          </div>
        </div>
      </div>
    </>
  );
}

function BucketHeader({ title, count, tone }: { title: string; count: number; tone: Tone }) {
  const [n, setN] = useState(0);
  const cfg = CFG[tone];
  useEffect(() => {
    setN(0);
    let c = 0;
    const step = () => { c = Math.min(c + 1, count); setN(c); if (c < count) setTimeout(step, 35); };
    setTimeout(step, 80);
  }, [count]);
  return (
    <div className={`flex items-center gap-2.5 text-[11px] uppercase tracking-[0.18em] font-bold mb-3 ${cfg.header}`}>
      <span className="h-px w-6 rounded-full" style={{ background: cfg.border }} />
      {title}
      <span className="inline-flex items-center justify-center size-5 rounded-full text-[10px] font-bold tabular-nums"
        style={{ background: cfg.badgeBg, color: cfg.badgeFg }}>
        {n}
      </span>
    </div>
  );
}

export function Bucket({ title, tone, rows }: { title: string; tone: Tone; rows: BucketRow[] }) {
  if (rows.length === 0) return null;
  return (
    <div>
      <BucketHeader title={title} count={rows.length} tone={tone} />
      <div className="space-y-2">
        {rows.map((r, i) => <Row key={`${r.raw}-${i}`} row={r} tone={tone} index={i} />)}
      </div>
    </div>
  );
}

export function CollapsibleBucket({ title, tone, rows }: { title: string; tone: Tone; rows: BucketRow[] }) {
  const [open, setOpen] = useState(false);
  if (rows.length === 0) return null;
  const cfg = CFG[tone];
  return (
    <div>
      <button type="button" onClick={() => setOpen(v => !v)}
        className={`w-full flex items-center justify-between text-[11px] uppercase tracking-[0.18em] font-bold ${cfg.header} min-h-11`}
        aria-expanded={open}>
        <span className="flex items-center gap-2.5">
          <span className="h-px w-6 rounded-full" style={{ background: cfg.border }} />
          {title}
          <span className="inline-flex items-center justify-center size-5 rounded-full text-[10px] font-bold"
            style={{ background: cfg.badgeBg, color: cfg.badgeFg }}>{rows.length}</span>
        </span>
        <ChevronDown size={15} className={`transition-transform duration-300 ${open ? 'rotate-180' : ''}`} />
      </button>
      <div style={{ display: 'grid', gridTemplateRows: open ? '1fr' : '0fr', transition: 'grid-template-rows 320ms cubic-bezier(0.22,1,0.36,1)' }}>
        <div className="overflow-hidden">
          <div className="space-y-2 mt-2">
            {rows.map((r, i) => <Row key={`${r.raw}-${i}`} row={r} tone={tone} index={open ? i : 999} />)}
          </div>
        </div>
      </div>
    </div>
  );
}
