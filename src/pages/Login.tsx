import { useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { Sparkles, Loader2 } from 'lucide-react';
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

type Mode = 'signin' | 'signup' | 'reset';

export default function Login() {
  const {
    user,
    loading,
    signInWithGoogle,
    signInWithEmail,
    signUpWithEmail,
    sendPasswordReset,
  } = useAuth();
  const [mode, setMode] = useState<Mode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [oauthSubmitting, setOauthSubmitting] = useState(false);
  const [emailSubmitting, setEmailSubmitting] = useState(false);

  if (loading) return null;
  if (user) return <Navigate to="/app" replace />;

  async function doGoogle() {
    setErr(null);
    setInfo(null);
    setOauthSubmitting(true);
    const { error } = await signInWithGoogle();
    if (error) {
      setErr(error.message);
      setOauthSubmitting(false);
    }
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
        setInfo('Check your email to confirm your account, then sign in.');
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
            ? 'Sign up with email or continue with Google.'
            : mode === 'reset'
              ? 'Enter your email to get a reset link.'
              : 'Welcome back. Sign in to continue.'}
        </p>

        {mode !== 'reset' && (
          <>
            <button
              type="button"
              onClick={doGoogle}
              disabled={oauthSubmitting || emailSubmitting}
              className="w-full inline-flex items-center justify-center gap-3 border border-border rounded-lg px-4 py-3 bg-card hover:bg-bg transition text-sm font-medium disabled:opacity-60"
            >
              <GoogleIcon /> {oauthSubmitting ? 'Redirecting…' : 'Continue with Google'}
            </button>

            <div className="flex items-center gap-3 my-5 text-xs text-muted">
              <div className="h-px bg-border flex-1" />
              <span>OR</span>
              <div className="h-px bg-border flex-1" />
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
            disabled={emailSubmitting || oauthSubmitting}
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
