import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, Beaker } from 'lucide-react';
import { parseInci } from '@/lib/inci';
import {
  categorizeIngredients,
  generateVerdict,
  type Culprit,
} from '@/lib/ingredient-knowledge';
import { VerdictCard } from './VerdictCard';
import { Bucket } from './Bucket';

const SAMPLE =
  'Aqua, Glycerin, Niacinamide, Bisabolol, Coconut Alkanes, Ceramide NP, Panthenol, Fragrance, Linalool, Sodium Hyaluronate';

const EMPTY_MAP: Map<string, Culprit> = new Map();

export function TryItDemo() {
  const [input, setInput] = useState('');
  const [analyzed, setAnalyzed] = useState<string | null>(null);

  const result = useMemo(() => {
    if (!analyzed) return null;
    const parsed = parseInci(analyzed);
    if (parsed.length === 0) return null;
    const buckets = categorizeIngredients(parsed, EMPTY_MAP);
    const verdict = generateVerdict(buckets);
    return { buckets, verdict, count: parsed.length };
  }, [analyzed]);

  return (
    <div className="card p-6 md:p-8 relative overflow-hidden">
      <div
        aria-hidden
        className="absolute -top-16 -right-16 size-48 bg-primary/8 blur-3xl rounded-full"
      />
      <div className="flex items-center gap-2 text-xs uppercase tracking-[0.14em] text-primary mb-3 font-medium">
        <Beaker size={14} /> Try it now
      </div>
      <h3 className="font-display text-2xl md:text-3xl mb-2 leading-tight">
        Paste any ingredient list.
      </h3>
      <p className="text-muted text-sm mb-5 max-w-[55ch] leading-relaxed">
        See how Skintel parses an INCI list. No account, no upload, runs in your browser.
      </p>

      <textarea
        value={input}
        onChange={(e) => setInput(e.target.value)}
        placeholder="Aqua, Glycerin, Niacinamide, Bisabolol, Fragrance..."
        rows={4}
        className="input font-mono text-xs leading-relaxed resize-none"
      />

      <div className="flex flex-wrap items-center gap-2 mt-3">
        <button
          type="button"
          onClick={() => setAnalyzed(input.trim())}
          disabled={!input.trim()}
          className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
        >
          Analyze
        </button>
        <button
          type="button"
          onClick={() => {
            setInput(SAMPLE);
            setAnalyzed(SAMPLE);
          }}
          className="btn-secondary active:scale-[0.97] transition-transform duration-150 ease-emil"
        >
          Try a sample
        </button>
        {result && (
          <button
            type="button"
            onClick={() => {
              setInput('');
              setAnalyzed(null);
            }}
            className="text-sm text-muted hover:text-ink transition-colors duration-200 ease-emil px-2 py-1.5"
          >
            Clear
          </button>
        )}
      </div>

      {result && (
        <div className="mt-6 space-y-4 animate-rise-in">
          <VerdictCard verdict={result.verdict} />
          <Bucket title="Watch out" tone="bad" rows={result.buckets.watchOut} />
          <Bucket title="Good for your skin" tone="good" rows={result.buckets.good} />
          {result.buckets.rest.length > 0 && (
            <div className="text-xs text-muted">
              + {result.buckets.rest.length} more ingredients in everything else
            </div>
          )}

          <div className="border-t border-border pt-4 mt-2">
            <p className="text-sm text-muted mb-3">
              This demo only flags fragrance markers and well-known ingredients. Sign up to build
              your personal trigger map — Skintel learns from products you tag.
            </p>
            <Link
              to="/login"
              className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
            >
              Build my trigger map <ArrowRight size={16} />
            </Link>
          </div>
        </div>
      )}
    </div>
  );
}
