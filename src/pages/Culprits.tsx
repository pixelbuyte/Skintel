import { Link } from 'react-router-dom';
import { AlertTriangle, AlertCircle } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useCulprits } from '@/hooks/useCulprits';
import { EmptyState } from '@/components/EmptyState';
import type { Culprit } from '@/lib/types';

function CulpritCard({ c, severity }: { c: Culprit; severity: 'high' | 'medium' }) {
  const bgHeader = severity === 'high' ? 'bg-bad-bg' : 'bg-unsure-bg';
  const fgHeader = severity === 'high' ? 'text-bad-fg' : 'text-unsure-fg';
  return (
    <div className="card overflow-hidden">
      <div className={`flex items-center justify-between px-5 py-3 ${bgHeader} ${fgHeader}`}>
        <span className="font-mono text-sm">{c.name}</span>
        <span className="text-xs font-medium">in {c.badCount} breakouts</span>
      </div>
      <div className="p-5 text-sm">
        <div className="text-muted mb-1">Appeared in:</div>
        <ul className="space-y-1">
          {c.badProducts.map((p) => (
            <li key={p}>· {p}</li>
          ))}
        </ul>
        {c.goodProducts.length > 0 && (
          <>
            <div className="text-muted mb-1 mt-3">Also in safe products:</div>
            <ul className="space-y-1 text-muted">
              {c.goodProducts.map((p) => (
                <li key={p}>· {p}</li>
              ))}
            </ul>
          </>
        )}
      </div>
    </div>
  );
}

export default function Culprits() {
  const { products, loading } = useProducts();
  const { high, medium } = useCulprits(products);
  const badCount = products.filter((p) => p.outcome === 'bad').length;

  if (loading) return <div className="text-muted">Loading…</div>;

  if (badCount < 2) {
    return (
      <div>
        <h1 className="font-display text-4xl mb-6">Suspect ingredients</h1>
        <EmptyState
          title="Not enough data yet"
          body="Tag at least 2 products as 'broke me out' to start seeing your suspect ingredients."
          cta={
            <Link to="/app/products/new" className="btn-primary">
              Add a product
            </Link>
          }
        />
      </div>
    );
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="font-display text-4xl">Suspect ingredients</h1>
        <p className="text-muted text-sm mt-1">
          Ingredients showing up across your breakout products — ranked by how often.
        </p>
      </div>

      <section className="mb-10">
        <div className="flex items-center gap-2 mb-4">
          <AlertTriangle className="text-bad-fg" size={20} />
          <h2 className="font-display text-2xl">High risk</h2>
          <span className="text-xs text-muted">— only in breakout products</span>
        </div>
        {high.length === 0 ? (
          <div className="text-muted text-sm">None yet.</div>
        ) : (
          <div className="grid md:grid-cols-2 gap-4">
            {high.map((c) => (
              <CulpritCard key={c.normalized} c={c} severity="high" />
            ))}
          </div>
        )}
      </section>

      <section>
        <div className="flex items-center gap-2 mb-4">
          <AlertCircle className="text-unsure-fg" size={20} />
          <h2 className="font-display text-2xl">Medium risk</h2>
          <span className="text-xs text-muted">— also in some safe products</span>
        </div>
        {medium.length === 0 ? (
          <div className="text-muted text-sm">None yet.</div>
        ) : (
          <div className="grid md:grid-cols-2 gap-4">
            {medium.map((c) => (
              <CulpritCard key={c.normalized} c={c} severity="medium" />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
