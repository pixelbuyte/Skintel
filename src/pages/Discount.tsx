import { Link, useNavigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { ArrowRight, ChevronDown, Check, Sparkles, ShieldCheck } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { useFoundingCount } from '@/hooks/useFoundingCount';
import { STRIPE_PRICES } from '@/lib/stripe-prices';

const INCLUDED = [
  'Unlimited tracked products',
  'Personal trigger map across your routine',
  'Full INCI scanner — paste, snap, or barcode',
  'Suspect ingredient surfacing across breakouts',
  'JSON export of every row you log',
  'Founding badge + early iOS access',
];

const FAQS = [
  {
    q: 'What exactly do I get for $20?',
    a: 'Six months of Skintel Pro — everything in the yearly plan, prorated. No subscription, no auto-renew. You pay once, use it for six months, then decide if you want to keep going at the regular Pro price.',
  },
  {
    q: 'Why only 500 spots?',
    a: 'This is the founding batch — people who lock in before the iOS app ships. Once 500 seats are claimed, the offer is closed for good. The price after that is $79/year or $9/month.',
  },
  {
    q: 'What happens after the 6 months?',
    a: 'Nothing automatic. Your Pro access pauses and you keep all your data on Free. You can resubscribe at the regular price whenever — or not. No card on file, no surprise charges.',
  },
  {
    q: 'Can I get a refund if it is not for me?',
    a: 'Yes. Email us within 14 days and we will refund the $20, no questions. Your data stays yours either way.',
  },
];

export default function Discount() {
  const { user, session } = useAuth();
  const nav = useNavigate();
  const { remaining, total } = useFoundingCount();
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [openFaq, setOpenFaq] = useState<number | null>(0);

  const soldOut = typeof remaining === 'number' && remaining <= 0;
  const claimed = typeof remaining === 'number' ? total - remaining : null;
  const pct = typeof remaining === 'number'
    ? Math.max(0, Math.min(100, ((total - remaining) / total) * 100))
    : 0;

  useEffect(() => {
    const prevTitle = document.title;
    document.title = 'Skintel Founding Deal — 6 months of Pro for $20';
    const meta = document.querySelector('meta[name="description"]');
    const prevDesc = meta?.getAttribute('content') ?? null;
    meta?.setAttribute(
      'content',
      'Founding offer: $20 for 6 months of Skintel Pro. 500 seats, then gone. Locks in before the iOS launch.',
    );
    return () => {
      document.title = prevTitle;
      if (prevDesc !== null) meta?.setAttribute('content', prevDesc);
    };
  }, []);

  async function claim() {
    if (!user || !session) {
      nav('/login?next=/discount');
      return;
    }
    setErr(null);
    setLoading(true);
    try {
      const res = await fetch('/api/stripe-checkout', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({ priceId: STRIPE_PRICES.founding, tier: 'founding' }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error ?? 'Checkout failed');
      window.location.href = data.url;
    } catch (e: any) {
      setErr(e?.message ?? 'Something went wrong');
      setLoading(false);
    }
  }

  const ctaLabel = soldOut
    ? 'Sold out'
    : loading
      ? 'Loading…'
      : 'Claim 6 months — $20';

  return (
    <div className="min-h-screen">
      <header className="max-w-5xl mx-auto px-6 py-6 flex items-center justify-between">
        <Link to="/" className="font-display text-2xl">
          Skintel<span className="text-primary">.</span>
        </Link>
        <Link to="/pricing" className="text-sm text-muted hover:text-ink transition-colors">
          See full pricing
        </Link>
      </header>

      <main className="max-w-3xl mx-auto px-6 pb-24">
        {/* Eyebrow */}
        <div className="inline-flex items-center gap-1.5 text-xs uppercase tracking-[0.16em] text-primary bg-primary/10 px-3 py-1.5 rounded-full font-medium mb-8">
          <Sparkles size={11} className="animate-pulse" />
          Founding offer · ends at seat 500
        </div>

        {/* Headline */}
        <h1 className="font-display text-5xl md:text-7xl leading-[1.02] tracking-tight mb-6">
          Six months of <em className="text-primary">Skintel Pro</em>
          {' '}
          for the price of one bad serum.
        </h1>

        <p className="text-lg md:text-xl text-muted max-w-[58ch] leading-relaxed mb-10">
          $20. One payment. No subscription, no auto-renew. Locks in your Pro access
          before the iOS app ships — then this deal is gone for good.
        </p>

        {/* Live progress */}
        <div className="card p-6 md:p-7 mb-6 relative overflow-hidden">
          <div
            aria-hidden
            className="absolute -top-24 -right-20 size-72 bg-primary/10 blur-3xl rounded-full"
          />
          <div className="relative">
            <div className="flex items-center justify-between text-xs uppercase tracking-[0.14em] mb-3">
              <span className="text-muted font-medium">Founding spots claimed</span>
              <span className="text-primary font-display font-semibold tabular-nums text-sm">
                {claimed !== null ? `${claimed} / ${total}` : `— / ${total}`}
              </span>
            </div>
            <div className="h-2 w-full rounded-full bg-border/40 overflow-hidden relative mb-4">
              <div
                className="h-full bg-gradient-to-r from-primary to-primary/60 rounded-full transition-[width] duration-1000 ease-emil relative"
                style={{ width: `${pct}%` }}
              >
                <div
                  aria-hidden
                  className="absolute inset-0 rounded-full"
                  style={{
                    background:
                      'linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.55) 50%, transparent 100%)',
                    animation: 'discount-shimmer 2.5s linear infinite',
                  }}
                />
              </div>
            </div>
            <p className="text-sm text-muted">
              {remaining === null
                ? 'Loading remaining seats…'
                : soldOut
                  ? 'All 500 founding seats are gone. Full pricing applies from here.'
                  : `${remaining} of ${total} spots left. When this bar fills, the offer closes.`}
            </p>
          </div>
        </div>

        {/* Primary CTA */}
        <button
          type="button"
          onClick={claim}
          disabled={loading || soldOut}
          className="btn-primary w-full md:w-auto text-base md:text-lg px-7 py-4 shadow-[0_18px_44px_-18px_rgba(163,88,72,0.65)] disabled:opacity-60"
        >
          {ctaLabel}
          {!soldOut && !loading && <ArrowRight size={16} />}
        </button>
        <p className="text-xs text-muted mt-3 flex items-center gap-1.5">
          <ShieldCheck size={12} className="text-primary" />
          Secure Stripe checkout · 14-day refund · No auto-renew
        </p>
        {err && <p className="text-sm text-bad-fg mt-3">{err}</p>}

        {/* What's included */}
        <section className="mt-16">
          <h2 className="font-display text-3xl md:text-4xl mb-6">What you unlock.</h2>
          <ul className="grid sm:grid-cols-2 gap-x-8 gap-y-3">
            {INCLUDED.map((f) => (
              <li key={f} className="flex items-start gap-2.5 text-base">
                <span className="size-5 mt-0.5 rounded-full bg-primary/10 text-primary flex items-center justify-center shrink-0">
                  <Check size={12} strokeWidth={3} />
                </span>
                <span>{f}</span>
              </li>
            ))}
          </ul>
        </section>

        {/* Why this exists / social-proof strip */}
        <section className="mt-16 card p-7 md:p-8 bg-ink text-bg relative overflow-hidden">
          <div
            aria-hidden
            className="absolute -bottom-20 -right-16 size-64 bg-primary/30 blur-3xl rounded-full"
          />
          <div className="relative">
            <div className="text-xs uppercase tracking-[0.16em] text-primary font-medium mb-3">
              Why $20
            </div>
            <p className="font-display text-2xl md:text-3xl leading-snug mb-3">
              Because the people who log their routine <em>before</em> the iOS launch
              are the ones who shape what gets built next.
            </p>
            <p className="text-bg/70 text-base leading-relaxed max-w-[56ch]">
              Founding members get priority on feature requests, the first invite to
              the iOS beta, and a permanent badge on their account. After 500 seats,
              Pro is $9/month or $79/year. No exceptions.
            </p>
          </div>
        </section>

        {/* FAQ */}
        <section className="mt-16">
          <h2 className="font-display text-3xl md:text-4xl mb-6">Quick questions.</h2>
          <div className="divide-y divide-border border-y border-border">
            {FAQS.map((f, i) => {
              const open = openFaq === i;
              return (
                <div key={f.q}>
                  <button
                    type="button"
                    className="w-full py-5 flex items-start gap-4 text-left group min-h-11"
                    onClick={() => setOpenFaq(open ? null : i)}
                    aria-expanded={open}
                  >
                    <span className="font-display text-lg md:text-xl flex-1 leading-snug">
                      {f.q}
                    </span>
                    <ChevronDown
                      size={20}
                      className={`text-muted shrink-0 mt-1 transition-transform duration-300 ease-emil ${
                        open ? 'rotate-180 text-primary' : 'group-hover:text-ink'
                      }`}
                    />
                  </button>
                  <div
                    className="grid transition-[grid-template-rows] duration-400 ease-emil"
                    style={{ gridTemplateRows: open ? '1fr' : '0fr' }}
                  >
                    <div className="overflow-hidden">
                      <p className="text-muted text-base leading-relaxed pb-5 pr-8">
                        {f.a}
                      </p>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        {/* Bottom CTA repeat */}
        <section className="mt-16 text-center">
          <p className="font-display text-2xl md:text-3xl mb-5 leading-snug">
            {soldOut
              ? 'The founding batch closed. Pricing resets to standard.'
              : remaining !== null
                ? `${remaining} seats left. Then it is gone.`
                : 'Lock in before the iOS launch.'}
          </p>
          <button
            type="button"
            onClick={claim}
            disabled={loading || soldOut}
            className="btn-primary text-base md:text-lg px-7 py-4 shadow-[0_18px_44px_-18px_rgba(163,88,72,0.65)] disabled:opacity-60"
          >
            {ctaLabel}
            {!soldOut && !loading && <ArrowRight size={16} />}
          </button>
          <div className="mt-6 text-sm text-muted">
            Want to compare plans?{' '}
            <Link to="/pricing" className="text-primary hover:underline">
              See full pricing →
            </Link>
          </div>
        </section>
      </main>

      <style>{`
        @keyframes discount-shimmer {
          0% { transform: translateX(-100%); }
          100% { transform: translateX(100%); }
        }
      `}</style>
    </div>
  );
}
