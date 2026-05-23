import { useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { Sparkles } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';

function GoogleIcon({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" xmlns="http://www.w3.org/2000/svg">
      <path
        fill="#4285F4"
        d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844a4.14 4.14 0 0 1-1.796 2.716v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.615z"
      />
      <path
        fill="#34A853"
        d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.258c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 0 0 9 18z"
      />
      <path
        fill="#FBBC05"
        d="M3.964 10.707A5.41 5.41 0 0 1 3.682 9c0-.593.102-1.17.282-1.707V4.961H.957A8.996 8.996 0 0 0 0 9c0 1.452.348 2.827.957 4.04l3.007-2.333z"
      />
      <path
        fill="#EA4335"
        d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 0 0 .957 4.96l3.007 2.333C4.672 5.166 6.656 3.58 9 3.58z"
      />
    </svg>
  );
}

export default function Login() {
  const { user, loading, signInWithGoogle } = useAuth();
  const [err, setErr] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (loading) return null;
  if (user) return <Navigate to="/app" replace />;

  async function go() {
    setErr(null);
    setSubmitting(true);
    const { error } = await signInWithGoogle();
    if (error) {
      setErr(error.message);
      setSubmitting(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="card p-8 w-full max-w-md">
        <Link to="/" className="flex items-center gap-2 mb-6">
          <Sparkles className="text-primary" size={22} />
          <span className="font-display text-2xl">Skintel</span>
        </Link>
        <h1 className="font-display text-3xl mb-2">Sign in</h1>
        <p className="text-muted text-sm mb-6">
          One click with Google. We only use your email, never anything else.
        </p>
        <button
          type="button"
          onClick={go}
          disabled={submitting}
          className="w-full inline-flex items-center justify-center gap-3 border border-border rounded-lg px-4 py-3 bg-card hover:bg-bg transition text-sm font-medium"
        >
          <GoogleIcon /> {submitting ? 'Redirecting…' : 'Continue with Google'}
        </button>
        {err && <div className="text-sm text-bad-fg mt-3">{err}</div>}
        <p className="text-xs text-muted mt-6">
          By signing in you agree to our terms. We never share your data.
        </p>
      </div>
    </div>
  );
}
