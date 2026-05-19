import { Link } from 'react-router-dom';
import { Sparkles } from 'lucide-react';

export function PaywallBanner({ reason }: { reason: 'scanner' | 'product-cap' }) {
  const copy = reason === 'scanner'
    ? {
        title: 'Scanner is a Pro feature',
        body: 'Upgrade to scan any product against your personal trigger ingredients before you buy.',
      }
    : {
        title: 'Free plan limit reached',
        body: 'Upgrade to track unlimited products. The more you log, the smarter your culprits list gets.',
      };
  return (
    <div className="card p-8 text-center">
      <Sparkles className="text-primary mx-auto mb-3" size={28} />
      <h3 className="font-display text-2xl mb-2">{copy.title}</h3>
      <p className="text-muted max-w-md mx-auto mb-5">{copy.body}</p>
      <Link to="/pricing" className="btn-primary">See plans</Link>
    </div>
  );
}
