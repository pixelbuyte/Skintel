import { useState } from 'react';
import { ChevronDown } from 'lucide-react';
import type { BucketRow } from '@/lib/ingredient-knowledge';

type Tone = 'bad' | 'good' | 'muted';

const TONE: Record<Tone, { headerCls: string; rowCls: string; meta: string }> = {
  bad: {
    headerCls: 'text-bad-fg',
    rowCls: 'bg-bad-bg/60 border border-bad-fg/15',
    meta: 'text-bad-fg/80',
  },
  good: {
    headerCls: 'text-good-fg',
    rowCls: 'bg-good-bg/60 border border-good-fg/15',
    meta: 'text-good-fg/80',
  },
  muted: {
    headerCls: 'text-ink',
    rowCls: 'bg-bg border border-border',
    meta: 'text-muted',
  },
};

function Row({ row, tone }: { row: BucketRow; tone: Tone }) {
  const t = TONE[tone];
  let meta: string | null = null;
  if (row.culprit) {
    meta = `in ${row.culprit.badCount} of your breakouts`;
  } else if (row.info && tone === 'good') {
    meta = row.info.benefit;
  } else if (row.isFragrance) {
    meta = 'common irritant';
  } else if (row.info) {
    meta = row.info.benefit;
  }
  return (
    <div className={`flex items-center justify-between gap-3 rounded-2xl px-4 py-2.5 ${t.rowCls}`}>
      <span className="font-mono text-sm break-all">{row.raw}</span>
      {meta && <span className={`text-xs shrink-0 text-right ${t.meta}`}>{meta}</span>}
    </div>
  );
}

export function Bucket({
  title,
  tone,
  rows,
}: {
  title: string;
  tone: Tone;
  rows: BucketRow[];
}) {
  if (rows.length === 0) return null;
  const t = TONE[tone];
  return (
    <div>
      <div className={`text-xs uppercase tracking-wide font-medium mb-2 ${t.headerCls}`}>
        {title} <span className="opacity-70">· {rows.length}</span>
      </div>
      <div className="space-y-2">
        {rows.map((r, i) => (
          <Row key={`${r.raw}-${i}`} row={r} tone={tone} />
        ))}
      </div>
    </div>
  );
}

export function CollapsibleBucket({
  title,
  tone,
  rows,
}: {
  title: string;
  tone: Tone;
  rows: BucketRow[];
}) {
  const [open, setOpen] = useState(false);
  if (rows.length === 0) return null;
  const t = TONE[tone];
  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className={`w-full flex items-center justify-between text-xs uppercase tracking-wide font-medium ${t.headerCls} min-h-11`}
        aria-expanded={open}
      >
        <span>
          {title} <span className="opacity-70">· {rows.length}</span>
        </span>
        <ChevronDown size={16} className={`transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div className="space-y-2 mt-2">
          {rows.map((r, i) => (
            <Row key={`${r.raw}-${i}`} row={r} tone={tone} />
          ))}
        </div>
      )}
    </div>
  );
}
