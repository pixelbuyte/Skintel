import { useMemo, useState } from 'react';
import { ScanLine, CheckCircle2, AlertTriangle } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useCulprits } from '@/hooks/useCulprits';
import { useSubscription } from '@/hooks/useSubscription';
import { parseInci } from '@/lib/inci';
import { PaywallBanner } from '@/components/PaywallBanner';

const EXAMPLE = `Water, Glycerin, Niacinamide, Cetyl Alcohol, Caprylic/Capric Triglyceride, Ceramide NP, Sodium Hyaluronate, Phenoxyethanol, Fragrance`;

export default function Scanner() {
  const { products } = useProducts();
  const { high, medium } = useCulprits(products);
  const { canUseScanner } = useSubscription();
  const [input, setInput] = useState('');
  const [scanned, setScanned] = useState<string | null>(null);

  const culpritMap = useMemo(() => {
    const m = new Map<string, { name: string; risk: 'high' | 'medium'; badCount: number }>();
    for (const c of high) m.set(c.normalized, { name: c.name, risk: 'high', badCount: c.badCount });
    for (const c of medium) m.set(c.normalized, { name: c.name, risk: 'medium', badCount: c.badCount });
    return m;
  }, [high, medium]);

  const matches = useMemo(() => {
    if (!scanned) return null;
    const parsed = parseInci(scanned);
    const out: { name: string; risk: 'high' | 'medium'; badCount: number }[] = [];
    for (const i of parsed) {
      const hit = culpritMap.get(i.normalized);
      if (hit) out.push(hit);
    }
    out.sort((a, b) => (a.risk === b.risk ? b.badCount - a.badCount : a.risk === 'high' ? -1 : 1));
    return out;
  }, [scanned, culpritMap]);

  if (!canUseScanner) {
    return (
      <div>
        <h1 className="font-display text-4xl mb-6">Scanner</h1>
        <PaywallBanner reason="scanner" />
      </div>
    );
  }

  return (
    <div className="max-w-3xl">
      <div className="mb-6">
        <h1 className="font-display text-4xl">Scanner</h1>
        <p className="text-muted text-sm mt-1">
          Paste any product's INCI list. We'll check it against your personal triggers.
        </p>
      </div>

      <div className="card p-6">
        <label className="label">Ingredient list</label>
        <textarea
          className="input min-h-40 font-mono text-xs"
          placeholder="Paste an INCI list from any product page…"
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <div className="flex gap-2 mt-3">
          <button className="btn-primary" disabled={!input.trim()} onClick={() => setScanned(input)}>
            <ScanLine size={16} /> Scan
          </button>
          <button
            className="btn-ghost"
            onClick={() => {
              setInput(EXAMPLE);
              setScanned(null);
            }}
          >
            Try example
          </button>
        </div>
      </div>

      {matches && matches.length === 0 && (
        <div className="card mt-6 p-6 bg-good-bg text-good-fg flex items-start gap-3">
          <CheckCircle2 size={24} className="shrink-0 mt-0.5" />
          <div>
            <div className="font-display text-xl mb-1">No known triggers found</div>
            <p className="text-sm">This product doesn't contain any of your flagged ingredients.</p>
          </div>
        </div>
      )}

      {matches && matches.length > 0 && (
        <div className="card mt-6 p-6 bg-bad-bg text-bad-fg">
          <div className="flex items-start gap-3 mb-4">
            <AlertTriangle size={24} className="shrink-0 mt-0.5" />
            <div>
              <div className="font-display text-xl mb-1">
                {matches.length} suspect ingredient{matches.length === 1 ? '' : 's'} detected
              </div>
              <p className="text-sm">
                This product contains ingredients that appear in your breakouts.
              </p>
            </div>
          </div>
          <ul className="space-y-2">
            {matches.map((m) => (
              <li key={m.name} className="flex items-center justify-between bg-card rounded-lg px-4 py-2 text-ink">
                <span className="font-mono text-sm">{m.name}</span>
                <span className="text-xs">
                  {m.risk === 'high' ? 'HIGH' : 'MEDIUM'} · in {m.badCount} breakouts
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
