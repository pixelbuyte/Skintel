import { useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { Sparkles } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';

export default function Login() {
  const { user, loading, signInWithOtp } = useAuth();
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (loading) return null;
  if (user) return <Navigate to="/app" replace />;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setSubmitting(true);
    const { error } = await signInWithOtp(email);
    setSubmitting(false);
    if (error) setErr(error.message);
    else setSent(true);
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="card p-8 w-full max-w-md">
        <Link to="/" className="flex items-center gap-2 mb-6">
          <Sparkles className="text-primary" size={22} />
          <span className="font-display text-2xl">Skintel</span>
        </Link>
        <h1 className="font-display text-3xl mb-2">Sign in</h1>
        <p className="text-muted text-sm mb-6">We'll send you a magic link. No password.</p>
        {sent ? (
          <div className="bg-good-bg text-good-fg rounded-lg p-4 text-sm">
            Check <strong>{email}</strong> for your magic link.
          </div>
        ) : (
          <form onSubmit={submit} className="flex flex-col gap-3">
            <label className="label">Email</label>
            <input
              type="email"
              required
              className="input"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoFocus
            />
            {err && <div className="text-sm text-bad-fg">{err}</div>}
            <button className="btn-primary w-full mt-2" disabled={submitting}>
              {submitting ? 'Sending…' : 'Send magic link'}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
