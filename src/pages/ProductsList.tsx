import { Link } from 'react-router-dom';
import { Plus, ChevronRight } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useSubscription } from '@/hooks/useSubscription';
import { OutcomeBadge } from '@/components/OutcomeBadge';
import { EmptyState } from '@/components/EmptyState';
import { formatDate, pluralize } from '@/lib/format';

export default function ProductsList() {
  const { products, loading } = useProducts();
  const { tier, productLimit } = useSubscription();
  const atCap = tier === 'free' && products.length >= productLimit;

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="font-display text-4xl">Your products</h1>
          <p className="text-muted text-sm mt-1">
            {products.length} tracked
            {tier === 'free' && ` · ${products.length}/${productLimit} on free plan`}
          </p>
        </div>
        <Link
          to={atCap ? '/pricing' : '/app/products/new'}
          className="btn-primary"
        >
          <Plus size={16} />
          {atCap ? 'Upgrade to add more' : 'Add product'}
        </Link>
      </div>

      {loading ? (
        <div className="text-muted">Loading…</div>
      ) : products.length === 0 ? (
        <EmptyState
          title="No products yet"
          body="Start by logging the products in your current routine. Tag what works and what doesn't — Skintel will surface the patterns."
          cta={
            <Link to="/app/products/new" className="btn-primary">
              <Plus size={16} /> Add your first product
            </Link>
          }
        />
      ) : (
        <div className="card overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wide text-muted border-b border-border">
                <th className="px-5 py-3 font-medium">Product</th>
                <th className="px-5 py-3 font-medium hidden md:table-cell">Brand</th>
                <th className="px-5 py-3 font-medium">Outcome</th>
                <th className="px-5 py-3 font-medium hidden md:table-cell">Ingredients</th>
                <th className="px-5 py-3 font-medium hidden md:table-cell">Added</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {products.map((p) => (
                <tr
                  key={p.id}
                  className="border-b border-border last:border-b-0 hover:bg-bg/60 transition"
                >
                  <td className="px-5 py-4">
                    <Link to={`/app/products/${p.id}`} className="font-medium hover:text-primary">
                      {p.product_name}
                    </Link>
                    {p.category && <div className="text-xs text-muted mt-0.5">{p.category}</div>}
                  </td>
                  <td className="px-5 py-4 hidden md:table-cell text-muted text-sm">{p.brand ?? '—'}</td>
                  <td className="px-5 py-4">
                    <OutcomeBadge outcome={p.outcome} size="sm" />
                  </td>
                  <td className="px-5 py-4 hidden md:table-cell text-muted text-sm">
                    {pluralize(p.product_ingredients?.length ?? 0, 'ingredient')}
                  </td>
                  <td className="px-5 py-4 hidden md:table-cell text-muted text-sm">
                    {formatDate(p.created_at)}
                  </td>
                  <td className="px-5 py-4 text-right">
                    <Link to={`/app/products/${p.id}`} className="text-muted hover:text-primary inline-flex">
                      <ChevronRight size={18} />
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
