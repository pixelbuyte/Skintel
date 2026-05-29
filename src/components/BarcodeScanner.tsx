import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Camera, X, ScanLine, ImageIcon, RefreshCw } from 'lucide-react';
import { useZxing } from 'react-zxing';
import type { Result } from '@zxing/library';
import { supabase } from '@/lib/supabase';
import { haptic } from '@/lib/haptics';
import { enqueueUpc } from '@/lib/offlineQueue';

export type BarcodeResult = {
  brand?: string | null;
  productName?: string | null;
  ingredients: string;
  upc: string;
};

type LookupResponse = {
  brand?: string | null;
  productName?: string | null;
  ingredients?: string;
  source?: 'openbeautyfacts' | 'openfoodfacts' | 'claude' | 'cache' | null;
  error?: string;
};

const LOOKUP_TIMEOUT_MS = 8000;

function CameraView({
  onDetected,
  onClose,
}: {
  onDetected: (code: string) => void;
  onClose: () => void;
}) {
  const [err, setErr] = useState<string | null>(null);
  const firedRef = useRef(false);

  const { ref } = useZxing({
    onResult(result: Result) {
      if (firedRef.current) return;
      const text = result.getText().replace(/\D/g, '');
      if (/^\d{8,13}$/.test(text)) {
        firedRef.current = true;
        haptic.detect();
        onDetected(text);
      }
    },
    onError(e) {
      const msg = e instanceof Error ? e.message : String(e);
      // Suppress "no barcode found" — fires constantly while searching, not a real error.
      if (/no multiformat readers|not found/i.test(msg)) return;
      setErr(msg);
    },
    constraints: {
      video: {
        facingMode: { ideal: 'environment' },
        width: { ideal: 1920 },
        height: { ideal: 1080 },
      },
      audio: false,
    },
  });

  // Ensure video plays inline on iOS and uses center positioning
  useEffect(() => {
    const el = ref.current as HTMLVideoElement | null;
    if (!el) return;
    el.setAttribute('playsinline', 'true');
    el.setAttribute('webkit-playsinline', 'true');
    el.muted = true;
    el.autoplay = true;
  }, [ref]);

  // Portal to body so we escape any transformed ancestor (Vaul Drawer,
  // modal, etc) — `position: fixed` is relative to the nearest transformed
  // ancestor, not the viewport, otherwise the camera gets trapped inside
  // the drawer box at the bottom of the screen.
  return createPortal(
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        width: '100vw',
        height: '100vh',
        background: '#000',
        overflow: 'hidden',
        zIndex: 9999,
      }}
    >
      {/* Full-screen camera feed — inline styles to override any zxing or browser defaults */}
      <video
        ref={ref}
        autoPlay
        playsInline
        muted
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          minWidth: '100%',
          minHeight: '100%',
          objectFit: 'cover',
          objectPosition: 'center center',
          transform: 'translateZ(0)',
          zIndex: 0,
        }}
      />

      {/* Dark vignette outside viewfinder for focus */}
      <div className="absolute inset-0 pointer-events-none" style={{ background: 'radial-gradient(ellipse at center, transparent 30%, rgba(0,0,0,0.55) 80%)' }} />

      {/* Top bar overlay */}
      <div
        className="absolute top-0 left-0 right-0 z-10 flex justify-between items-center px-4 py-3 text-white"
        style={{
          paddingTop: 'calc(env(safe-area-inset-top) + 12px)',
          background: 'linear-gradient(to bottom, rgba(0,0,0,0.6), transparent)',
        }}
      >
        <span className="font-display text-lg drop-shadow">Scan barcode</span>
        <button
          onClick={onClose}
          className="p-2 -m-2 min-h-11 min-w-11 inline-flex items-center justify-center rounded-full bg-black/30 hover:bg-black/50 active:scale-95 transition-transform backdrop-blur-sm"
          aria-label="Close scanner"
        >
          <X size={22} />
        </button>
      </div>

      {/* Viewfinder centered */}
      <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
        <div className="relative w-[78%] max-w-sm" style={{ aspectRatio: '5 / 3' }}>
          {/* corner brackets only — no full border (less obstructive) */}
          <div className="absolute -top-1 -left-1 w-8 h-8 border-t-[3px] border-l-[3px] border-white/95 rounded-tl-2xl" style={{ boxShadow: '0 0 10px rgba(255,255,255,0.4)' }} />
          <div className="absolute -top-1 -right-1 w-8 h-8 border-t-[3px] border-r-[3px] border-white/95 rounded-tr-2xl" style={{ boxShadow: '0 0 10px rgba(255,255,255,0.4)' }} />
          <div className="absolute -bottom-1 -left-1 w-8 h-8 border-b-[3px] border-l-[3px] border-white/95 rounded-bl-2xl" style={{ boxShadow: '0 0 10px rgba(255,255,255,0.4)' }} />
          <div className="absolute -bottom-1 -right-1 w-8 h-8 border-b-[3px] border-r-[3px] border-white/95 rounded-br-2xl" style={{ boxShadow: '0 0 10px rgba(255,255,255,0.4)' }} />

          {/* sweeping laser line */}
          <div
            className="absolute inset-x-4 h-0.5 rounded-full"
            style={{
              background: 'rgba(163,88,72,0.95)',
              boxShadow: '0 0 14px 4px rgba(163,88,72,0.7)',
              animation: 'bcScan 1.6s ease-in-out infinite',
            }}
          />
        </div>
      </div>

      {/* Bottom hint + error overlay */}
      <div
        className="absolute bottom-0 left-0 right-0 z-10 px-6 pt-8 pb-6 text-center text-white"
        style={{
          paddingBottom: 'calc(env(safe-area-inset-bottom) + 20px)',
          background: 'linear-gradient(to top, rgba(0,0,0,0.6), transparent)',
        }}
      >
        {err ? (
          <div className="text-sm text-red-300 bg-red-900/60 mx-auto inline-block px-3 py-2 rounded-xl backdrop-blur-sm">
            {err}
          </div>
        ) : (
          <p className="text-white/90 text-sm font-medium drop-shadow">
            Center the barcode inside the frame
          </p>
        )}
      </div>

      <style>{`
        @keyframes bcScan {
          0%   { top: 8%;  opacity: 0.0; }
          15%  { opacity: 1; }
          85%  { opacity: 1; }
          100% { top: 92%; opacity: 0.0; }
        }
      `}</style>
    </div>,
    document.body,
  );
}

function Skeleton() {
  return (
    <div className="card p-6 space-y-3 animate-pulse">
      <div className="flex items-center gap-2">
        <div className="w-5 h-5 rounded-full bg-border" />
        <div className="h-5 w-40 bg-border rounded" />
      </div>
      <div className="h-3 w-3/4 bg-border rounded" />
      <div className="h-3 w-2/3 bg-border rounded" />
      <div className="h-3 w-5/6 bg-border rounded" />
      <p className="text-xs text-muted pt-2">AI analyzing ingredients…</p>
    </div>
  );
}

type Mode = 'idle' | 'camera' | 'loading' | 'preview' | 'offline' | 'error';

export default function BarcodeScanner({
  onScanned,
  onSwitchToPhoto,
}: {
  onScanned: (data: BarcodeResult) => void;
  onSwitchToPhoto?: () => void;
}) {
  const [mode, setMode] = useState<Mode>('idle');
  const [error, setError] = useState<string | null>(null);
  const [preview, setPreview] = useState<BarcodeResult | null>(null);
  const [lastUpc, setLastUpc] = useState<string>('');

  useEffect(() => {
    // Auto-open camera on first mount for fastest path.
    setMode('camera');
  }, []);

  async function lookup(upc: string) {
    setError(null);
    setPreview(null);
    setLastUpc(upc);
    setMode('loading');

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), LOOKUP_TIMEOUT_MS);

    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;
      if (!token) {
        setError('You must be signed in.');
        setMode('error');
        return;
      }
      const r = await fetch(`/api/lookup?mode=barcode&upc=${encodeURIComponent(upc)}`, {
        method: 'GET',
        headers: { Authorization: `Bearer ${token}` },
        signal: controller.signal,
      });
      const body = (await r.json()) as LookupResponse;
      if (!r.ok) {
        setError(body.error ?? `Lookup failed (${r.status})`);
        setMode('error');
        haptic.error();
        return;
      }
      setPreview({
        brand: body.brand ?? null,
        productName: body.productName ?? null,
        ingredients: body.ingredients ?? '',
        upc,
      });
      setMode('preview');
      haptic.success();
    } catch (e) {
      if ((e as Error).name === 'AbortError') {
        enqueueUpc(upc);
        setMode('offline');
        return;
      }
      setError(e instanceof Error ? e.message : 'Network error');
      setMode('error');
      haptic.error();
    } finally {
      clearTimeout(timer);
    }
  }

  function onCameraDetect(code: string) {
    void lookup(code);
  }

  function confirm() {
    if (preview) onScanned(preview);
  }

  if (mode === 'camera') {
    return <CameraView onDetected={onCameraDetect} onClose={() => setMode('idle')} />;
  }

  return (
    <div className="space-y-4">
      {mode === 'idle' && (
        <button
          type="button"
          onClick={() => setMode('camera')}
          className="w-full card p-6 text-left active:scale-[0.98] transition-transform duration-200 ease-ios hover:shadow-soft"
        >
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center text-primary">
              <ScanLine size={24} />
            </div>
            <div className="flex-1">
              <div className="font-medium">Scan with camera</div>
              <div className="text-xs text-muted mt-0.5">Center the barcode. Auto-detects EAN/UPC.</div>
            </div>
            <Camera className="text-muted" size={20} />
          </div>
        </button>
      )}

      {mode === 'loading' && <Skeleton />}

      {mode === 'offline' && (
        <div className="card p-5 space-y-3">
          <div className="font-medium">Connection weak</div>
          <p className="text-sm text-muted">
            UPC <span className="font-mono">{lastUpc}</span> saved. We'll fetch it next time you're online.
          </p>
          <div className="flex gap-2 pt-1">
            <button type="button" className="btn-primary" onClick={() => lookup(lastUpc)}>
              <RefreshCw size={16} /> Try again
            </button>
            {onSwitchToPhoto && (
              <button type="button" className="btn-secondary" onClick={onSwitchToPhoto}>
                <ImageIcon size={16} /> Snap label instead
              </button>
            )}
          </div>
        </div>
      )}

      {mode === 'error' && (
        <div className="card p-5 space-y-3">
          <div className="font-medium">Couldn't read that</div>
          {error && <p className="text-sm text-bad-fg">{error}</p>}
          <p className="text-sm text-muted">
            Try snapping the ingredient label instead. Works for any product.
          </p>
          <div className="flex gap-2 pt-1">
            <button type="button" className="btn-primary" onClick={() => setMode('camera')}>
              <Camera size={16} /> Try again
            </button>
            {onSwitchToPhoto && (
              <button type="button" className="btn-secondary" onClick={onSwitchToPhoto}>
                <ImageIcon size={16} /> Snap label
              </button>
            )}
          </div>
        </div>
      )}

      {mode === 'preview' && preview && (
        <div className="card p-5 space-y-3 animate-in fade-in duration-300">
          <div className="text-xs uppercase tracking-wide text-muted">Review & confirm</div>
          <div>
            <div className="font-display text-2xl">{preview.productName || 'Unnamed product'}</div>
            {preview.brand && <div className="text-sm text-muted mt-0.5">{preview.brand}</div>}
          </div>
          <div className="text-xs text-muted">
            {preview.ingredients
              ? `${preview.ingredients.split(',').length} ingredients parsed`
              : 'No ingredients found yet'}
          </div>
          <div className="flex gap-2 pt-2">
            <button type="button" onClick={confirm} className="btn-primary flex-1">
              Use this product
            </button>
            <button
              type="button"
              onClick={() => setMode('camera')}
              className="btn-secondary"
              aria-label="Scan again"
            >
              <ScanLine size={16} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
