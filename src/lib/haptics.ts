import { isNative, haptic as nativeHaptic } from './native';

export function vibe(pattern: number | number[] = 25) {
  try {
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      navigator.vibrate(pattern);
    }
  } catch {
    // ignore
  }
}

// navigator.vibrate is a no-op inside iOS WKWebView — route through
// Capacitor Haptics on native, fall back to the Vibration API on web.
export const haptic = {
  tap: () => (isNative() ? void nativeHaptic('light') : vibe(15)),
  success: () => (isNative() ? void nativeHaptic('medium') : vibe([20, 40, 20])),
  detect: () => (isNative() ? void nativeHaptic('medium') : vibe(50)),
  error: () => (isNative() ? void nativeHaptic('heavy') : vibe([60, 50, 60])),
};
