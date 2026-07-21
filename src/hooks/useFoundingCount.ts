import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

const TOTAL_FOUNDING_SEATS = 500;
const DISPLAY_BASELINE_CLAIMED = 138;

export function useFoundingCount(pollMs = 30_000) {
  const [remaining, setRemaining] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function poll() {
      const { data, error } = await supabase.rpc('founding_seats_remaining');
      if (!cancelled && !error && typeof data === 'number') {
        const actualClaimed = Math.max(0, TOTAL_FOUNDING_SEATS - data);
        const displayedClaimed = Math.min(
          TOTAL_FOUNDING_SEATS,
          DISPLAY_BASELINE_CLAIMED + actualClaimed,
        );
        setRemaining(TOTAL_FOUNDING_SEATS - displayedClaimed);
      }
    }
    poll();
    const t = setInterval(poll, pollMs);
    return () => {
      cancelled = true;
      clearInterval(t);
    };
  }, [pollMs]);

  return { remaining, total: TOTAL_FOUNDING_SEATS };
}
