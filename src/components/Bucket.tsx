import { useEffect, useState } from 'react';
import { Check, AlertTriangle, ChevronDown, Droplets, Shield, Leaf, Zap, Sparkles, FlaskConical } from 'lucide-react';
import type { BucketRow } from '@/lib/ingredient-knowledge';

type Tone = 'bad' | 'good' | 'muted';

const TONE_CFG: Record<Tone, {
  header: string;
  cardBg: string;
  cardBorder: string;
  cardHover: string;
  glow: string;
  nameCls: string;
  metaCls: string;
  badgeBg: string;
  badgeFg: string;
  badgeIcon: React.ReactNode;
  accentBar: string;
  iconBg: string;
  iconFg: string;
  accent: string;
}> = {
  good: {
    header: 'text-good-fg',
    cardBg: 'bg-good-bg/40',
    cardBorder: 'border-good-fg/20',
    cardHover: 'hover:border-good-fg/50 hover:bg-good-bg/60',
    glow: 'rgba(34,197,94,0.08)',
    nameCls: 'text-ink',
    metaCls: 'text-good-fg',
    badgeBg: 'bg-good-fg/15',
    badgeFg: 'text-good-fg',
    badgeIcon: <Check size={10} strokeWidth={3} />,
    accentBar: 'bg-good-fg/60',
    iconBg: 'bg-good-fg/15',
    iconFg: 'text-good-fg',
    accent: 'bg-good-fg/25',
  },
  bad: {
    header: 'text-bad-fg',
    cardBg: 'bg-bad-bg/40',
    cardBorder: 'border-bad-fg/20',
    cardHover: 'hover:border-bad-fg/50 hover:bg-bad-bg/60',
    glow: 'rgba(239,68,68,0.08)',
    nameCls: 'text-ink',
    metaCls: 'text-bad-fg',
    badgeBg: 'bg-bad-fg/15',
    badgeFg: 'text-bad-fg',
    badgeIcon: <AlertTriangle size={10} strokeWidth={2.5} />,
    accentBar: 'bg-bad-fg/60',
    iconBg: 'bg-bad-fg/15',
    iconFg: 'text-bad-fg',
    accent: 'bg-bad-fg/25',
  },
  muted: {
    header: 'text-ink',
    cardBg: 'bg-bg/60',
    cardBorder: 'border-border',
    cardHover: 'hover:border-border/60',
    glow: 'transparent',
    nameCls: 'text-ink',
    metaCls: 'text-muted',
    badgeBg: 'bg-border/60',
    badgeFg: 'text-muted',
    badgeIcon: null,
    accentBar: 'bg-border',
    iconBg: 'bg-border/40',
    iconFg: 'text-muted',
    accent: 'bg-border',
  },
};

// Pick a small icon per ingredient name
function ingredientIcon(name: string): React.ReactNode {
  const n = name.toLowerCase();
  if (n.includes('hyaluron') || n.includes('glycer') || n.includes('aqua')) return <Droplets size={13} />;
  if (n.includes('ceramide') || n.includes('panthenol') || n.includes('squalane')) return <Shield size={13} />;
  if (n.includes('niacinamide') || n.includes('vitamin') || n.includes('retinol')) return <Zap size={13} />;
  if (n.includes('bisabolol') || n.includes('centella') || n.includes('aloe')) return <Leaf size={13} />;
  if (n.includes('fragrance') || n.includes('parfum') || n.includes('linalool') || n.includes('limonene')) return <AlertTriangle size={13} />;
  return <FlaskConical size={13} />;
}

function Row({ row, tone, index }: { row: BucketRow; tone: Tone; index: number }) {
  const [shown, setShown] = useState(false);
  const cfg = TONE_CFG[tone];

  useEffect(() => {
    const t = setTimeout(() => setShown(true), index * 65);
    return () => clearTimeout(t);
  }, [index]);

  let meta: string | null = null;
  if (row.culprit) meta = `found in ${row.culprit.badCount} of your breakouts`;
  else if (row.info && tone === 'good') meta = row.info.benefit;
  else if (row.isFragrance) meta = 'common irritant · patch test recommended';
  else if (row.info) meta = row.info.benefit;

  return (
    <div
      className={`relative flex items-center gap-3 rounded-2xl border px-4 py-3.5 cursor-default transition-all duration-200 overflow-hidden ${cfg.cardBg} ${cfg.cardBorder} ${cfg.cardHover}`}
      style={{
        opacity: shown ? 1 : 0,
        transform: shown ? 'translateY(0) scale(1)' : 'translateY(10px) scale(0.97)',
        transition: `opacity 400ms cubic-bezier(0.22,1,0.36,1) ${index * 65}ms, transform 400ms cubic-bezier(0.22,1,0.36,1) ${index * 65}ms, border-color 150ms ease, background-color 150ms ease`,
        boxShadow: shown ? `0 2px 12px ${cfg.glow}` : 'none',
      }}
    >
      {/* left accent bar */}
      <div
        className={`absolute left-0 top-3 bottom-3 w-[3px] rounded-full ${cfg.accentBar}`}
        style={{
          transform: shown ? 'scaleY(1)' : 'scaleY(0)',
          transformOrigin: 'top',
          transition: `transform 350ms cubic-bezier(0.22,1,0.36,1) ${index * 65 + 120}ms`,
        }}
      />

      {/* ingredient icon */}
      <div
        className={`shrink-0 size-8 rounded-xl flex items-center justify-center ${cfg.iconBg} ${cfg.iconFg}`}
        style={{
          transform: shown ? 'scale(1)' : 'scale(0.5)',
          opacity: shown ? 1 : 0,
          transition: `transform 400ms cubic-bezier(0.34,1.56,0.64,1) ${index * 65 + 80}ms, opacity 300ms ease ${index * 65 + 80}ms`,
        }}
      >
        {ingredientIcon(row.raw)}
      </div>

      {/* text */}
      <div className="flex-1 min-w-0">
        <div className={`text-sm font-semibold leading-tight truncate ${cfg.nameCls}`}>
          {row.raw}
        </div>
        {meta && (
          <div
            className={`text-xs mt-0.5 leading-snug ${cfg.metaCls}`}
            style={{
              opacity: shown ? 0.85 : 0,
              transition: `opacity 350ms ease ${index * 65 + 200}ms`,
            }}
          >
            {meta}
          </div>
        )}
      </div>

      {/* badge */}
      <div
        className={`shrink-0 flex items-center gap-1 text-[10px] font-semibold px-2 py-1 rounded-full ${cfg.badgeBg} ${cfg.badgeFg}`}
        style={{
          opacity: shown ? 1 : 0,
          transform: shown ? 'scale(1)' : 'scale(0.7)',
          transition: `opacity 300ms ease ${index * 65 + 250}ms, transform 350ms cubic-bezier(0.34,1.56,0.64,1) ${index * 65 + 250}ms`,
        }}
      >
        {cfg.badgeIcon}
        <span>{tone === 'good' ? 'safe' : tone === 'bad' ? 'watch' : '—'}</span>
      </div>
    </div>
  );
}

function BucketHeader({ title, count, tone }: { title: string; count: number; tone: Tone }) {
  const [displayCount, setDisplayCount] = useState(0);
  const cfg = TONE_CFG[tone];
  useEffect(() => {
    setDisplayCount(0);
    let n = 0;
    const step = () => { n = Math.min(n + 1, count); setDisplayCount(n); if (n < count) setTimeout(step, 35); };
    setTimeout(step, 80);
  }, [count]);
  return (
    <div className={`flex items-center gap-2.5 text-[11px] uppercase tracking-[0.16em] font-bold mb-3 ${cfg.header}`}>
      <span className={`h-px w-6 rounded-full ${cfg.accent}`} />
      {title}
      <span
        className={`inline-flex items-center justify-center size-5 rounded-full text-[10px] font-bold tabular-nums ${cfg.badgeBg} ${cfg.header}`}
      >
        {displayCount}
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
  const cfg = TONE_CFG[tone];
  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen(v => !v)}
        className={`w-full flex items-center justify-between text-[11px] uppercase tracking-[0.16em] font-bold ${cfg.header} min-h-11`}
        aria-expanded={open}
      >
        <span className="flex items-center gap-2.5">
          <span className={`h-px w-6 rounded-full ${cfg.accent}`} />
          {title}
          <span className={`inline-flex items-center justify-center size-5 rounded-full text-[10px] font-bold ${cfg.badgeBg} ${cfg.header}`}>
            {rows.length}
          </span>
        </span>
        <ChevronDown size={15} className={`transition-transform duration-300 ${open ? 'rotate-180' : ''}`} />
      </button>
      <div style={{ display: 'grid', gridTemplateRows: open ? '1fr' : '0fr', transition: 'grid-template-rows 320ms cubic-bezier(0.22,1,0.36,1)' }}>
        <div className="overflow-hidden">
          <div className="space-y-2 mt-2 pb-1">
            {rows.map((r, i) => <Row key={`${r.raw}-${i}`} row={r} tone={tone} index={open ? i : 999} />)}
          </div>
        </div>
      </div>
    </div>
  );
}
