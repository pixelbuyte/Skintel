import { Link } from 'react-router-dom';
import { Package, Check, X, HelpCircle, ScanLine, ArrowRight, TrendingUp, Sparkles, AlertTriangle } from 'lucide-react';
import { useProducts } from '@/hooks/useProducts';
import { useCulprits } from '@/hooks/useCulprits';
import { useAuth } from '@/hooks/useAuth';
import { OutcomeBadge } from '@/components/OutcomeBadge';
import { isPreview } from '@/lib/preview';

function PremiumStatCard({
  label,
  value,
  total,
  icon,
  accent,
  trend,
}: {
  label: string;
  value: number;
  total?: number;
  icon: React.ReactNode;
  accent: 'good' | 'bad' | 'unsure' | 'primary';
  trend?: string;
}) {
  const colors = {
    good: { text: 'text-good-fg', bg: 'bg-good-bg', ring: 'ring-good-fg/20', dot: 'bg-good-fg', grad: 'from-good-bg/60 to-good-bg/10' },
    bad: { text: 'text-bad-fg', bg: 'bg-bad-bg', ring: 'ring-bad-fg/20', dot: 'bg-bad-fg', grad: 'from-bad-bg/60 to-bad-bg/10' },
    unsure: { text: 'text-unsure-fg', bg: 'bg-unsure-bg', ring: 'ring-unsure-fg/20', dot: 'bg-unsure-fg', grad: 'from-unsure-bg/60 to-unsure-bg/10' },
    primary: { text: 'text-primary', bg: 'bg-primary/10', ring: 'ring-primary/20', dot: 'bg-primary', grad: 'from-primary/15 to-primary/5' },
  }[accent];
  const pct = total ? Math.round((value / total) * 100) : null;
  return (
    <div className={`relative card p-4 overflow-hidden transition-all duration-300 hover:-translate-y-0.5 hover:shadow-soft ring-1 ${colors.ring}`}>
      <div aria-hidden className={`absolute -top-12 -right-12 size-32 rounded-full blur-2xl bg-gradient-to-br ${colors.grad}`} />
      <div className="relative flex items-center justify-between mb-3">
        <span className="text-[10px] uppercase tracking-[0.16em] text-muted font-semibold">{label}</span>
        <div className={`size-7 rounded-lg ${colors.bg} ${colors.text} flex items-center justify-center`}>
          {icon}
        </div>
      </div>
      <div className="relative flex items-baseline gap-1.5">
        <span className={`font-display text-4xl leading-none ${colors.text}`}>{value}</span>
        {pct !== null && <span className="text-xs text-muted font-medium">{pct}%</span>}
      </div>
      {trend && (
        <div className="relative text-[10px] text-muted mt-2 flex items-center gap-1">
          <span className={`size-1 rounded-full ${colors.dot}`} />
          {trend}
        </div>
      )}
    </div>
  );
}

export default function Dashboard() {
  const { user } = useAuth();
  const { products, loading } = useProducts();
  const { high, medium } = useCulprits(products);

  const total = products.length;
  const good = products.filter((p) => p.outcome === 'good').length;
  const bad = products.filter((p) => p.outcome === 'bad').length;
  const unsure = products.filter((p) => p.outcome === 'unsure').length;
  const topSuspects = [...high, ...medium].slice(0, 5);
  const recent = products.slice(0, 6);
  const previewing = isPreview();
  const firstName = previewing
    ? 'preview'
    : user?.email
      ? user.email.split('@')[0]
      : '';

  return (
    <div className="relative">
      {previewing && (
        <div className="mb-5 inline-flex items-center gap-2 text-[10px] uppercase tracking-[0.18em] text-primary bg-primary/10 border border-primary/25 px-3 py-1.5 rounded-full font-semibold">
          <span className="size-1.5 rounded-full bg-primary animate-pulse" />
          Preview mode · seeded demo data
        </div>
      )}

      <div className="mb-8 flex items-end justify-between flex-wrap gap-3">
        <div>
          <p className="text-muted text-sm flex items-center gap-1.5">
            <Sparkles size={12} className="text-primary" />
            Welcome back{firstName ? `, ${firstName}` : ''}
          </p>
          <h1 className="font-display text-4xl md:text-5xl mt-1 tracking-tight">
            Your skin, <span className="italic text-primary">decoded.</span>
          </h1>
          <p className="text-muted text-sm mt-2 max-w-[52ch]">
            Track what works. Skip what doesn't. Your personal trigger map updates with every product you log.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Link to="/app/scanner" className="btn-secondary">
            <ScanLine size={14} /> Scan label
          </Link>
          <Link to="/app/products/new" className="btn-primary">
            Add product <ArrowRight size={14} />
          </Link>
        </div>
      </div>

      {loading ? (
        <div className="text-muted">Loading…</div>
      ) : (
        <>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 md:gap-4 mb-8">
            <PremiumStatCard
              label="Logged"
              value={total}
              icon={<Package size={14} />}
              accent="primary"
              trend={total > 0 ? `${recent.length} this month` : 'Start logging'}
            />
            <PremiumStatCard
              label="Worked"
              value={good}
              total={total}
              icon={<Check size={14} />}
              accent="good"
              trend={good > 0 ? 'Keep buying these' : '—'}
            />
            <PremiumStatCard
              label="Broke out"
              value={bad}
              total={total}
              icon={<X size={14} />}
              accent="bad"
              trend={bad > 0 ? 'Pattern detected' : '—'}
            />
            <PremiumStatCard
              label="Unsure"
              value={unsure}
              total={total}
              icon={<HelpCircle size={14} />}
              accent="unsure"
              trend={unsure > 0 ? 'Needs more data' : '—'}
            />
          </div>

          <div className="grid md:grid-cols-3 gap-4 md:gap-6 mb-6">
            <div className="card p-6 md:col-span-2 relative overflow-hidden">
              <div aria-hidden className="absolute -top-24 -right-24 size-64 bg-primary/10 blur-3xl rounded-full pointer-events-none" />
              <div className="relative flex items-center justify-between mb-5">
                <div>
                  <div className="text-[10px] uppercase tracking-[0.18em] text-muted font-semibold mb-1">Pattern detection</div>
                  <h2 className="font-display text-2xl leading-tight flex items-center gap-2">
                    <AlertTriangle size={16} className="text-primary" />
                    Top suspect ingredients
                  </h2>
                </div>
                <Link to="/app/culprits" className="text-sm text-primary inline-flex items-center gap-1 hover:gap-1.5 transition-all">
                  See all <ArrowRight size={14} />
                </Link>
              </div>
              {topSuspects.length === 0 ? (
                <div className="text-center py-8 text-muted text-sm">
                  <div className="size-10 rounded-full bg-primary/10 mx-auto mb-3 flex items-center justify-center text-primary">
                    <Sparkles size={16} />
                  </div>
                  Tag at least 2 products as <span className="text-bad-fg font-medium">"broke me out"</span> to surface your personal triggers.
                </div>
              ) : (
                <ul className="relative space-y-2">
                  {topSuspects.map((c, i) => {
                    const maxBad = topSuspects[0]?.badCount ?? 1;
                    const widthPct = Math.max(8, Math.round((c.badCount / maxBad) * 100));
                    return (
                      <li
                        key={c.normalized}
                        className="group relative rounded-xl border border-border bg-card hover:border-primary/30 hover:shadow-soft transition-all duration-200 overflow-hidden"
                        style={{ animation: `streamIn 320ms ease-out forwards`, animationDelay: `${i * 70}ms`, opacity: 0 }}
                      >
                        <div
                          aria-hidden
                          className={`absolute left-0 top-0 bottom-0 ${c.risk === 'high' ? 'bg-bad-bg/40' : 'bg-unsure-bg/40'} transition-all duration-500`}
                          style={{ width: `${widthPct}%` }}
                        />
                        <div className="relative flex items-center justify-between px-4 py-2.5">
                          <div className="flex items-center gap-2.5 min-w-0">
                            <div className={`size-2 rounded-full ${c.risk === 'high' ? 'bg-bad-fg' : 'bg-unsure-fg'} shadow-[0_0_8px_currentColor]`} />
                            <span className="font-mono text-sm font-medium truncate">{c.name}</span>
                          </div>
                          <div className="flex items-center gap-3 shrink-0">
                            <span className="text-xs text-muted font-mono">
                              {c.badCount}× in flares
                            </span>
                            <span
                              className={`text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider ${
                                c.risk === 'high' ? 'bg-bad-bg text-bad-fg ring-1 ring-bad-fg/30' : 'bg-unsure-bg text-unsure-fg ring-1 ring-unsure-fg/30'
                              }`}
                            >
                              {c.risk}
                            </span>
                          </div>
                        </div>
                      </li>
                    );
                  })}
                </ul>
              )}
            </div>

            <Link
              to="/app/scanner"
              className="card p-6 hover:border-primary hover:shadow-soft transition-all duration-300 flex flex-col relative overflow-hidden group"
            >
              <div aria-hidden className="absolute -bottom-12 -right-12 size-40 bg-primary/15 blur-3xl rounded-full group-hover:bg-primary/25 transition-colors duration-500" />
              <div className="relative">
                <div className="size-10 rounded-xl bg-primary/15 text-primary flex items-center justify-center mb-3 group-hover:rotate-6 group-hover:scale-110 transition-transform duration-300">
                  <ScanLine size={20} />
                </div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-muted font-semibold mb-1">Quick action</div>
                <h3 className="font-display text-2xl mb-1 leading-tight">Scan a product</h3>
                <p className="text-muted text-sm">
                  Paste any INCI list. Get a verdict in under a second.
                </p>
                <span className="text-primary text-sm font-semibold inline-flex items-center gap-1 mt-4 group-hover:gap-2 transition-all">
                  Open scanner <ArrowRight size={14} />
                </span>
              </div>
            </Link>
          </div>

          <div className="card p-6 relative overflow-hidden">
            <div className="flex items-center justify-between mb-4">
              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-muted font-semibold mb-1">Recent activity</div>
                <h2 className="font-display text-2xl leading-tight flex items-center gap-2">
                  <TrendingUp size={16} className="text-primary" />
                  Recent products
                </h2>
              </div>
              <Link to="/app/products" className="text-sm text-primary inline-flex items-center gap-1 hover:gap-1.5 transition-all">
                See all <ArrowRight size={14} />
              </Link>
            </div>
            {recent.length === 0 ? (
              <div className="text-center py-8 text-muted text-sm">
                <div className="size-10 rounded-full bg-primary/10 mx-auto mb-3 flex items-center justify-center text-primary">
                  <Package size={16} />
                </div>
                No products yet.
                <div className="mt-3">
                  <Link to="/app/products/new" className="btn-primary inline-flex">
                    Log your first product <ArrowRight size={14} />
                  </Link>
                </div>
              </div>
            ) : (
              <ul className="divide-y divide-border">
                {recent.map((p, i) => (
                  <li
                    key={p.id}
                    className="py-3 flex items-center justify-between gap-3 hover:bg-bg/40 -mx-2 px-2 rounded-lg transition-colors"
                    style={{ animation: `streamIn 300ms ease-out forwards`, animationDelay: `${i * 50}ms`, opacity: 0 }}
                  >
                    <Link to={`/app/products/${p.id}`} className="flex items-center gap-3 min-w-0 flex-1 hover:text-primary transition-colors">
                      <div
                        className={`size-9 rounded-lg flex items-center justify-center shrink-0 ${
                          p.outcome === 'good'
                            ? 'bg-good-bg text-good-fg'
                            : p.outcome === 'bad'
                              ? 'bg-bad-bg text-bad-fg'
                              : 'bg-unsure-bg text-unsure-fg'
                        }`}
                      >
                        {p.outcome === 'good' ? <Check size={14} /> : p.outcome === 'bad' ? <X size={14} /> : <HelpCircle size={14} />}
                      </div>
                      <div className="min-w-0">
                        <div className="font-medium truncate">{p.product_name}</div>
                        {p.brand && <div className="text-xs text-muted truncate">{p.brand}</div>}
                      </div>
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
