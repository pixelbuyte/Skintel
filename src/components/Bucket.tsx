import { useEffect, useState } from 'react';
import { Check, AlertTriangle, ChevronDown, Droplets, Shield, Leaf, Zap, FlaskConical } from 'lucide-react';
import type { BucketRow } from '@/lib/ingredient-knowledge';

type Tone = 'bad' | 'good' | 'muted';

const CFG: Record<Tone, {
  accentColor: string;
  accentGlow: string;
  leftGrad: string;
  iconBg: string; iconFg: string;
  badgeBg: string; badgeFg: string;
  cardBorder: string;
  headerCls: string;
  headerAccent: string;
}> = {
  good: {
    accentColor: '#5C7A4F',
    accentGlow: 'rgba(92,122,79,0.25)',
    leftGrad: 'rgba(232,245,226,0.7)',
    iconBg: 'rgba(92,122,79,0.10)', iconFg: '#5C7A4F',
    badgeBg: '#EEF2DD', badgeFg: '#5C7A4F',
    cardBorder: 'rgba(92,122,79,0.18)',
    headerCls: 'text-good-fg',
    headerAccent: '#5C7A4F',
  },
  bad: {
    accentColor: '#B22B2B',
    accentGlow: 'rgba(178,43,43,0.25)',
    leftGrad: 'rgba(253,234,234,0.7)',
    iconBg: 'rgba(178,43,43,0.10)', iconFg: '#B22B2B',
    badgeBg: '#FDEAEA', badgeFg: '#B22B2B',
    cardBorder: 'rgba(178,43,43,0.18)',
    headerCls: 'text-bad-fg',
    headerAccent: '#B22B2B',
  },
  muted: {
    accentColor: '#6B6760',
    accentGlow: 'rgba(107,103,96,0.15)',
    leftGrad: 'rgba(234,230,223,0.5)',
    iconBg: 'rgba(107,103,96,0.08)', iconFg: '#6B6760',
    badgeBg: '#EAE6DF', badgeFg: '#6B6760',
    cardBorder: 'rgba(107,103,96,0.15)',
    headerCls: 'text-muted',
    headerAccent: '#6B6760',
  },
};

function ingredientIcon(name: string): React.ReactNode {
  const n = name.toLowerCase();
  if (n.includes('hyaluron') || n.includes('glycer') || n.includes('aqua')) return <Droplets size={15} />;
  if (n.includes('ceramide') || n.includes('panthenol') || n.includes('squalane')) return <Shield size={15} />;
  if (n.includes('niacinamide') || n.includes('vitamin') || n.includes('retinol')) return <Zap size={15} />;
  if (n.includes('bisabolol') || n.includes('centella') || n.includes('aloe')) return <Leaf size={15} />;
  if (n.includes('fragrance') || n.includes('parfum') || n.includes('linalool') || n.includes('limonene')) return <AlertTriangle size={15} />;
  return <FlaskConical size={15} />;
}

function Row({ row, tone, index }: { row: BucketRow; tone: Tone; index: number }) {
  const [shown, setShown] = useState(false);
  const cfg = CFG[tone];

  useEffect(() => {
    const t = setTimeout(() => setShown(true), index * 55);
    return () => clearTimeout(t);
  }, [index]);

  let meta: string | null = null;
  if (row.culprit) meta = `triggered ${row.culprit.badCount}× in your history`;
  else if (row.info && tone === 'good') meta = row.info.benefit;
  else if (row.isFragrance) meta = 'common irritant — skip if sensitive';
  else if (row.info) meta = row.info.benefit;

  return (
    <div
      className="relative flex items-center overflow-hidden rounded-2xl"
      style={{
        background: '#FFFEFA',
        border: `1px solid ${cfg.cardBorder}`,
        boxShadow: '0 1px 4px rgba(26,24,20,0.06)',
        opacity: shown ? 1 : 0,
        transform: shown ? 'translateY(0) scale(1)' : 'translateY(14px) scale(0.97)',
        transition: `opacity 380ms cubic-bezier(0.22,1,0.36,1) ${index * 55}ms,
                     transform 380ms cubic-bezier(0.22,1,0.36,1) ${index * 55}ms`,
      }}
    >
      {/* left accent bar */}
      <div
        className="absolute left-0 top-0 bottom-0 w-[3px] rounded-l-sm"
        style={{
          background: cfg.accentColor,
          boxShadow: `3px 0 10px ${cfg.accentGlow}`,
          transform: shown ? 'scaleY(1)' : 'scaleY(0)',
          transformOrigin: 'top',
          transition: `transform 420ms cubic-bezier(0.22,1,0.36,1) ${index * 55 + 80}ms`,
        }}
      />

      {/* left color wash */}
      <div
        className="absolute left-0 top-0 bottom-0 w-20 pointer-events-none"
        style={{ background: `linear-gradient(90deg, ${cfg.leftGrad}, transparent)` }}
      />

      {/* icon */}
      <div
        className="relative shrink-0 ml-5 size-10 rounded-xl flex items-center justify-center"
        style={{
          background: cfg.iconBg,
          color: cfg.iconFg,
          opacity: shown ? 1 : 0,
          transform: shown ? 'scale(1)' : 'scale(0.5)',
          transition: `opacity 280ms ease ${index * 55 + 100}ms,
                       transform 420ms cubic-bezier(0.34,1.56,0.64,1) ${index * 55 + 100}ms`,
        }}
      >
        {ingredientIcon(row.raw)}
      </div>

      {/* text */}
      <div className="flex-1 min-w-0 py-4 px-3.5">
        <div className="text-[14px] font-bold leading-tight text-ink truncate">{row.raw}</div>
        {meta && (
          <div
            className="text-[12px] mt-0.5 leading-snug font-medium"
            style={{
              color: cfg.iconFg,
              opacity: shown ? 0.80 : 0,
              transition: `opacity 350ms ease ${index * 55 + 180}ms`,
            }}
          >
            {meta}
          </div>
        )}
      </div>

      {/* badge */}
      <div
        className="shrink-0 mr-4 flex items-center gap-1.5 font-mono text-[10px] font-bold uppercase tracking-wider px-2.5 py-1.5 rounded-full"
        style={{
          background: cfg.badgeBg,
          color: cfg.badgeFg,
          border: `1px solid ${cfg.cardBorder}`,
          opacity: shown ? 1 : 0,
          transform: shown ? 'scale(1)' : 'scale(0.65)',
          transition: `opacity 280ms ease ${index * 55 + 240}ms,
                       transform 360ms cubic-bezier(0.34,1.56,0.64,1) ${index * 55 + 240}ms`,
        }}
      >
        {tone === 'good' ? <Check size={9} strokeWidth={3} /> : tone === 'bad' ? <AlertTriangle size={9} strokeWidth={2.5} /> : null}
        <span>{tone === 'good' ? 'safe' : tone === 'bad' ? 'watch' : '—'}</span>
      </div>
    </div>
  );
}

function BucketHeader({ title, count, tone }: { title: string; count: number; tone: Tone }) {
  const [n, setN] = useState(0);
  const cfg = CFG[tone];
  useEffect(() => {
    setN(0);
    let c = 0;
    const step = () => { c = Math.min(c + 1, count); setN(c); if (c < count) setTimeout(step, 28); };
    setTimeout(step, 60);
  }, [count]);
  return (
    <div className="flex items-center gap-2.5 mb-3">
      <span
        className="h-4 w-1 rounded-full shrink-0"
        style={{ background: cfg.headerAccent, boxShadow: `0 0 8px ${cfg.headerAccent}60` }}
      />
      <span className={`text-[11px] uppercase tracking-[0.2em] font-bold flex-1 ${cfg.headerCls}`}>{title}</span>
      <span
        className="inline-flex items-center justify-center h-5 min-w-5 px-1.5 rounded-full font-mono text-[10px] font-bold tabular-nums"
        style={{
          background: cfg.badgeBg,
          color: cfg.badgeFg,
          border: `1px solid ${cfg.cardBorder}`,
        }}
      >
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
      <button
        type="button"
        onClick={() => setOpen(v => !v)}
        className={`w-full flex items-center justify-between min-h-11 ${cfg.headerCls}`}
        aria-expanded={open}
      >
        <span className="flex items-center gap-2.5">
          <span className="h-4 w-1 rounded-full" style={{ background: cfg.headerAccent, boxShadow: `0 0 8px ${cfg.headerAccent}60` }} />
          <span className="text-[11px] uppercase tracking-[0.2em] font-bold">{title}</span>
          <span
            className="inline-flex items-center justify-center h-5 min-w-5 px-1.5 rounded-full font-mono text-[10px] font-bold"
            style={{ background: cfg.badgeBg, color: cfg.badgeFg, border: `1px solid ${cfg.cardBorder}` }}
          >
            {rows.length}
          </span>
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
