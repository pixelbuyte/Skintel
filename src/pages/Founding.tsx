import { Link } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { ArrowRight, ScanLine, ShieldCheck } from 'lucide-react';
import { track } from '@vercel/analytics';
import { useAuth } from '@/hooks/useAuth';
import { useFoundingCount } from '@/hooks/useFoundingCount';
import { STRIPE_PRICES } from '@/lib/stripe-prices';

// Deliberately the shortest path in the app: one screen, one decision. This is
// the link that goes in video captions/bios for people who already watched a
// demo of the scanner elsewhere and just want the deal — /discount is the
// version for people who still need convincing (full FAQ, features, "why
// $20" copy). Same checkout underneath (api/stripe-checkout.ts), so nothing
// new to maintain — just a shorter road to the same door. `ref=video` on the
// guest-checkout URL below tags conversions from this page in Stripe metadata.
export default function Founding() {
  const { user, session } = useAuth();
  const { remaining, total } = useFoundingCount();
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const soldOut = typeof remaining === 'number' && remaining <= 0;
  const pct = typeof remaining === 'number'
    ? Math.max(0, Math.min(100, ((total - remaining) / total) * 100))
    : 0;

  useEffect(() => {
    const prevTitle = document.title;
    document.title = 'Get 3 months of Skintel Pro — $20';
    track('founding_landing_view', { page: 'founding-video' });
    return () => { document.title = prevTitle; };
  }, []);

  async function claim() {
    track('founding_claim_click', { guest: !user || !session, page: 'founding-video' });

    if (!user || !session) {
      // Pay first, no account wall — Stripe collects the email and the
      // webhook creates/matches the account after payment (same as /discount).
      window.location.href = '/api/stripe-checkout?offer=founding&ref=video';
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
    } catch (e) {
      track('founding_checkout_error', { page: 'founding-video' });
      setErr(e instanceof Error ? e.message : 'Something went wrong');
      setLoading(false);
    }
  }

  const ctaLabel = soldOut ? 'Sold out' : loading ? 'Loading…' : 'Claim 3 months — $20';

  return (
    <div className="min-h-screen flex flex-col">
      <header className="px-6 py-6">
        <Link to="/" className="font-display text-xl inline-block">
          Skintel<span className="text-primary">.</span>
        </Link>
      </header>

      <main className="flex-1 flex items-center px-6 pb-10">
        <div className="max-w-md mx-auto w-full text-center">
          <div className="inline-flex items-center gap-1.5 text-xs uppercase tracking-[0.16em] text-primary bg-primary/10 px-3 py-1.5 rounded-full font-medium mb-6">
            Founding offer · 500 seats
          </div>

          <h1 className="font-display text-4xl md:text-5xl leading-[1.05] tracking-tight mb-4">
            You saw the scan.<br />Now get your own.
          </h1>

          <p className="text-muted text-base md:text-lg leading-relaxed mb-8">
            3 months of Skintel Pro — <span className="line-through text-muted/60">$49.99</span>{' '}
            <span className="text-ink font-medium">$20</span>. One payment, no subscription.
          </p>

          <button
            type="button"
            onClick={claim}
            disabled={loading || soldOut}
            className="btn-primary w-full text-base md:text-lg px-7 py-4 shadow-[0_18px_44px_-18px_rgba(163,88,72,0.65)] disabled:opacity-60 mb-3"
          >
            {ctaLabel}
            {!soldOut && !loading && <ArrowRight size={16} />}
          </button>

          <div className="mb-8">
            <div className="h-1.5 w-full rounded-full bg-border/40 overflow-hidden mb-2">
              <div
                className="h-full bg-gradient-to-r from-primary to-primary/60 rounded-full transition-[width] duration-1000 ease-emil"
                style={{ width: `${pct}%` }}
              />
            </div>
            <p className="text-xs text-muted">
              {remaining === null
                ? 'Loading seats…'
                : soldOut
                  ? 'All 500 seats claimed — deal closed.'
                  : `${remaining} of ${total} seats left`}
            </p>
          </div>

          {err && <p className="text-sm text-bad-fg mb-6">{err}</p>}

          <div className="flex items-center justify-center gap-2 text-sm text-muted mb-2">
            <ScanLine size={15} className="text-primary shrink-0" />
            <span>Scan any product — find what's actually breaking you out.</span>
          </div>
          <p className="text-xs text-muted flex items-center justify-center gap-1.5">
            <ShieldCheck size={12} className="text-primary" />
            Secure Stripe checkout · 14-day refund · No auto-renew
          </p>
        </div>
      </main>

      <footer className="px-6 py-6 flex items-center justify-center gap-5 text-xs text-muted">
        <Link to="/terms" className="hover:text-ink transition-colors">Terms</Link>
        <Link to="/privacy" className="hover:text-ink transition-colors">Privacy</Link>
        <Link to="/discount" className="hover:text-ink transition-colors">Full details</Link>
      </footer>
    </div>
  );
}
