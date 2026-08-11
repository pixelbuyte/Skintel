import { Link, useNavigate } from 'react-router-dom';
import { Check, ArrowLeft, ArrowRight } from 'lucide-react';
import { useState } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { STRIPE_PRICES } from '@/lib/stripe-prices';
import {
  Tilt3D,
  AnimatedBorder,
  SparkleField,
  MagneticButton,
} from '@/components/Tilt3D';

type Plan = 'pro_monthly' | 'pro_yearly';

function Card({
  name,
  priceNumber,
  pricePrefix = '$',
  priceSuffix = '',
  period,
  features,
  cta,
  highlight,
  badge,
  loading,
  onClick,
}: {
  name: string;
  priceNumber: number;
  pricePrefix?: string;
  priceSuffix?: string;
  period?: string;
  features: string[];
  cta: string;
  highlight?: boolean;
  badge?: string;
  loading?: boolean;
  onClick?: () => void;
}) {
  const inner = (
    <div
      className={`card p-6 flex flex-col h-full relative overflow-hidden transition-shadow duration-300 ease-emil hover:shadow-[0_30px_60px_-20px_rgba(163,88,72,0.3)] ${
        highlight ? 'border-primary/40 ring-2 ring-primary/20 bg-card' : ''
      }`}
    >
      {highlight && <SparkleField count={10} />}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 rounded-card"
        style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }}
      />
      <div className="relative flex flex-col h-full">
        {badge && (
          <div className="inline-flex self-start items-center gap-1 text-xs uppercase tracking-wider text-primary bg-primary/10 px-2 py-0.5 rounded-full mb-3">
            {badge}
          </div>
        )}
        <h3 className="font-display text-2xl">{name}</h3>
        <div className="mt-2 mb-5 flex items-baseline gap-1">
          <span className="font-display text-5xl tabular-nums animate-rise-in">
            {pricePrefix}
            {priceNumber}
            {priceSuffix}
          </span>
          {period && <span className="text-muted text-sm ml-1">{period}</span>}
        </div>
        <ul className="space-y-2 text-sm flex-1 group/list">
          {features.map((f, i) => (
            <li
              key={f}
              className="flex items-start gap-2 transition-all duration-300 ease-emil group-hover/list:translate-x-0"
              style={{ transitionDelay: `${i * 40}ms` }}
            >
              <span className="size-5 mt-0.5 rounded-full bg-primary/10 text-primary flex items-center justify-center shrink-0 group-hover/list:bg-primary group-hover/list:text-card transition-colors duration-300 ease-emil">
                <Check size={12} strokeWidth={3} />
              </span>
              <span>{f}</span>
            </li>
          ))}
        </ul>
        <MagneticButton
          strength={0.25}
          className={`${highlight ? 'btn-primary' : 'btn-secondary'} mt-6 disabled:opacity-60`}
          disabled={loading}
          onClick={(e) => {
            e.stopPropagation();
            onClick?.();
          }}
        >
          {loading ? 'Loading…' : (
            <>
              {cta}
              <ArrowRight size={14} />
            </>
          )}
        </MagneticButton>
      </div>
    </div>
  );

  return (
    <Tilt3D max={9} lift={18} className="h-full">
      {highlight ? <AnimatedBorder className="rounded-card h-full">{inner}</AnimatedBorder> : inner}
    </Tilt3D>
  );
}

export default function Pricing() {
  const { user, session } = useAuth();
  const nav = useNavigate();
  const [loadingPlan, setLoadingPlan] = useState<Plan | null>(null);
  const [err, setErr] = useState<string | null>(null);

  async function checkout(plan: Plan) {
    if (!user || !session) {
      nav('/login?next=/pricing');
      return;
    }
    setErr(null);
    setLoadingPlan(plan);
    try {
      const priceId = plan === 'pro_yearly' ? STRIPE_PRICES.pro_yearly : STRIPE_PRICES.pro_monthly;
      const tier = 'pro' as const;
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
      setLoadingPlan(null);
    }
  }

  function startFree() {
    if (!user) nav('/login');
    else nav('/app');
  }

  return (
    <div className="min-h-screen">
      <header className="max-w-6xl mx-auto px-6 py-6 flex items-center justify-between">
        <Link to="/" className="font-display text-2xl">Skintel</Link>
        <Link to={user ? '/app' : '/login'} className="text-sm text-muted hover:text-ink">
          {user ? 'Dashboard' : 'Sign in'}
        </Link>
      </header>

      <div className="max-w-6xl mx-auto px-6 pb-16">
        <Link to="/" className="inline-flex items-center gap-1 text-sm text-muted mb-6 hover:text-ink transition-colors group">
          <ArrowLeft size={16} className="group-hover:-translate-x-0.5 transition-transform" /> Back
        </Link>
        <div className="text-center mb-12">
          <h1 className="font-display text-5xl mb-3">Simple pricing</h1>
          <p className="text-muted">Track your skin, find your triggers, scan before you buy.</p>
        </div>

        {err && <div className="text-sm text-bad-fg text-center mb-4">{err}</div>}

        <div className="grid md:grid-cols-3 gap-6">
          <Card
            name="Free"
            priceNumber={0}
            period="forever"
            features={[
              'Up to 5 tracked products',
              'Basic trigger surfacing',
              'No scanner',
              'JSON export',
            ]}
            cta={user ? 'Go to dashboard' : 'Start free'}
            onClick={startFree}
          />
          <Card
            name="Pro Monthly"
            priceNumber={8.99}
            period="/month"
            highlight
            features={[
              'Unlimited tracked products',
              'Full trigger detection',
              'Full INCI scanner',
              'JSON export',
              'Cancel anytime',
            ]}
            cta="Upgrade monthly"
            loading={loadingPlan === 'pro_monthly'}
            onClick={() => checkout('pro_monthly')}
          />
          <Card
            name="Pro Yearly"
            priceNumber={79}
            period="/year"
            badge="Save 27%"
            features={[
              'Everything in Pro Monthly',
              'Two months free vs monthly',
              'Cancel anytime',
            ]}
            cta="Upgrade yearly"
            loading={loadingPlan === 'pro_yearly'}
            onClick={() => checkout('pro_yearly')}
          />
        </div>
      </div>
    </div>
  );
}
