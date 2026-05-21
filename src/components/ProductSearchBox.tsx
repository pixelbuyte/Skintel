import { useEffect, useRef, useState } from 'react';
import { Search, Loader2 } from 'lucide-react';
import { supabase } from '@/lib/supabase';

type SearchResult = {
  code: string;
  productName: string;
  brand: string;
  ingredients: string;
  imageUrl: string;
};

type SelectedPayload = {
  brand?: string | null;
  productName?: string | null;
  ingredients: string;
};

type Props = {
  onSelected: (data: SelectedPayload) => void;
};

export default function ProductSearchBox({ onSelected }: Props) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const [searched, setSearched] = useState(false);
  const containerRef = useRef<HTMLDivElement | null>(null);

  // Close dropdown on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  // Debounced search
  useEffect(() => {
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      setResults([]);
      setSearched(false);
      setLoading(false);
      return;
    }

    let cancelled = false;
    setLoading(true);

    const timer = setTimeout(async () => {
      try {
        const { data: sessionData } = await supabase.auth.getSession();
        const token = sessionData.session?.access_token;
        if (!token) {
          if (!cancelled) {
            setResults([]);
            setSearched(true);
            setLoading(false);
          }
          return;
        }

        const resp = await fetch(`/api/lookup?mode=search&q=${encodeURIComponent(trimmed)}`, {
          headers: { Authorization: `Bearer ${token}` },
        });

        if (cancelled) return;

        if (!resp.ok) {
          setResults([]);
          setSearched(true);
          setLoading(false);
          return;
        }

        const body = (await resp.json()) as { results?: SearchResult[] };
        if (cancelled) return;
        setResults(Array.isArray(body.results) ? body.results : []);
        setSearched(true);
        setOpen(true);
      } catch {
        if (!cancelled) {
          setResults([]);
          setSearched(true);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }, 300);

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [query]);

  function handleSelect(r: SearchResult) {
    onSelected({
      brand: r.brand || null,
      productName: r.productName || null,
      ingredients: r.ingredients,
    });
    setOpen(false);
    setQuery('');
    setResults([]);
    setSearched(false);
  }

  return (
    <div ref={containerRef} className="relative w-full">
      <div className="relative">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onFocus={() => {
            if (results.length > 0 || searched) setOpen(true);
          }}
          placeholder="Search for a product..."
          className="w-full rounded-lg border border-gray-300 bg-white py-2 pl-9 pr-9 text-sm text-gray-900 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        />
        {loading && (
          <Loader2 className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-gray-400" />
        )}
      </div>

      {open && query.trim().length >= 2 && (
        <div className="absolute z-20 mt-1 max-h-96 w-full overflow-y-auto rounded-lg border border-gray-200 bg-white shadow-lg">
          {loading && results.length === 0 ? (
            <div className="flex items-center justify-center gap-2 px-4 py-6 text-sm text-gray-500">
              <Loader2 className="h-4 w-4 animate-spin" />
              <span>Searching...</span>
            </div>
          ) : results.length === 0 && searched ? (
            <div className="px-4 py-6 text-center text-sm text-gray-500">No results found</div>
          ) : (
            <ul className="divide-y divide-gray-100">
              {results.map((r, i) => (
                <li key={`${r.code || 'r'}-${i}`}>
                  <button
                    type="button"
                    onClick={() => handleSelect(r)}
                    className="flex w-full items-center gap-3 px-3 py-2 text-left hover:bg-gray-50"
                  >
                    <div className="h-10 w-10 flex-shrink-0 overflow-hidden rounded bg-gray-100">
                      {r.imageUrl ? (
                        <img
                          src={r.imageUrl}
                          alt=""
                          className="h-full w-full object-cover"
                          loading="lazy"
                        />
                      ) : null}
                    </div>
                    <div className="min-w-0 flex-1">
                      {r.brand && (
                        <div className="truncate text-xs font-medium uppercase tracking-wide text-gray-500">
                          {r.brand}
                        </div>
                      )}
                      <div className="truncate text-sm text-gray-900">
                        {r.productName || 'Unnamed product'}
                      </div>
                    </div>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
