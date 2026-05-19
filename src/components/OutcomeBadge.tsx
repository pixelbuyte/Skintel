import type { Outcome } from '@/lib/types';
import { Check, X, HelpCircle } from 'lucide-react';

const CONFIG: Record<Outcome, { label: string; bg: string; fg: string; Icon: typeof Check }> = {
  good: { label: 'Good', bg: 'bg-good-bg', fg: 'text-good-fg', Icon: Check },
  bad: { label: 'Broke me out', bg: 'bg-bad-bg', fg: 'text-bad-fg', Icon: X },
  unsure: { label: 'Unsure', bg: 'bg-unsure-bg', fg: 'text-unsure-fg', Icon: HelpCircle },
};

export function OutcomeBadge({ outcome, size = 'md' }: { outcome: Outcome; size?: 'sm' | 'md' }) {
  const { label, bg, fg, Icon } = CONFIG[outcome];
  const sz = size === 'sm' ? 'text-xs px-2 py-0.5' : 'text-sm px-2.5 py-1';
  const iconSz = size === 'sm' ? 12 : 14;
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full font-medium ${bg} ${fg} ${sz}`}>
      <Icon size={iconSz} strokeWidth={2.5} />
      {label}
    </span>
  );
}
