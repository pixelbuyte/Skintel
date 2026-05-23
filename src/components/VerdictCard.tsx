import type { Verdict } from '@/lib/ingredient-knowledge';

const TONE_CLASS: Record<Verdict['tone'], string> = {
  good: 'bg-good-bg text-good-fg',
  caution: 'bg-unsure-bg text-unsure-fg',
  bad: 'bg-bad-bg text-bad-fg',
};

export function VerdictCard({ verdict }: { verdict: Verdict }) {
  return (
    <div
      className={`card p-6 ${TONE_CLASS[verdict.tone]} animate-in fade-in slide-in-from-bottom-2 duration-300`}
    >
      <div className="font-display text-2xl leading-tight">{verdict.headline}</div>
      <p className="text-sm mt-2 opacity-90">{verdict.body}</p>
    </div>
  );
}
