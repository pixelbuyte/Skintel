import { Link, useNavigate } from 'react-router-dom';
import { Check, ArrowLeft, Sparkles, RotateCw, ArrowRight } from 'lucide-react';
import { useState } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { useFoundingCount } from '@/hooks/useFoundingCount';
import { STRIPE_PRICES } from '@/lib/stripe-prices';
import {
  Tilt3D,
  Flip3D,
  AnimatedBorder,
  SparkleField,
  MagneticButton,
} from '@/components/Tilt3D';

type Plan = 'pro_monthly' | 'pro_yearly' | 'founding';

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

function FoundingCard({
  remaining,
  total,
  loading,
  soldOut,
  onCheckout,
}: {
  remaining: number | null;
  total: number;
  loading: boolean;
  soldOut: boolean;
  onCheckout: () => void;
}) {
  const [flipped, setFlipped] = useState(false);
  const pct = remaining !== null ? Math.max(0, Math.min(100, (remaining / total) * 100)) : 100;

  const Front = (
    <div className="card p-7 md:p-10 border-primary/40 ring-2 ring-primary/20 relative overflow-hidden h-full">
      <SparkleField count={18} />
      <div
        aria-hidden
        className="absolute -top-20 -right-20 size-72 bg-primary/15 blur-3xl rounded-full animate-pulse"
        style={{ animationDuration: '4s' }}
      />
      <div
        aria-hidden
        className="absolute -bottom-32 -left-20 size-80 bg-primary/10 blur-3xl rounded-full"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 rounded-card"
        style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }}
      />
      <div className="relative grid md:grid-cols-[1fr_auto] gap-6 items-center">
        <div>
          <div className="inline-flex items-center gap-1.5 text-xs uppercase tracking-[0.14em] text-primary bg-primary/10 px-2.5 py-1 rounded-full mb-3 font-medium">
            <Sparkles size={11} className="animate-pulse" /> Founding · 6 months
          </div>
          <h2 className="font-display text-3xl md:text-4xl mb-2 flex items-baseline gap-2">
            <span className="tabular-nums animate-rise-in">$20</span>
            <span className="text-muted text-lg font-sans">for 6 months</span>
          </h2>
          <p className="text-muted text-sm md:text-base max-w-[52ch] mb-4">
            One-time payment. 6 months of everything in Pro. No subscription, no
            auto-renew — locked in before the iOS launch.
          </p>

          <div className="max-w-sm mb-3">
            <div className="flex items-center justify-between text-xs mb-1.5">
              <span className="text-muted uppercase tracking-wider font-medium">
                Founding spots
              </span>
              <span className="text-primary font-display font-semibold tabular-nums">
                {remaining !== null ? `${remaining} / ${total}` : `${total}`}
              </span>
            </div>
            <div className="h-1.5 w-full rounded-full bg-border/40 overflow-hidden relative">
              <div
                className="h-full bg-gradient-to-r from-primary to-primary/60 rounded-full transition-[width] duration-1000 ease-emil relative"
                style={{ width: `${pct}%` }}
              >
                <div
                  aria-hidden
                  className="absolute inset-0 rounded-full"
                  style={{
                    background:
                      'linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.6) 50%, transparent 100%)',
                    animation: 'shimmer 2.5s linear infinite',
                  }}
                />
              </div>
            </div>
          </div>

          <button
            type="button"
            className="inline-flex items-center gap-1.5 text-xs text-muted hover:text-primary transition-colors"
            onClick={(e) => {
              e.stopPropagation();
              setFlipped(true);
            }}
          >
            <RotateCw size={11} /> See what's included
          </button>
        </div>
        <div className="flex flex-col items-stretch md:items-end gap-2">
          <MagneticButton
            strength={0.3}
            className="btn-primary shadow-[0_10px_30px_-10px_rgba(163,88,72,0.6)]"
            disabled={loading || soldOut}
            onClick={(e) => {
              e.stopPropagation();
              onCheckout();
            }}
          >
            {soldOut
              ? 'Sold out'
              : loading
                ? 'Loading…'
                : (
                  <>
                    Get 6 months — $20 <ArrowRight size={14} />
                  </>
                )}
          </MagneticButton>
        </div>
      </div>
      <style>{`
        @keyframes shimmer {
          0% { transform: translateX(-100%); }
          100% { transform: translateX(100%); }
        }
      `}</style>
    </div>
  );

  const Back = (
    <div className="card p-7 md:p-10 border-primary/40 ring-2 ring-primary/20 bg-ink text-bg relative overflow-hidden h-full">
      <SparkleField count={18} />
      <div
        aria-hidden
        className="absolute -top-32 -right-20 size-80 bg-primary/30 blur-3xl rounded-full"
      />
      <div className="relative">
        <div className="flex items-center justify-between mb-5">
          <div className="text-xs uppercase tracking-[0.14em] text-primary font-medium">
            Founding perks
          </div>
          <button
            type="button"
            className="inline-flex items-center gap-1.5 text-xs text-bg/60 hover:text-bg transition-colors"
            onClick={(e) => {
              e.stopPropagation();
              setFlipped(false);
            }}
          >
            <RotateCw size={11} /> Back
          </button>
        </div>
        <ul className="grid sm:grid-cols-2 gap-3 mb-6">
          {[
            'Everything in Pro Yearly',
            '6 months of Pro — pay once',
            'Founding member badge',
            'Priority feature requests',
            'Early access to iOS app',
            'Lock in before launch',
          ].map((f, i) => (
            <li
              key={f}
              className="flex items-start gap-2 text-sm"
              style={{ animation: `featurePop 500ms ${i * 70}ms both cubic-bezier(0.22,1,0.36,1)` }}
            >
              <Check size={15} className="text-primary mt-0.5 shrink-0" />
              <span>{f}</span>
            </li>
          ))}
        </ul>
        <MagneticButton
          strength={0.3}
          className="btn-primary"
          disabled={loading || soldOut}
          onClick={(e) => {
            e.stopPropagation();
            onCheckout();
          }}
        >
          {soldOut ? 'Sold out' : loading ? 'Loading…' : 'Claim 6 months — $20'}
        </MagneticButton>
        <style>{`
          @keyframes featurePop {
            0% { opacity: 0; transform: translateY(8px) scale(0.95); }
            100% { opacity: 1; transform: translateY(0) scale(1); }
          }
        `}</style>
      </div>
    </div>
  );

  return (
    <Tilt3D max={5} lift={12} className="mb-10">
      <AnimatedBorder className="rounded-card">
        <Flip3D flipped={flipped} onToggle={() => setFlipped((v) => !v)} front={Front} back={Back} />
      </AnimatedBorder>
    </Tilt3D>
  );
}

export default function Pricing() {
  const { user, session } = useAuth();
  const nav = useNavigate();
  const [loadingPlan, setLoadingPlan] = useState<Plan | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const { remaining, total } = useFoundingCount();
  const foundingSoldOut = typeof remaining === 'number' && remaining <= 0;

  async function checkout(plan: Plan) {
    if (!user || !session) {
      nav('/login?next=/pricing');
      return;
    }
    setErr(null);
    setLoadingPlan(plan);
    try {
      let priceId = STRIPE_PRICES.pro_monthly;
      let tier: 'pro' | 'founding' = 'pro';
      if (plan === 'pro_yearly') priceId = STRIPE_PRICES.pro_yearly;
      else if (plan === 'founding') {
        priceId = STRIPE_PRICES.founding;
        tier = 'founding';
      }
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

        <div id="founding">
          <FoundingCard
            remaining={typeof remaining === 'number' ? remaining : null}
            total={total}
            loading={loadingPlan === 'founding'}
            soldOut={foundingSoldOut}
            onCheckout={() => checkout('founding')}
          />
        </div>

        <div className="grid md:grid-cols-3 gap-6">
          <Card
            name="Free"
            priceNumber={0}
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
            name="Pro Monthly"
            priceNumber={9}
            period="/month"
            highlight
            features={[
              'Unlimited tracked products',
              'Suspect ingredient surfacing',
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
            badge="Save $29"
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
