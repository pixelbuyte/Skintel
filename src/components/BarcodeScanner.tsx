import { useEffect, useRef, useState } from 'react';
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
      setErr(e instanceof Error ? e.message : String(e));
    },
    constraints: {
      video: { facingMode: 'environment' },
      audio: false,
    },
  });

  return (
    <div className="fixed inset-0 z-[60] bg-black flex flex-col" style={{ paddingTop: 'env(safe-area-inset-top)', paddingBottom: 'env(safe-area-inset-bottom)' }}>
      <div className="flex justify-between items-center p-4 text-white">
        <span className="font-display text-lg">Scan barcode</span>
        <button
          onClick={onClose}
          className="p-2 -m-2 min-h-11 min-w-11 inline-flex items-center justify-center rounded-full hover:bg-white/10 active:scale-95 transition-transform"
          aria-label="Close scanner"
        >
          <X size={24} />
        </button>
      </div>
      <div className="flex-1 flex items-center justify-center p-4">
        <div className="relative w-full max-w-md aspect-[4/3] bg-black rounded-3xl overflow-hidden shadow-sheet">
          <video ref={ref} className="w-full h-full object-cover" />
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div className="relative w-3/4 h-1/3">
              <div className="absolute inset-0 rounded-2xl border-2 border-white/90 animate-pulse" />
              <div className="absolute -top-1 -left-1 w-6 h-6 border-t-2 border-l-2 border-primary rounded-tl-2xl" />
              <div className="absolute -top-1 -right-1 w-6 h-6 border-t-2 border-r-2 border-primary rounded-tr-2xl" />
              <div className="absolute -bottom-1 -left-1 w-6 h-6 border-b-2 border-l-2 border-primary rounded-bl-2xl" />
              <div className="absolute -bottom-1 -right-1 w-6 h-6 border-b-2 border-r-2 border-primary rounded-br-2xl" />
            </div>
          </div>
        </div>
      </div>
      {err && (
        <div className="text-sm text-red-300 bg-red-900/50 mx-4 mb-4 px-3 py-2 rounded-xl">
          {err}
        </div>
      )}
      <p className="text-white/70 text-xs text-center pb-6 px-4">
        Center the barcode in the frame.
      </p>
    </div>
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
