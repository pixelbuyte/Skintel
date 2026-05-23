const KEY = 'skintel_upc_queue';

export function enqueueUpc(upc: string) {
  try {
    const raw = localStorage.getItem(KEY);
    const list = raw ? (JSON.parse(raw) as string[]) : [];
    if (!list.includes(upc)) list.push(upc);
    localStorage.setItem(KEY, JSON.stringify(list));
  } catch {
    // ignore
  }
}

export function readQueue(): string[] {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as string[]) : [];
  } catch {
    return [];
  }
}

export function clearQueue() {
  try {
    localStorage.removeItem(KEY);
  } catch {
    // ignore
  }
}

export async function processQueue(
  lookupFn: (upc: string) => Promise<unknown>
): Promise<void> {
  const list = readQueue();
  if (list.length === 0) return;
  const remaining: string[] = [];
  for (const upc of list) {
    try {
      await lookupFn(upc);
    } catch {
      remaining.push(upc);
    }
  }
  try {
    if (remaining.length === 0) localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, JSON.stringify(remaining));
  } catch {
    // ignore
  }
}
