import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';

export default function AuthCallback() {
  const nav = useNavigate();
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    async function handle() {
      const url = new URL(window.location.href);
      const code = url.searchParams.get('code');
      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(window.location.href);
        if (error) {
          setErr(error.message);
          return;
        }
      }
      nav('/app', { replace: true });
    }
    handle();
  }, [nav]);

  return (
    <div className="min-h-screen flex items-center justify-center text-muted">
      {err ? <div className="text-bad-fg">{err}</div> : 'Signing you in…'}
    </div>
  );
}
