import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

export function useFoundingCount(pollMs = 30_000) {
  const [remaining, setRemaining] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function poll() {
      const { data, error } = await supabase.rpc('founding_seats_remaining');
      if (!cancelled && !error && typeof data === 'number') setRemaining(data);
    }
    poll();
    const t = setInterval(poll, pollMs);
    return () => {
      cancelled = true;
      clearInterval(t);
    };
  }, [pollMs]);

  return { remaining, total: 250 };
}
