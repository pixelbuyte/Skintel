import { useState } from 'react';
import { Loader2 } from 'lucide-react';
import { supabase } from '@/lib/supabase';

type ImportedData = {
  brand?: string;
  productName?: string;
  ingredients: string;
};

type Props = {
  onImported: (data: ImportedData) => void;
};

export default function ImportFromUrl({ onImported }: Props) {
  const [url, setUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleImport(e?: React.FormEvent) {
    if (e) e.preventDefault();
    setError(null);
    const trimmed = url.trim();
    if (!trimmed) {
      setError('Enter a product URL.');
      return;
    }
    try {
      // eslint-disable-next-line no-new
      new URL(trimmed);
    } catch {
      setError('That does not look like a valid URL.');
      return;
    }

    setLoading(true);
    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;
      if (!token) {
        setError('You need to be signed in.');
        return;
      }

      const resp = await fetch('/api/import-url', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ url: trimmed }),
      });

      const payload = (await resp.json().catch(() => null)) as
        | (ImportedData & { error?: string; detail?: string })
        | null;

      if (!resp.ok || !payload) {
        const msg =
          payload?.error ??
          (resp.status === 402
            ? 'Pro plan required to import from URL.'
            : resp.status === 401
              ? 'Please sign in again.'
              : `Import failed (${resp.status}).`);
        setError(msg);
        return;
      }

      if (!payload.ingredients) {
        setError('No ingredients found on that page.');
        return;
      }

      onImported({
        brand: payload.brand,
        productName: payload.productName,
        ingredients: payload.ingredients,
      });
      setUrl('');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Import failed.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={handleImport} className="card p-4 space-y-3">
      <div className="space-y-1">
        <label className="label" htmlFor="import-url">
          Import from product URL
        </label>
        <div className="flex gap-2">
          <input
            id="import-url"
            type="url"
            className="input flex-1"
            placeholder="https://brand.com/products/moisturizer"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            disabled={loading}
            autoComplete="off"
          />
          <button
            type="submit"
            className="btn-primary inline-flex items-center gap-2"
            disabled={loading || !url.trim()}
          >
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />
                Importing
              </>
            ) : (
              'Import'
            )}
          </button>
        </div>
      </div>
      {error && (
        <p className="text-sm text-bad-ink" role="alert">
          {error}
        </p>
      )}
    </form>
  );
}
