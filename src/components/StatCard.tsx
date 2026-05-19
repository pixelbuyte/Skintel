import type { ReactNode } from 'react';

export function StatCard({
  label,
  value,
  hint,
  icon,
  accent,
}: {
  label: string;
  value: ReactNode;
  hint?: string;
  icon?: ReactNode;
  accent?: 'good' | 'bad' | 'unsure' | 'primary';
}) {
  const accentClass = {
    good: 'text-good-fg',
    bad: 'text-bad-fg',
    unsure: 'text-unsure-fg',
    primary: 'text-primary',
  }[accent ?? 'primary'];

  return (
    <div className="card p-5">
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm text-muted">{label}</span>
        {icon && <span className={accentClass}>{icon}</span>}
      </div>
      <div className={`font-display text-4xl ${accentClass}`}>{value}</div>
      {hint && <div className="text-xs text-muted mt-1">{hint}</div>}
    </div>
  );
}
