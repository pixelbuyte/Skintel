import { useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { CheckCircle2 } from 'lucide-react';

export default function CheckoutSuccess() {
  const nav = useNavigate();
  useEffect(() => {
    const t = setTimeout(() => nav('/app'), 2500);
    return () => clearTimeout(t);
  }, [nav]);

  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="card p-10 max-w-md text-center">
        <CheckCircle2 size={48} className="text-good-fg mx-auto mb-4" />
        <h1 className="font-display text-3xl mb-2">You're in.</h1>
        <p className="text-muted mb-6">
          Thanks for upgrading. Redirecting you to your dashboard…
        </p>
        <Link to="/app" className="btn-primary">Go to dashboard</Link>
      </div>
    </div>
  );
}
