import { useRef, useState } from 'react';
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

function isValidUrl(s: string): boolean {
  try {
    const u = new URL(s);
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch {
    return false;
  }
}

export default function ImportFromUrl({ onImported }: Props) {
  const [url, setUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const lastImportedRef = useRef<string>('');

  async function runImport(target: string) {
    setError(null);
    const trimmed = target.trim();
    if (!trimmed) {
      setError('Enter a product URL.');
      return;
    }
    if (!isValidUrl(trimmed)) {
      setError('That does not look like a valid URL.');
      return;
    }
    if (loading || lastImportedRef.current === trimmed) return;
    lastImportedRef.current = trimmed;

    setLoading(true);
    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;
      if (!token) {
        setError('You need to be signed in.');
        return;
      }

      const resp = await fetch('/api/lookup?mode=url', {
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

  function handleImport(e?: React.FormEvent) {
    if (e) e.preventDefault();
    void runImport(url);
  }

  function handlePaste(e: React.ClipboardEvent<HTMLInputElement>) {
    const pasted = e.clipboardData.getData('text').trim();
    if (isValidUrl(pasted)) {
      e.preventDefault();
      setUrl(pasted);
      // fire immediately on paste
      void runImport(pasted);
    }
  }

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const v = e.target.value;
    setUrl(v);
    // if user typed/pasted full URL via keyboard, fire after a short pause
    if (isValidUrl(v) && v !== lastImportedRef.current) {
      const target = v;
      window.setTimeout(() => {
        if (target === v) void runImport(target);
      }, 500);
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
            placeholder="Paste any product URL — auto-imports"
            value={url}
            onChange={handleChange}
            onPaste={handlePaste}
            disabled={loading}
            autoComplete="off"
          />
          {loading && (
            <div className="inline-flex items-center gap-2 text-sm text-muted">
              <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />
              Importing
            </div>
          )}
        </div>
        <p className="text-[11px] text-muted">
          Paste a link from Sephora, Ulta, Amazon, or any brand site — Skintel fetches ingredients automatically.
        </p>
      </div>
      {error && (
        <p className="text-sm text-bad-ink" role="alert">
          {error}
        </p>
      )}
    </form>
  );
}
