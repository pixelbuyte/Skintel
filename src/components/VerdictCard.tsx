import { useEffect, useState } from 'react';
import { CheckCircle2, AlertTriangle, XCircle } from 'lucide-react';
import type { Verdict } from '@/lib/ingredient-knowledge';

const TONE_CONFIG: Record<Verdict['tone'], {
  bg: string;
  border: string;
  glow: string;
  icon: React.ReactNode;
  shimmer: string;
  pulse: string;
}> = {
  good: {
    bg: 'bg-good-bg',
    border: 'border-good-fg/25',
    glow: '0 0 40px 6px rgba(34,197,94,0.18)',
    icon: <CheckCircle2 size={32} className="text-good-fg" />,
    shimmer: 'rgba(34,197,94,0.12)',
    pulse: 'rgba(34,197,94,0.25)',
  },
  caution: {
    bg: 'bg-unsure-bg',
    border: 'border-unsure-fg/25',
    glow: '0 0 40px 6px rgba(234,179,8,0.18)',
    icon: <AlertTriangle size={32} className="text-unsure-fg" />,
    shimmer: 'rgba(234,179,8,0.10)',
    pulse: 'rgba(234,179,8,0.22)',
  },
  bad: {
    bg: 'bg-bad-bg',
    border: 'border-bad-fg/25',
    glow: '0 0 40px 6px rgba(239,68,68,0.18)',
    icon: <XCircle size={32} className="text-bad-fg" />,
    shimmer: 'rgba(239,68,68,0.10)',
    pulse: 'rgba(239,68,68,0.22)',
  },
};

export function VerdictCard({ verdict }: { verdict: Verdict }) {
  const [iconIn, setIconIn] = useState(false);
  const [textIn, setTextIn] = useState(false);
  const [glowing, setGlowing] = useState(false);
  const cfg = TONE_CONFIG[verdict.tone];

  useEffect(() => {
    setIconIn(false); setTextIn(false); setGlowing(false);
    const t1 = setTimeout(() => setIconIn(true), 60);
    const t2 = setTimeout(() => setTextIn(true), 220);
    const t3 = setTimeout(() => setGlowing(true), 300);
    return () => { clearTimeout(t1); clearTimeout(t2); clearTimeout(t3); };
  }, [verdict.headline]);

  return (
    <div
      className={`card relative overflow-hidden ${cfg.bg} border ${cfg.border} p-6`}
      style={{
        boxShadow: glowing ? cfg.glow : 'none',
        transition: 'box-shadow 600ms cubic-bezier(0.22,1,0.36,1)',
      }}
    >
      {/* shimmer sweep on reveal */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background: `linear-gradient(105deg, transparent 30%, ${cfg.shimmer} 50%, transparent 70%)`,
          animation: 'verdictShimmer 800ms ease-out forwards',
        }}
      />
      {/* pulse ring */}
      {glowing && (
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 rounded-card"
          style={{
            boxShadow: `inset 0 0 0 1px ${cfg.pulse}`,
            animation: 'ringPulse 1s ease-out forwards',
          }}
        />
      )}

      <div className="relative flex items-start gap-4">
        {/* animated icon */}
        <div
          style={{
            opacity: iconIn ? 1 : 0,
            transform: iconIn ? 'scale(1) rotate(0deg)' : 'scale(0.4) rotate(-20deg)',
            transition: 'opacity 400ms cubic-bezier(0.22,1,0.36,1), transform 500ms cubic-bezier(0.34,1.56,0.64,1)',
          }}
          className="shrink-0 mt-0.5"
        >
          {cfg.icon}
        </div>

        <div
          style={{
            opacity: textIn ? 1 : 0,
            transform: textIn ? 'translateY(0)' : 'translateY(8px)',
            transition: 'opacity 400ms ease, transform 400ms cubic-bezier(0.22,1,0.36,1)',
          }}
        >
          <div className="font-display text-2xl leading-tight">{verdict.headline}</div>
          <p className="text-sm mt-1.5 opacity-80 leading-relaxed">{verdict.body}</p>
        </div>
      </div>

      <style>{`
        @keyframes verdictShimmer {
          0% { transform: translateX(-100%); opacity: 0; }
          30% { opacity: 1; }
          100% { transform: translateX(100%); opacity: 0; }
        }
        @keyframes ringPulse {
          0% { opacity: 0; transform: scale(0.96); }
          40% { opacity: 1; transform: scale(1); }
          100% { opacity: 0; transform: scale(1.02); }
        }
      `}</style>
    </div>
  );
}
