import { Link } from 'react-router-dom';
import { Package, Check, X, HelpCircle, ScanLine, ArrowRight } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useCulprits } from '@/hooks/useCulprits';
import { useAuth } from '@/hooks/useAuth';
import { StatCard } from '@/components/StatCard';
import { OutcomeBadge } from '@/components/OutcomeBadge';

export default function Dashboard() {
  const { user } = useAuth();
  const { products, loading } = useProducts();
  const { high, medium } = useCulprits(products);

  const total = products.length;
  const good = products.filter((p) => p.outcome === 'good').length;
  const bad = products.filter((p) => p.outcome === 'bad').length;
  const unsure = products.filter((p) => p.outcome === 'unsure').length;
  const topSuspects = [...high, ...medium].slice(0, 4);

  return (
    <div>
      <div className="mb-8">
        <p className="text-muted text-sm">Welcome back{user?.email ? `, ${user.email.split('@')[0]}` : ''}</p>
        <h1 className="font-display text-4xl mt-1">Your skin, decoded.</h1>
      </div>

      {loading ? (
        <div className="text-muted">Loading…</div>
      ) : (
        <>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
            <StatCard label="Total products" value={total} icon={<Package size={18} />} accent="primary" />
            <StatCard label="Worked" value={good} icon={<Check size={18} />} accent="good" />
            <StatCard label="Broke you out" value={bad} icon={<X size={18} />} accent="bad" />
            <StatCard label="Unsure" value={unsure} icon={<HelpCircle size={18} />} accent="unsure" />
          </div>

          <div className="grid md:grid-cols-3 gap-6 mb-8">
            <div className="card p-6 md:col-span-2">
              <div className="flex items-center justify-between mb-4">
                <h2 className="font-display text-2xl">Top suspect ingredients</h2>
                <Link to="/app/culprits" className="text-sm text-primary inline-flex items-center gap-1">
                  See all <ArrowRight size={14} />
                </Link>
              </div>
              {topSuspects.length === 0 ? (
                <p className="text-muted text-sm">
                  Tag at least 2 products as 'broke me out' to see your personal triggers.
                </p>
              ) : (
                <ul className="space-y-2">
                  {topSuspects.map((c) => (
                    <li
                      key={c.normalized}
                      className="flex items-center justify-between border border-border rounded-lg px-4 py-2.5"
                    >
                      <span className="font-mono text-sm">{c.name}</span>
                      <div className="flex items-center gap-3">
                        <span className="text-xs text-muted">in {c.badCount} breakouts</span>
                        <span
                          className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                            c.risk === 'high' ? 'bg-bad-bg text-bad-fg' : 'bg-unsure-bg text-unsure-fg'
                          }`}
                        >
                          {c.risk.toUpperCase()}
                        </span>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>

            <Link
              to="/app/scanner"
              className="card p-6 hover:border-primary transition flex flex-col"
            >
              <ScanLine className="text-primary mb-3" size={28} />
              <h3 className="font-display text-2xl mb-1">Scan a product</h3>
              <p className="text-muted text-sm flex-1">
                Paste any INCI list to instantly see if it contains your triggers.
              </p>
              <span className="text-primary text-sm font-medium inline-flex items-center gap-1 mt-3">
                Open scanner <ArrowRight size={14} />
              </span>
            </Link>
          </div>

          <div className="card p-6">
            <div className="flex items-center justify-between mb-2">
              <h2 className="font-display text-2xl">Recent products</h2>
              <Link to="/app/products" className="text-sm text-primary inline-flex items-center gap-1">
                See all <ArrowRight size={14} />
              </Link>
            </div>
            {products.slice(0, 5).length === 0 ? (
              <p className="text-muted text-sm">No products yet.</p>
            ) : (
              <ul className="divide-y divide-border">
                {products.slice(0, 5).map((p) => (
                  <li key={p.id} className="py-3 flex items-center justify-between">
                    <Link to={`/app/products/${p.id}`} className="hover:text-primary">
                      <div className="font-medium">{p.product_name}</div>
                      {p.brand && <div className="text-xs text-muted">{p.brand}</div>}
                    </Link>
                    <OutcomeBadge outcome={p.outcome} size="sm" />
                  </li>
                ))}
              </ul>
            )}
          </div>
        </>
      )}
    </div>
  );
}
