import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';

export default function AuthCallback() {
  const nav = useNavigate();
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let done = false;

    async function go() {
      const url = new URL(window.location.href);
      const code = url.searchParams.get('code');

      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(window.location.href);
        if (error) {
          setErr(error.message);
          return;
        }
      }

      const { data } = await supabase.auth.getSession();
      if (data.session) {
        done = true;
        nav('/app', { replace: true });
        return;
      }

      const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => {
        if (s && !done) {
          done = true;
          nav('/app', { replace: true });
        }
      });

      setTimeout(() => {
        if (!done) {
          supabase.auth.getSession().then(({ data: d2 }) => {
            if (d2.session && !done) {
              done = true;
              nav('/app', { replace: true });
            } else if (!done) {
              setErr('Sign-in did not complete. Try again.');
            }
          });
        }
      }, 4000);

      return () => sub.subscription.unsubscribe();
    }

    go();
  }, [nav]);

  return (
    <div className="min-h-screen flex items-center justify-center text-muted">
      {err ? <div className="text-bad-fg">{err}</div> : 'Signing you in…'}
    </div>
  );
}
