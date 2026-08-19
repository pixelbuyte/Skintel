import { useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { Sparkles, Loader2 } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';

type Mode = 'signin' | 'signup' | 'reset';

export default function Login() {
  const {
    user,
    loading,
    signInWithEmail,
    signUpWithEmail,
    sendPasswordReset,
  } = useAuth();
  const [mode, setMode] = useState<Mode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [confirmed, setConfirmed] = useState<string | null>(null);
  const [emailSubmitting, setEmailSubmitting] = useState(false);

  if (loading) return null;
  if (user) return <Navigate to="/app" replace />;

  if (confirmed) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6">
        <div className="card p-8 w-full max-w-md text-center">
          <div className="size-16 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-5">
            <Sparkles className="text-primary" size={28} />
          </div>
          <h1 className="font-display text-3xl mb-2">Check your inbox</h1>
          <p className="text-muted text-sm mb-1">
            We sent a confirmation link to
          </p>
          <p className="font-medium mb-5">{confirmed}</p>
          <p className="text-muted text-sm mb-6">
            Click the link in the email to activate your account, then come back here to sign in.
          </p>
          <button
            type="button"
            className="btn-secondary w-full"
            onClick={() => { setConfirmed(null); setMode('signin'); }}
          >
            Back to sign in
          </button>
        </div>
      </div>
    );
  }

  async function doEmail(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setInfo(null);
    const cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail) {
      setErr('Enter an email.');
      return;
    }
    if (mode !== 'reset' && password.length < 8) {
      setErr('Password must be at least 8 characters.');
      return;
    }

    setEmailSubmitting(true);
    if (mode === 'signin') {
      const { error } = await signInWithEmail(cleanEmail, password);
      if (error) setErr(error.message);
    } else if (mode === 'signup') {
      const { error, needsConfirm } = await signUpWithEmail(cleanEmail, password);
      if (error) setErr(error.message);
      else if (needsConfirm) {
        setConfirmed(cleanEmail);
        setPassword('');
      }
    } else if (mode === 'reset') {
      const { error } = await sendPasswordReset(cleanEmail);
      if (error) setErr(error.message);
      else setInfo('Password reset link sent. Check your email.');
    }
    setEmailSubmitting(false);
  }

  const heading =
    mode === 'signup' ? 'Create your account' : mode === 'reset' ? 'Reset password' : 'Sign in';

  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="card p-8 w-full max-w-md">
        <Link to="/" className="flex items-center gap-2 mb-6">
          <Sparkles className="text-primary" size={22} />
          <span className="font-display text-2xl">Skintel</span>
        </Link>
        <h1 className="font-display text-3xl mb-2">{heading}</h1>
        <p className="text-muted text-sm mb-6">
          {mode === 'signup'
            ? 'Sign up with your email.'
            : mode === 'reset'
              ? 'Enter your email to get a reset link.'
              : 'Welcome back. Sign in to continue.'}
        </p>

        <form onSubmit={doEmail} className="space-y-3">
          <div className="space-y-1">
            <label className="label" htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              required
              className="input w-full"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              disabled={emailSubmitting}
              placeholder="you@example.com"
            />
          </div>
          {mode !== 'reset' && (
            <div className="space-y-1">
              <label className="label" htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                autoComplete={mode === 'signup' ? 'new-password' : 'current-password'}
                required
                minLength={8}
                className="input w-full"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={emailSubmitting}
                placeholder={mode === 'signup' ? 'At least 8 characters' : 'Your password'}
              />
            </div>
          )}
          <button
            type="submit"
            disabled={emailSubmitting}
            className="btn-primary w-full inline-flex items-center justify-center gap-2 py-3 disabled:opacity-60"
          >
            {emailSubmitting && <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />}
            {mode === 'signup'
              ? emailSubmitting
                ? 'Creating account…'
                : 'Create account'
              : mode === 'reset'
                ? emailSubmitting
                  ? 'Sending…'
                  : 'Send reset link'
                : emailSubmitting
                  ? 'Signing in…'
                  : 'Sign in'}
          </button>
        </form>

        {err && (
          <div className="text-sm text-bad-fg mt-4" role="alert">
            {err}
          </div>
        )}
        {info && (
          <div className="text-sm text-good-fg mt-4">
            {info}
          </div>
        )}

        <div className="mt-6 flex flex-col gap-2 text-sm text-muted">
          {mode === 'signin' && (
            <>
              <button
                type="button"
                className="text-left hover:text-ink underline-offset-2 hover:underline"
                onClick={() => {
                  setMode('signup');
                  setErr(null);
                  setInfo(null);
                }}
              >
                Need an account? Sign up
              </button>
              <button
                type="button"
                className="text-left hover:text-ink underline-offset-2 hover:underline"
                onClick={() => {
                  setMode('reset');
                  setErr(null);
                  setInfo(null);
                }}
              >
                Forgot password?
              </button>
            </>
          )}
          {mode === 'signup' && (
            <button
              type="button"
              className="text-left hover:text-ink underline-offset-2 hover:underline"
              onClick={() => {
                setMode('signin');
                setErr(null);
                setInfo(null);
              }}
            >
              Already have an account? Sign in
            </button>
          )}
          {mode === 'reset' && (
            <button
              type="button"
              className="text-left hover:text-ink underline-offset-2 hover:underline"
              onClick={() => {
                setMode('signin');
                setErr(null);
                setInfo(null);
              }}
            >
              Back to sign in
            </button>
          )}
        </div>

        <p className="text-xs text-muted mt-6">
          By signing in you agree to our terms. We never share your data.
        </p>
      </div>
    </div>
  );
}
