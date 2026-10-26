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
    signInWithGoogle,
  } = useAuth();
  const [mode, setMode] = useState<Mode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [confirmed, setConfirmed] = useState<string | null>(null);
  const [emailSubmitting, setEmailSubmitting] = useState(false);
  const [googleSubmitting, setGoogleSubmitting] = useState(false);

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

  async function doGoogle() {
    setErr(null);
    setInfo(null);
    setGoogleSubmitting(true);
    const { error } = await signInWithGoogle();
    // On success the browser is already leaving for Google.
    if (error) {
      setErr(error.message);
      setGoogleSubmitting(false);
    }
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

        {mode !== 'reset' && (
          <>
            <button
              type="button"
              onClick={doGoogle}
              disabled={googleSubmitting || emailSubmitting}
              aria-label="Continue with Google"
              className="btn w-full inline-flex items-center justify-center gap-2 py-3 bg-cream text-ink border border-ink hover:bg-bg disabled:opacity-60"
            >
              {googleSubmitting ? (
                <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />
              ) : (
                <GoogleMark />
              )}
              Continue with Google
            </button>
            <div className="flex items-center gap-3 my-5" aria-hidden="true">
              <div className="h-px flex-1 bg-border" />
              <span className="font-mono text-[11px] uppercase tracking-widest text-muted">or</span>
              <div className="h-px flex-1 bg-border" />
            </div>
          </>
        )}

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

/** Google "G" mark; Google's brand colours are used here and nowhere else. */
function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z" />
      <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z" />
      <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z" />
      <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z" />
    </svg>
  );
}
