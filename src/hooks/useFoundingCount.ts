import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

const TOTAL_FOUNDING_SEATS = 500;

// One poll shared by every mount. The landing page alone mounts this hook
// twice (founding card + sticky bar), and /pricing and /discount mount it
// again, so per-instance polling meant several identical RPCs every 30s for
// a number that changes only when someone buys. New mounts get the cached
// value immediately, which also removes the "Limited founding seats" flash
// the second instance used to show while its own first request was in flight.
let cached: number | null = null;
let inFlight = false;
let timer: number | null = null;
const listeners = new Set<(n: number | null) => void>();

async function poll() {
  if (inFlight) return;
  if (typeof document !== 'undefined' && document.hidden) return;
  inFlight = true;
  try {
    const { data, error } = await supabase.rpc('founding_seats_remaining');
    if (!error && typeof data === 'number') {
      cached = Math.max(0, Math.min(TOTAL_FOUNDING_SEATS, data));
      listeners.forEach((notify) => notify(cached));
    }
  } finally {
    inFlight = false;
  }
}

function onVisibilityChange() {
  if (!document.hidden) void poll();
}

function startPolling(pollMs: number) {
  if (timer !== null) return;
  void poll();
  timer = window.setInterval(poll, pollMs);
  document.addEventListener('visibilitychange', onVisibilityChange);
}

function stopPollingIfUnused() {
  if (listeners.size > 0 || timer === null) return;
  window.clearInterval(timer);
  timer = null;
  document.removeEventListener('visibilitychange', onVisibilityChange);
}

export function useFoundingCount(pollMs = 30_000) {
  const [remaining, setRemaining] = useState<number | null>(cached);

  useEffect(() => {
    listeners.add(setRemaining);
    if (cached !== null) setRemaining(cached);
    startPolling(pollMs);
    return () => {
      listeners.delete(setRemaining);
      stopPollingIfUnused();
    };
  }, [pollMs]);

  return { remaining, total: TOTAL_FOUNDING_SEATS };
}
