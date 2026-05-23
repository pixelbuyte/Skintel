export function vibe(pattern: number | number[] = 25) {
  try {
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      navigator.vibrate(pattern);
    }
  } catch {
    // ignore
  }
}

export const haptic = {
  tap: () => vibe(15),
  success: () => vibe([20, 40, 20]),
  detect: () => vibe(50),
  error: () => vibe([60, 50, 60]),
};
