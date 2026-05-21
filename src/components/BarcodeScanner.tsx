import { useState } from 'react';
import { ScanBarcode, Loader2 } from 'lucide-react';
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

export default function BarcodeScanner({
  onScanned,
}: {
  onScanned: (data: ScanResult) => void;
}) {
  const [upc, setUpc] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [preview, setPreview] = useState<ScanResult | null>(null);

  async function lookup() {
    setError(null);
    setPreview(null);
    const cleaned = upc.trim();
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
      const r = await fetch(`/api/barcode-lookup?upc=${encodeURIComponent(cleaned)}`, {
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

  return (
    <div className="card p-6 space-y-4">
      <div className="flex items-center gap-2">
        <ScanBarcode className="text-primary" size={22} />
        <h3 className="font-display text-xl">Scan a barcode</h3>
      </div>

      <p className="text-muted text-sm">
        Enter the UPC/EAN below to look up brand, product name, and ingredient list.
      </p>

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
          onClick={lookup}
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
    </div>
  );
}
