import { useEffect } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { CheckCircle2, Mail } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';

export default function CheckoutSuccess() {
  const nav = useNavigate();
  const { user, loading } = useAuth();
  const [params] = useSearchParams();
  const launch = params.get('offer') === 'launch';
  // Opened from the iOS paywall's "Web" option: send the buyer back to the app, where
  // Skintel+ unlocks on the same account once the webhook lands.
  const fromApp = params.get('from') === 'app';
  const cancelled = params.get('cancelled') === '1';

  // Logged-in buyers go straight to the dashboard. Guest buyers stay here —
  // their account was just created by the webhook and the sign-in link is in
  // their email; bouncing them to /app would hit the login wall.
  useEffect(() => {
    if (fromApp || launch || loading || !user) return;
    const t = setTimeout(() => nav('/app'), 2500);
    return () => clearTimeout(t);
  }, [nav, user, loading, launch, fromApp]);

  if (fromApp) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6">
        <div className="card p-10 max-w-md text-center">
          {!cancelled && <CheckCircle2 size={48} className="text-good-fg mx-auto mb-4" />}
          <h1 className="font-display text-3xl mb-2">{cancelled ? 'No charge made.' : 'You\u2019re Skintel+.'}</h1>
          <p className="text-muted mb-6">
            {cancelled
              ? 'Checkout was closed before paying. Go back to Skinstel to pick a plan again.'
              : 'Payment received. Go back to Skinstel: Skintel+ unlocks there in a few seconds.'}
          </p>
          <a href="skintel://open" className="btn-primary">Back to Skinstel</a>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="card p-10 max-w-md text-center">
        <CheckCircle2 size={48} className="text-good-fg mx-auto mb-4" />
        <h1 className="font-display text-3xl mb-2">You&rsquo;re in.</h1>
        {launch ? (
          <>
            <p className="text-muted mb-4">You’re Skintel+. Your launch price is locked in for the first 3 months.</p>
            <div className="flex items-start gap-3 text-left rounded-2xl bg-primary/8 border border-primary/15 p-4 mb-6">
              <Mail size={18} className="text-primary shrink-0 mt-0.5" />
              <p className="text-sm leading-relaxed">
                Open Skintel on your iPhone and <strong>sign in with the email you used at checkout</strong>. That’s
                the account Skintel+ is on. New to Skintel? Tap <em>Continue with email</em>, then{' '}
                <em>Forgot password?</em> to set a password. We’ve emailed you the same steps.
              </p>
            </div>
            <a href="https://apps.apple.com/us/app/skinstel-scan-track-clear/id6812903021" className="btn-primary">Open the App Store</a>
            <p className="text-sm text-muted mt-6">
              Not seeing Skintel+ in the app? Email{' '}
              <a href="mailto:skinstelreview@gmail.com" className="underline">skinstelreview@gmail.com</a> with the email you
              paid with. We fix it within 24 hours.
            </p>
          </>
        ) : user ? (
          <>
            <p className="text-muted mb-6">
              Thanks for upgrading. Redirecting you to your dashboard…
            </p>
            <Link to="/app" className="btn-primary">Go to dashboard</Link>
          </>
        ) : (
          <>
            <p className="text-muted mb-4">
              Payment received — your founding seat is locked in.
            </p>
            <div className="flex items-start gap-3 text-left rounded-2xl bg-primary/8 border border-primary/15 p-4 mb-6">
              <Mail size={18} className="text-primary shrink-0 mt-0.5" />
              <p className="text-sm leading-relaxed">
                We just emailed you a <strong>one-click sign-in link</strong> at the address you
                used at checkout. Open it to access your Pro account — no password needed.
              </p>
            </div>
            <Link to="/login" className="btn-secondary">I already have an account</Link>
          </>
        )}
      </div>
    </div>
  );
}
