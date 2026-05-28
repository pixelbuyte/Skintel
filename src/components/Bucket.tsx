import { useEffect, useRef, useState } from 'react';
import { ChevronDown } from 'lucide-react';
import type { BucketRow } from '@/lib/ingredient-knowledge';

type Tone = 'bad' | 'good' | 'muted';

const TONE: Record<Tone, {
  headerCls: string;
  rowCls: string;
  meta: string;
  dot: string;
  accent: string;
}> = {
  bad: {
    headerCls: 'text-bad-fg',
    rowCls: 'bg-bad-bg/50 border border-bad-fg/20 hover:border-bad-fg/40',
    meta: 'text-bad-fg/80',
    dot: 'bg-bad-fg',
    accent: 'bg-bad-fg/30',
  },
  good: {
    headerCls: 'text-good-fg',
    rowCls: 'bg-good-bg/50 border border-good-fg/20 hover:border-good-fg/40',
    meta: 'text-good-fg/80',
    dot: 'bg-good-fg',
    accent: 'bg-good-fg/30',
  },
  muted: {
    headerCls: 'text-ink',
    rowCls: 'bg-bg border border-border hover:border-border/80',
    meta: 'text-muted',
    dot: 'bg-muted',
    accent: 'bg-border',
  },
};

function Row({ row, tone, index }: { row: BucketRow; tone: Tone; index: number }) {
  const [shown, setShown] = useState(false);
  const t = TONE[tone];

  useEffect(() => {
    const timer = setTimeout(() => setShown(true), index * 55);
    return () => clearTimeout(timer);
  }, [index]);

  let meta: string | null = null;
  if (row.culprit) meta = `in ${row.culprit.badCount} of your breakouts`;
  else if (row.info && tone === 'good') meta = row.info.benefit;
  else if (row.isFragrance) meta = 'common irritant';
  else if (row.info) meta = row.info.benefit;

  return (
    <div
      className={`flex items-center gap-3 rounded-2xl px-4 py-3 transition-all duration-200 ${t.rowCls}`}
      style={{
        opacity: shown ? 1 : 0,
        transform: shown ? 'translateX(0) scale(1)' : 'translateX(-10px) scale(0.98)',
        transition: `opacity 350ms cubic-bezier(0.22,1,0.36,1), transform 350ms cubic-bezier(0.22,1,0.36,1), border-color 150ms ease`,
      }}
    >
      {/* accent dot */}
      <span
        className={`shrink-0 size-1.5 rounded-full ${t.dot}`}
        style={{
          transform: shown ? 'scale(1)' : 'scale(0)',
          transition: `transform 300ms cubic-bezier(0.34,1.56,0.64,1) ${index * 55 + 100}ms`,
        }}
      />
      <span className="font-mono text-sm break-all flex-1">{row.raw}</span>
      {meta && (
        <span
          className={`text-xs shrink-0 text-right leading-tight ${t.meta}`}
          style={{
            opacity: shown ? 1 : 0,
            transition: `opacity 300ms ease ${index * 55 + 180}ms`,
          }}
        >
          {meta}
        </span>
      )}
    </div>
  );
}

function BucketHeader({ title, count, tone }: { title: string; count: number; tone: Tone }) {
  const [displayCount, setDisplayCount] = useState(0);
  const t = TONE[tone];

  useEffect(() => {
    setDisplayCount(0);
    let n = 0;
    const step = () => {
      n = Math.min(n + 1, count);
      setDisplayCount(n);
      if (n < count) setTimeout(step, 40);
    };
    setTimeout(step, 100);
  }, [count]);

  return (
    <div className={`flex items-center gap-2 text-xs uppercase tracking-wide font-semibold mb-3 ${t.headerCls}`}>
      <span className={`h-px flex-none w-5 ${t.accent} rounded-full`} />
      {title}
      <span className="opacity-60 font-mono tabular-nums">· {displayCount}</span>
    </div>
  );
}

export function Bucket({ title, tone, rows }: { title: string; tone: Tone; rows: BucketRow[] }) {
  if (rows.length === 0) return null;
  return (
    <div>
      <BucketHeader title={title} count={rows.length} tone={tone} />
      <div className="space-y-1.5">
        {rows.map((r, i) => (
          <Row key={`${r.raw}-${i}`} row={r} tone={tone} index={i} />
        ))}
      </div>
    </div>
  );
}

export function CollapsibleBucket({ title, tone, rows }: { title: string; tone: Tone; rows: BucketRow[] }) {
  const [open, setOpen] = useState(false);
  if (rows.length === 0) return null;
  const t = TONE[tone];
  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className={`w-full flex items-center justify-between text-xs uppercase tracking-wide font-semibold ${t.headerCls} min-h-11`}
        aria-expanded={open}
      >
        <span className="flex items-center gap-2">
          <span className={`h-px w-5 ${t.accent} rounded-full`} />
          {title} <span className="opacity-60 font-mono">· {rows.length}</span>
        </span>
        <ChevronDown size={16} className={`transition-transform duration-300 ${open ? 'rotate-180' : ''}`} />
      </button>
      <div
        style={{
          display: 'grid',
          gridTemplateRows: open ? '1fr' : '0fr',
          transition: 'grid-template-rows 300ms cubic-bezier(0.22,1,0.36,1)',
        }}
      >
        <div className="overflow-hidden">
          <div className="space-y-1.5 mt-2">
            {rows.map((r, i) => (
              <Row key={`${r.raw}-${i}`} row={r} tone={tone} index={open ? i : 0} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
