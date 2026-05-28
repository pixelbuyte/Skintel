import { useEffect, useState } from 'react';
import type { Verdict } from '@/lib/ingredient-knowledge';

const TONE: Record<Verdict['tone'], {
  ringColor: string; ringGlow: string;
  trackColor: string; bgGrad: string;
  border: string; shimmer: string;
  labelFg: string; labelBg: string;
  statBorder: string;
}> = {
  good: {
    ringColor: '#2D6A2E', ringGlow: 'rgba(45,106,46,0.35)',
    trackColor: 'rgba(45,106,46,0.08)',
    bgGrad: 'linear-gradient(135deg, #E8F5E2 0%, #FFFEFA 55%)',
    border: 'rgba(45,106,46,0.20)',
    shimmer: 'rgba(45,106,46,0.10)',
    labelFg: '#2D6A2E', labelBg: 'rgba(45,106,46,0.10)',
    statBorder: 'rgba(45,106,46,0.15)',
  },
  caution: {
    ringColor: '#8B6914', ringGlow: 'rgba(139,105,20,0.30)',
    trackColor: 'rgba(139,105,20,0.08)',
    bgGrad: 'linear-gradient(135deg, #FFF4E0 0%, #FFFEFA 55%)',
    border: 'rgba(139,105,20,0.20)',
    shimmer: 'rgba(139,105,20,0.10)',
    labelFg: '#8B6914', labelBg: 'rgba(139,105,20,0.10)',
    statBorder: 'rgba(139,105,20,0.15)',
  },
  bad: {
    ringColor: '#B22B2B', ringGlow: 'rgba(178,43,43,0.35)',
    trackColor: 'rgba(178,43,43,0.08)',
    bgGrad: 'linear-gradient(135deg, #FDEAEA 0%, #FFFEFA 55%)',
    border: 'rgba(178,43,43,0.20)',
    shimmer: 'rgba(178,43,43,0.10)',
    labelFg: '#B22B2B', labelBg: 'rgba(178,43,43,0.10)',
    statBorder: 'rgba(178,43,43,0.15)',
  },
};

function AnimCount({ to, delay = 0 }: { to: number; delay?: number }) {
  const [n, setN] = useState(0);
  useEffect(() => {
    setN(0);
    if (to === 0) return;
    const tid = setTimeout(() => {
      const dur = 700;
      const start = performance.now();
      const frame = (now: number) => {
        const p = Math.min((now - start) / dur, 1);
        const ease = 1 - Math.pow(1 - p, 3);
        setN(Math.round(ease * to));
        if (p < 1) requestAnimationFrame(frame);
      };
      requestAnimationFrame(frame);
    }, delay);
    return () => clearTimeout(tid);
  }, [to, delay]);
  return <>{n}</>;
}

function stripLeadingSymbol(h: string) {
  return h.replace(/^[✓✗!~⚠]+\s*/u, '').trim();
}

export function VerdictCard({
  verdict,
  goodCount = 0,
  badCount = 0,
  totalCount = 0,
}: {
  verdict: Verdict;
  goodCount?: number;
  badCount?: number;
  totalCount?: number;
}) {
  const [phase, setPhase] = useState(0);
  const cfg = TONE[verdict.tone];

  const total = goodCount + badCount;
  const safePercent = total > 0 ? Math.round((goodCount / total) * 100) : verdict.tone === 'good' ? 100 : verdict.tone === 'caution' ? 60 : 25;

  const R = 38;
  const circ = 2 * Math.PI * R;
  const dashOffset = phase >= 1 ? circ * (1 - safePercent / 100) : circ;

  useEffect(() => {
    setPhase(0);
    const t1 = setTimeout(() => setPhase(1), 80);
    const t2 = setTimeout(() => setPhase(2), 320);
    const t3 = setTimeout(() => setPhase(3), 540);
    return () => { clearTimeout(t1); clearTimeout(t2); clearTimeout(t3); };
  }, [verdict.headline]);

  const headline = stripLeadingSymbol(verdict.headline);

  return (
    <div
      className="relative overflow-hidden rounded-card border"
      style={{
        background: cfg.bgGrad,
        borderColor: cfg.border,
        boxShadow: phase >= 3
          ? `0 0 0 1px ${cfg.border}, 0 4px 24px ${cfg.ringGlow}`
          : `0 0 0 1px ${cfg.border}`,
        transition: 'box-shadow 700ms cubic-bezier(0.22,1,0.36,1)',
      }}
    >
      {/* shimmer sweep */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 -z-0 overflow-hidden"
      >
        <div
          className="absolute inset-0"
          style={{
            background: `linear-gradient(105deg, transparent 20%, ${cfg.shimmer} 50%, transparent 80%)`,
            animation: 'vcShimmer 1s ease-out forwards',
          }}
        />
      </div>

      <div className="relative p-5">
        <div className="flex items-center gap-5">
          {/* ring */}
          <div className="relative shrink-0 size-[100px] flex items-center justify-center">
            <svg width="100" height="100" viewBox="0 0 100 100"
              style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}>
              {/* track */}
              <circle cx="50" cy="50" r={R} fill="none" stroke={cfg.trackColor} strokeWidth="6" />
              {/* arc */}
              <circle
                cx="50" cy="50" r={R}
                fill="none"
                stroke={cfg.ringColor}
                strokeWidth="6"
                strokeLinecap="round"
                strokeDasharray={circ}
                strokeDashoffset={dashOffset}
                style={{
                  transition: 'stroke-dashoffset 1.3s cubic-bezier(0.22,1,0.36,1) 120ms',
                  filter: `drop-shadow(0 0 6px ${cfg.ringGlow})`,
                }}
              />
            </svg>

            {/* center content */}
            <div
              className="relative flex flex-col items-center"
              style={{
                opacity: phase >= 1 ? 1 : 0,
                transform: phase >= 1 ? 'scale(1)' : 'scale(0.5)',
                transition: 'opacity 300ms ease 200ms, transform 500ms cubic-bezier(0.34,1.56,0.64,1) 200ms',
              }}
            >
              <span
                className="font-display leading-none tabular-nums"
                style={{
                  fontSize: safePercent === 100 ? 26 : 24,
                  color: cfg.ringColor,
                  textShadow: `0 0 14px ${cfg.ringGlow}`,
                }}
              >
                <AnimCount to={safePercent} delay={350} />%
              </span>
              <span
                className="font-mono text-[8px] uppercase tracking-widest mt-0.5"
                style={{ color: cfg.labelFg, opacity: 0.75 }}
              >
                safe
              </span>
            </div>
          </div>

          {/* headline + body */}
          <div
            className="flex-1 min-w-0"
            style={{
              opacity: phase >= 2 ? 1 : 0,
              transform: phase >= 2 ? 'translateY(0)' : 'translateY(10px)',
              transition: 'opacity 400ms ease, transform 400ms cubic-bezier(0.22,1,0.36,1)',
            }}
          >
            <div className="font-display text-xl leading-snug mb-1.5">{headline}</div>
            <p className="text-[13px] leading-relaxed text-muted">{verdict.body}</p>
          </div>
        </div>

        {/* stats strip */}
        {(goodCount > 0 || badCount > 0) && (
          <div
            className="mt-4 pt-4 flex items-center gap-5"
            style={{
              borderTop: `1px solid ${cfg.statBorder}`,
              opacity: phase >= 2 ? 1 : 0,
              transform: phase >= 2 ? 'translateY(0)' : 'translateY(6px)',
              transition: 'opacity 400ms ease 180ms, transform 400ms ease 180ms',
            }}
          >
            {/* progress bar */}
            <div className="flex-1 relative">
              <div className="h-1.5 rounded-full overflow-hidden" style={{ background: cfg.trackColor }}>
                <div
                  className="h-full rounded-full"
                  style={{
                    background: cfg.ringColor,
                    boxShadow: `0 0 8px ${cfg.ringGlow}`,
                    width: phase >= 3 ? `${safePercent}%` : '0%',
                    transition: 'width 1.1s cubic-bezier(0.22,1,0.36,1) 350ms',
                  }}
                />
              </div>
            </div>

            {/* counts */}
            <div className="flex items-center gap-4 shrink-0 text-xs">
              {goodCount > 0 && (
                <span className="flex items-center gap-1.5">
                  <span className="size-2 rounded-full bg-good-fg" style={{ boxShadow: '0 0 5px rgba(45,106,46,0.5)' }} />
                  <span className="font-mono font-bold text-good-fg tabular-nums"><AnimCount to={goodCount} delay={480} /></span>
                  <span className="text-muted">safe</span>
                </span>
              )}
              {badCount > 0 && (
                <span className="flex items-center gap-1.5">
                  <span className="size-2 rounded-full bg-bad-fg" style={{ boxShadow: '0 0 5px rgba(178,43,43,0.5)' }} />
                  <span className="font-mono font-bold text-bad-fg tabular-nums"><AnimCount to={badCount} delay={620} /></span>
                  <span className="text-muted">triggers</span>
                </span>
              )}
              {totalCount > 0 && (
                <span className="text-muted font-mono tabular-nums">
                  <AnimCount to={totalCount} delay={760} /> parsed
                </span>
              )}
            </div>
          </div>
        )}
      </div>

      <style>{`
        @keyframes vcShimmer {
          0%   { transform: translateX(-110%); }
          100% { transform: translateX(110%); }
        }
      `}</style>
    </div>
  );
}
