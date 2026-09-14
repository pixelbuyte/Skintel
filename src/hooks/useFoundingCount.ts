import { useSyncExternalStore } from 'react';
import { supabase } from '@/lib/supabase';

const TOTAL_FOUNDING_SEATS = 500;
const POLL_MS = 30_000;

// One poll shared by every mount. The landing page alone mounts this hook
// twice (founding card + sticky bar), and /pricing and /discount mount it
// again, so per-instance polling meant several identical RPCs every 30s for
// a number that changes only when someone buys. New mounts read the cached
// value synchronously, which also removes the "Limited founding seats" flash
// the second instance used to show while its own first request was in flight.
let cached: number | null = null;
let inFlight = false;
let timer: number | null = null;
const listeners = new Set<() => void>();

async function poll() {
  if (inFlight) return;
  if (typeof document !== 'undefined' && document.hidden) return;
  inFlight = true;
  try {
    const { data, error } = await supabase.rpc('founding_seats_remaining');
    if (!error && typeof data === 'number') {
      cached = Math.max(0, Math.min(TOTAL_FOUNDING_SEATS, data));
      listeners.forEach((notify) => notify());
    }
  } finally {
    inFlight = false;
  }
}

function onVisibilityChange() {
  if (!document.hidden) void poll();
}

function subscribe(notify: () => void) {
  listeners.add(notify);
  if (timer === null) {
    void poll();
    timer = window.setInterval(poll, POLL_MS);
    document.addEventListener('visibilitychange', onVisibilityChange);
  }
  return () => {
    listeners.delete(notify);
    if (listeners.size === 0 && timer !== null) {
      window.clearInterval(timer);
      timer = null;
      document.removeEventListener('visibilitychange', onVisibilityChange);
    }
  };
}

function getSnapshot() {
  return cached;
}

export function useFoundingCount() {
  const remaining = useSyncExternalStore(subscribe, getSnapshot, getSnapshot);
  return { remaining, total: TOTAL_FOUNDING_SEATS };
}
