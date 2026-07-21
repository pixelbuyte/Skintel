import { useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { CheckCircle2, Mail } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';

export default function CheckoutSuccess() {
  const nav = useNavigate();
  const { user, loading } = useAuth();

  // Logged-in buyers go straight to the dashboard. Guest buyers stay here —
  // their account was just created by the webhook and the sign-in link is in
  // their email; bouncing them to /app would hit the login wall.
  useEffect(() => {
    if (loading || !user) return;
    const t = setTimeout(() => nav('/app'), 2500);
    return () => clearTimeout(t);
  }, [nav, user, loading]);

  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="card p-10 max-w-md text-center">
        <CheckCircle2 size={48} className="text-good-fg mx-auto mb-4" />
        <h1 className="font-display text-3xl mb-2">You&rsquo;re in.</h1>
        {user ? (
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
