import { useState, useRef } from 'react';
import { ScanBarcode, Loader2, Camera, X } from 'lucide-react';
import { useZxing } from 'react-zxing';
import type { Result } from '@zxing/library';
import { supabase } from '@/lib/supabase';

type ScanResult = {
  brand?: string | null;
  productName?: string | null;
  ingredients: string;
  upc: string;
};

type LookupResponse = {
  brand?: string | null;
  productName?: string | null;
  ingredients?: string;
  source?: 'openbeautyfacts' | 'openfoodfacts' | null;
  error?: string;
};

function CameraScanner({
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
    <div className="fixed inset-0 z-50 bg-black/90 flex flex-col">
      <div className="flex justify-between items-center p-4 text-white">
        <span className="font-display text-lg">Point at barcode</span>
        <button onClick={onClose} className="p-2 hover:bg-white/10 rounded-full">
          <X size={24} />
        </button>
      </div>
      <div className="flex-1 flex items-center justify-center p-4">
        <div className="relative w-full max-w-md aspect-[4/3] bg-black rounded-lg overflow-hidden">
          <video ref={ref} className="w-full h-full object-cover" />
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div className="border-2 border-red-500 w-3/4 h-1/3 rounded" />
          </div>
        </div>
      </div>
      {err && (
        <div className="text-sm text-red-300 bg-red-900/50 mx-4 mb-4 px-3 py-2 rounded">
          {err}
        </div>
      )}
      <p className="text-white/70 text-xs text-center pb-4 px-4">
        Hold steady. Auto-detects EAN/UPC.
      </p>
    </div>
  );
}

export default function BarcodeScanner({
  onScanned,
}: {
  onScanned: (data: ScanResult) => void;
}) {
  const [upc, setUpc] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [preview, setPreview] = useState<ScanResult | null>(null);
  const [cameraOpen, setCameraOpen] = useState(false);

  async function lookup(codeArg?: string) {
    setError(null);
    setPreview(null);
    const cleaned = (codeArg ?? upc).trim();
    if (!/^\d{8,13}$/.test(cleaned)) {
      setError('UPC must be 8-13 digits.');
      return;
    }
    setLoading(true);
    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;
      if (!token) {
        setError('You must be signed in.');
        return;
      }
      const r = await fetch(`/api/lookup?mode=barcode&upc=${encodeURIComponent(cleaned)}`, {
        method: 'GET',
        headers: { Authorization: `Bearer ${token}` },
      });
      const body = (await r.json()) as LookupResponse;
      if (!r.ok) {
        setError(body.error ?? `Lookup failed (${r.status})`);
        return;
      }
      setPreview({
        brand: body.brand ?? null,
        productName: body.productName ?? null,
        ingredients: body.ingredients ?? '',
        upc: cleaned,
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Network error');
    } finally {
      setLoading(false);
    }
  }

  function confirm() {
    if (preview) onScanned(preview);
  }

  function onCameraDetect(code: string) {
    setCameraOpen(false);
    setUpc(code);
    lookup(code);
  }

  return (
    <div className="card p-6 space-y-4">
      <div className="flex items-center gap-2">
        <ScanBarcode className="text-primary" size={22} />
        <h3 className="font-display text-xl">Scan a barcode</h3>
      </div>

      <p className="text-muted text-sm">
        Use camera or enter UPC/EAN. Returns brand, product name, ingredient list.
      </p>

      <button
        type="button"
        onClick={() => setCameraOpen(true)}
        className="btn-primary w-full inline-flex items-center justify-center gap-2"
        disabled={loading}
      >
        <Camera size={18} />
        Scan with camera
      </button>

      <div className="flex items-center gap-2 text-xs text-muted">
        <div className="flex-1 h-px bg-gray-200" />
        <span>or type</span>
        <div className="flex-1 h-px bg-gray-200" />
      </div>

      <div className="flex flex-col sm:flex-row gap-2">
        <input
          type="text"
          inputMode="numeric"
          pattern="[0-9]*"
          maxLength={13}
          value={upc}
          onChange={(e) => setUpc(e.target.value.replace(/\D/g, ''))}
          placeholder="e.g. 3600523971084"
          className="flex-1 rounded-md border border-gray-300 px-3 py-2 text-base focus:outline-none focus:ring-2 focus:ring-primary"
          disabled={loading}
        />
        <button
          type="button"
          onClick={() => lookup()}
          disabled={loading || !upc.trim()}
          className="btn-primary inline-flex items-center justify-center gap-2 disabled:opacity-50"
        >
          {loading ? <Loader2 className="animate-spin" size={16} /> : <ScanBarcode size={16} />}
          {loading ? 'Looking up…' : 'Lookup'}
        </button>
      </div>

      {error && (
        <div className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-md px-3 py-2">
          {error}
        </div>
      )}

      {preview && (
        <div className="border border-gray-200 rounded-md p-4 space-y-2 bg-gray-50">
          <div className="text-sm">
            <span className="text-muted">Brand: </span>
            <span className="font-medium">{preview.brand || '—'}</span>
          </div>
          <div className="text-sm">
            <span className="text-muted">Product: </span>
            <span className="font-medium">{preview.productName || '—'}</span>
          </div>
          <div className="text-sm">
            <span className="text-muted">Ingredients:</span>
            <p className="mt-1 text-xs leading-relaxed max-h-32 overflow-y-auto">
              {preview.ingredients || '(none returned)'}
            </p>
          </div>
          <div className="flex gap-2 pt-2">
            <button type="button" onClick={confirm} className="btn-primary text-sm">
              Use this product
            </button>
            <button
              type="button"
              onClick={() => setPreview(null)}
              className="text-sm px-3 py-2 rounded-md border border-gray-300 hover:bg-gray-100"
            >
              Discard
            </button>
          </div>
        </div>
      )}

      {cameraOpen && (
        <CameraScanner
          onDetected={onCameraDetect}
          onClose={() => setCameraOpen(false)}
        />
      )}
    </div>
  );
}
