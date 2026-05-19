import type { ReactNode } from 'react';

export function EmptyState({
  title,
  body,
  cta,
}: {
  title: string;
  body: string;
  cta?: ReactNode;
}) {
  return (
    <div className="card p-10 text-center">
      <h3 className="font-display text-2xl mb-2">{title}</h3>
      <p className="text-muted max-w-md mx-auto mb-5">{body}</p>
      {cta}
    </div>
  );
}
