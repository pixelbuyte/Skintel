import { Link, useNavigate } from 'react-router-dom';
import { Check, Sparkles, ArrowLeft } from 'lucide-react';
import { useState } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { useFoundingCount } from '@/hooks/useFoundingCount';
import { STRIPE_PRICES } from '@/lib/stripe-prices';

function Card({
  name,
  price,
  period,
  features,
  cta,
  highlight,
  badge,
  disabled,
  onClick,
  loading,
}: {
  name: string;
  price: string;
  period?: string;
  features: string[];
  cta: string;
  highlight?: boolean;
  badge?: string;
  disabled?: boolean;
  onClick?: () => void;
  loading?: boolean;
}) {
  return (
    <div
      className={`card p-6 flex flex-col ${highlight ? 'border-primary/40 ring-2 ring-primary/20' : ''}`}
    >
      {badge && (
        <div className="inline-flex self-start items-center gap-1 text-xs uppercase tracking-wider text-primary bg-primary/10 px-2 py-0.5 rounded-full mb-3">
          <Sparkles size={12} /> {badge}
        </div>
      )}
      <h3 className="font-display text-2xl">{name}</h3>
      <div className="mt-2 mb-5">
        <span className="font-display text-5xl">{price}</span>
        {period && <span className="text-muted text-sm ml-1">{period}</span>}
      </div>
      <ul className="space-y-2 text-sm flex-1">
        {features.map((f) => (
          <li key={f} className="flex items-start gap-2">
            <Check size={16} className="text-primary mt-0.5 shrink-0" /> {f}
          </li>
        ))}
      </ul>
      <button
        className={highlight ? 'btn-primary mt-6' : 'btn-secondary mt-6'}
        disabled={disabled || loading}
        onClick={onClick}
      >
        {loading ? 'Loading…' : cta}
      </button>
    </div>
  );
}

export default function Pricing() {
  const { user, session } = useAuth();
  const { remaining } = useFoundingCount();
  const nav = useNavigate();
  const [loadingTier, setLoadingTier] = useState<'pro' | 'founding' | null>(null);
  const [err, setErr] = useState<string | null>(null);

  async function checkout(tier: 'pro' | 'founding') {
    if (!user || !session) {
      nav('/login?next=/pricing');
      return;
    }
    setErr(null);
    setLoadingTier(tier);
    try {
      const priceId = tier === 'pro' ? STRIPE_PRICES.pro : STRIPE_PRICES.founding;
      const res = await fetch('/api/stripe-checkout', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({ priceId, tier }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error ?? 'Checkout failed');
      window.location.href = data.url;
    } catch (e: any) {
      setErr(e?.message ?? 'Something went wrong');
      setLoadingTier(null);
    }
  }

  async function startFree() {
    if (!user) nav('/login');
    else nav('/app');
  }

  const foundingSoldOut = remaining !== null && remaining <= 0;

  return (
    <div className="min-h-screen">
      <header className="max-w-6xl mx-auto px-6 py-6 flex items-center justify-between">
        <Link to="/" className="font-display text-2xl">Skintel</Link>
        <Link to={user ? '/app' : '/login'} className="text-sm text-muted hover:text-ink">
          {user ? 'Dashboard' : 'Sign in'}
        </Link>
      </header>

      <div className="max-w-6xl mx-auto px-6 pb-16">
        <Link to="/" className="inline-flex items-center gap-1 text-sm text-muted mb-6">
          <ArrowLeft size={16} /> Back
        </Link>
        <div className="text-center mb-12">
          <h1 className="font-display text-5xl mb-3">Simple pricing</h1>
          <p className="text-muted">Track your skin, find your triggers, scan before you buy.</p>
        </div>

        {err && <div className="text-sm text-bad-fg text-center mb-4">{err}</div>}

        <div className="grid md:grid-cols-3 gap-6">
          <Card
            name="Free"
            price="$0"
            period="forever"
            features={[
              'Up to 5 tracked products',
              'Suspect ingredient surfacing',
              'No scanner',
              'JSON export',
            ]}
            cta={user ? 'Go to dashboard' : 'Start free'}
            onClick={startFree}
          />
          <Card
            name="Pro"
            price="$9"
            period="/month"
            highlight
            features={[
              'Unlimited tracked products',
              'Suspect ingredient surfacing',
              'Full INCI scanner',
              'JSON export',
              'Cancel anytime',
            ]}
            cta="Upgrade to Pro"
            loading={loadingTier === 'pro'}
            onClick={() => checkout('pro')}
          />
          <Card
            name="Founding"
            price="$9"
            period="/month forever"
            badge={foundingSoldOut ? 'Sold out' : `${remaining ?? '…'}/250 left`}
            features={[
              'Everything in Pro',
              'Locked at $9/mo for life',
              'Founding-member badge',
              'Direct line for feature requests',
              'Capped at 250 members',
            ]}
            cta={foundingSoldOut ? 'Sold out' : 'Claim a seat'}
            disabled={foundingSoldOut}
            loading={loadingTier === 'founding'}
            onClick={() => checkout('founding')}
          />
        </div>
      </div>
    </div>
  );
}
