import { Link } from 'react-router-dom';
import { useEffect, useState } from 'react';
import {
  ArrowRight,
  ChevronDown,
  ScanLine,
  ShieldCheck,
  Sparkles,
  FlaskConical,
  Check,
} from 'lucide-react';

const FAQS = [
  {
    q: 'How does Skintel know what breaks me out?',
    a: "Tag each product 'worked' or 'broke me out' and paste its INCI list. We cross-reference ingredients to surface what only shows up in your breakouts.",
  },
  {
    q: 'Is my data private?',
    a: 'Every row is locked to your account via Postgres row-level security. Export everything as JSON or wipe your account at any time.',
  },
  {
    q: 'Monthly or yearly?',
    a: 'Pro is $9/month or $79/year. Yearly saves you two months. Cancel anytime in either.',
  },
  {
    q: 'Do I need to scan a barcode?',
    a: 'No. Paste the ingredient list from any product page. Skintel normalizes the names automatically.',
  },
];

const STEPS = [
  {
    n: '01',
    icon: <FlaskConical size={20} />,
    title: 'Log your routine',
    body: "Add the products you're actually using. Paste the ingredient list — we parse the INCI so you don't have to.",
    detail: 'Brand · product · outcome',
  },
  {
    n: '02',
    icon: <Sparkles size={20} />,
    title: 'See the pattern',
    body: 'Skintel surfaces the ingredients showing up in your breakout products that never appear in your safe ones.',
    detail: 'Bisabolol · Coconut alkanes · Linalool',
  },
  {
    n: '03',
    icon: <ScanLine size={20} />,
    title: 'Scan before you buy',
    body: 'Snap a label, scan a barcode, or paste any INCI list. Skintel checks it against your personal trigger map.',
    detail: 'Watch out · Good for you · Everything else',
  },
];

export default function Landing() {
  const [openFaq, setOpenFaq] = useState<number | null>(0);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <div className="min-h-[100dvh] bg-bg text-ink overflow-x-hidden">
      <header
        className={`sticky top-0 z-30 transition-colors duration-300 ease-emil ${
          scrolled ? 'bg-bg/85 backdrop-blur-xl border-b border-border/70' : 'bg-transparent'
        }`}
      >
        <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
          <Link to="/" className="font-display text-2xl leading-none">
            Skintel<span className="text-primary">.</span>
          </Link>
          <nav className="flex items-center gap-1 text-sm">
            <Link
              to="/pricing"
              className="px-3 py-2 text-muted hover:text-ink transition-colors duration-200 ease-emil rounded-lg"
            >
              Pricing
            </Link>
            <Link
              to="/login"
              className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
            >
              Get started <ArrowRight size={14} />
            </Link>
          </nav>
        </div>
      </header>

      <section className="relative max-w-6xl mx-auto px-6 pt-12 md:pt-20 pb-20 md:pb-28">
        <div className="grid lg:grid-cols-[1.15fr_1fr] gap-10 lg:gap-16 items-center">
          <div
            className="animate-rise-in"
            style={{ animationDelay: '40ms' }}
          >
            <div className="inline-flex items-center gap-2 text-xs uppercase tracking-[0.14em] text-primary bg-primary/8 border border-primary/15 px-3 py-1.5 rounded-full mb-7">
              <span className="relative flex h-1.5 w-1.5">
                <span className="absolute inline-flex h-full w-full rounded-full bg-primary animate-breathe" />
                <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-primary" />
              </span>
              Personal ingredient intelligence
            </div>

            <h1 className="font-display text-[2.75rem] sm:text-6xl lg:text-[4.25rem] leading-[1.02] tracking-tight mb-6">
              Stop guessing why
              <br />
              your skin{' '}
              <span className="italic text-primary">broke out.</span>
            </h1>

            <p className="text-lg text-muted max-w-xl mb-8 leading-relaxed">
              Log the products in your routine, tag what works, and Skintel surfaces the exact
              ingredients showing up in your breakouts — so you can avoid them next time.
            </p>

            <div className="flex items-center gap-3 flex-wrap">
              <Link
                to="/login"
                className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
              >
                Start tracking free <ArrowRight size={16} />
              </Link>
              <Link
                to="/pricing"
                className="btn-secondary active:scale-[0.97] transition-transform duration-150 ease-emil"
              >
                See pricing
              </Link>
            </div>

            <div className="mt-10 flex items-center gap-5 text-xs text-muted">
              <div className="flex items-center gap-1.5">
                <ShieldCheck size={14} className="text-primary/80" />
                Private by default
              </div>
              <div className="h-3 w-px bg-border" />
              <div>Cancel anytime</div>
              <div className="h-3 w-px bg-border" />
              <div>No card to start</div>
            </div>
          </div>

          <div
            className="relative animate-rise-in"
            style={{ animationDelay: '180ms' }}
          >
            <div
              aria-hidden
              className="absolute -inset-6 bg-primary/8 blur-3xl rounded-[40px] -z-10"
            />
            <div className="card p-5 sm:p-6 shadow-soft relative overflow-hidden">
              <div
                aria-hidden
                className="pointer-events-none absolute inset-0 rounded-card"
                style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }}
              />
              <div className="flex items-center justify-between mb-4">
                <div className="text-xs uppercase tracking-[0.14em] text-muted font-medium">
                  Live scan
                </div>
                <div className="font-mono text-[10px] text-muted">eucerin · gel cream</div>
              </div>

              <div className="rounded-2xl bg-bad-bg/70 border border-bad-fg/15 p-4 mb-4">
                <div className="font-display text-xl text-bad-fg leading-tight">
                  2 of your triggers found.
                </div>
                <div className="text-xs text-bad-fg/80 mt-1">
                  We'd skip this one — both ingredients showed up in your last 3 breakouts.
                </div>
              </div>

              <div className="space-y-3">
                <div>
                  <div className="text-[10px] uppercase tracking-[0.14em] font-medium text-bad-fg mb-2">
                    Watch out · 2
                  </div>
                  <div className="space-y-1.5">
                    {['Bisabolol', 'Coconut Alkanes'].map((row, i) => (
                      <div
                        key={row}
                        className="flex items-center justify-between rounded-xl bg-bad-bg/60 border border-bad-fg/15 px-3 py-2 animate-rise-in"
                        style={{ animationDelay: `${320 + i * 80}ms` }}
                      >
                        <span className="font-mono text-xs">{row}</span>
                        <span className="text-[10px] text-bad-fg/80">in 3 breakouts</span>
                      </div>
                    ))}
                  </div>
                </div>

                <div>
                  <div className="text-[10px] uppercase tracking-[0.14em] font-medium text-good-fg mb-2">
                    Good for your skin · 3
                  </div>
                  <div className="space-y-1.5">
                    {[
                      ['Niacinamide', 'barrier · brightening'],
                      ['Glycerin', 'humectant'],
                      ['Ceramide NP', 'barrier'],
                    ].map(([name, benefit], i) => (
                      <div
                        key={name}
                        className="flex items-center justify-between rounded-xl bg-good-bg/60 border border-good-fg/15 px-3 py-2 animate-rise-in"
                        style={{ animationDelay: `${500 + i * 80}ms` }}
                      >
                        <span className="font-mono text-xs">{name}</span>
                        <span className="text-[10px] text-good-fg/80">{benefit}</span>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="flex items-center justify-between pt-1 text-xs text-muted">
                  <span>+ 11 more in everything else</span>
                  <ChevronDown size={14} />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="max-w-6xl mx-auto px-6 py-16 md:py-24">
        <div className="max-w-2xl mb-14">
          <div className="text-xs uppercase tracking-[0.18em] text-muted font-medium mb-3">
            How it works
          </div>
          <h2 className="font-display text-4xl md:text-5xl leading-tight">
            Three steps. No more
            <br />
            ingredient detective work.
          </h2>
        </div>

        <div className="relative">
          <div
            aria-hidden
            className="absolute left-[10px] md:left-[14px] top-2 bottom-2 w-px bg-gradient-to-b from-border via-border to-transparent"
          />
          <ol className="space-y-12 md:space-y-16">
            {STEPS.map((s, i) => {
              const reverse = i % 2 === 1;
              return (
                <li
                  key={s.n}
                  className={`grid md:grid-cols-[28px_1fr] gap-x-6 md:gap-x-10 items-start ${
                    reverse ? 'md:[&>.detail]:order-first' : ''
                  }`}
                >
                  <div className="relative">
                    <div className="size-7 rounded-full bg-card border border-border flex items-center justify-center text-primary shadow-card">
                      {s.icon}
                    </div>
                  </div>
                  <div className={`grid md:grid-cols-2 gap-6 md:gap-10 ${reverse ? 'md:[direction:rtl]' : ''}`}>
                    <div className={reverse ? 'md:[direction:ltr]' : ''}>
                      <div className="font-mono text-[10px] text-muted tracking-[0.18em] mb-2">
                        STEP {s.n}
                      </div>
                      <h3 className="font-display text-2xl md:text-3xl mb-2 leading-tight">
                        {s.title}
                      </h3>
                      <p className="text-muted text-base leading-relaxed">{s.body}</p>
                    </div>
                    <div className={`detail ${reverse ? 'md:[direction:ltr]' : ''}`}>
                      <div className="card p-5 relative overflow-hidden">
                        <div
                          aria-hidden
                          className="pointer-events-none absolute inset-0 rounded-card"
                          style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }}
                        />
                        <div className="text-[10px] uppercase tracking-[0.14em] text-muted font-medium mb-3">
                          Example
                        </div>
                        <div className="font-mono text-xs text-ink/90 leading-relaxed">
                          {s.detail}
                        </div>
                      </div>
                    </div>
                  </div>
                </li>
              );
            })}
          </ol>
        </div>
      </section>

      <section className="max-w-6xl mx-auto px-6 py-16 md:py-24">
        <div className="grid lg:grid-cols-[1fr_1.1fr] gap-10 items-center">
          <div>
            <div className="text-xs uppercase tracking-[0.18em] text-muted font-medium mb-3">
              Pricing
            </div>
            <h2 className="font-display text-4xl md:text-5xl leading-tight mb-4">
              One plan. Less than
              <br />
              the serum you just regretted.
            </h2>
            <p className="text-muted text-lg max-w-md leading-relaxed">
              Free to log your first products. Pro unlocks unlimited routine tracking and the full
              ingredient scanner.
            </p>
          </div>

          <div className="card p-7 md:p-8 relative overflow-hidden border-primary/25">
            <div
              aria-hidden
              className="absolute -top-12 -right-12 size-44 bg-primary/8 blur-3xl rounded-full"
            />
            <div
              aria-hidden
              className="pointer-events-none absolute inset-0 rounded-card"
              style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }}
            />

            <div className="inline-flex items-center gap-2 text-xs uppercase tracking-[0.14em] text-primary bg-primary/10 px-2.5 py-1 rounded-full mb-5">
              <Sparkles size={12} /> Pro
            </div>

            <div className="flex items-baseline gap-3 mb-1">
              <div className="font-display text-5xl md:text-6xl leading-none">$9</div>
              <div className="text-muted">/ month</div>
            </div>
            <div className="text-sm text-muted mb-6">
              or $79/year — saves you two months
            </div>

            <ul className="space-y-2.5 mb-7 text-sm">
              {[
                'Unlimited product tracking',
                'Full ingredient scanner',
                'Personal trigger detection',
                'Barcode + label OCR',
                'Cancel anytime',
              ].map((f) => (
                <li key={f} className="flex items-center gap-2.5">
                  <span className="size-4 rounded-full bg-primary/10 text-primary flex items-center justify-center shrink-0">
                    <Check size={11} strokeWidth={3} />
                  </span>
                  <span>{f}</span>
                </li>
              ))}
            </ul>

            <Link
              to="/pricing"
              className="btn-primary w-full active:scale-[0.985] transition-transform duration-150 ease-emil"
            >
              See pricing <ArrowRight size={16} />
            </Link>
          </div>
        </div>
      </section>

      <section className="max-w-3xl mx-auto px-6 py-16 md:py-24">
        <div className="mb-10">
          <div className="text-xs uppercase tracking-[0.18em] text-muted font-medium mb-3">
            Questions
          </div>
          <h2 className="font-display text-4xl md:text-5xl leading-tight">Good ones, mostly.</h2>
        </div>

        <div className="divide-y divide-border border-y border-border">
          {FAQS.map((f, i) => {
            const open = openFaq === i;
            return (
              <div key={i}>
                <button
                  className="w-full py-5 flex items-start gap-4 text-left group min-h-11"
                  onClick={() => setOpenFaq(open ? null : i)}
                  aria-expanded={open}
                >
                  <span className="font-display text-lg md:text-xl flex-1 leading-snug">
                    {f.q}
                  </span>
                  <ChevronDown
                    size={20}
                    className={`text-muted shrink-0 mt-1 transition-transform duration-300 ease-emil ${
                      open ? 'rotate-180 text-primary' : 'group-hover:text-ink'
                    }`}
                  />
                </button>
                <div
                  className="grid transition-[grid-template-rows] duration-400 ease-emil"
                  style={{ gridTemplateRows: open ? '1fr' : '0fr' }}
                >
                  <div className="overflow-hidden">
                    <p className="text-muted text-base leading-relaxed pb-5 pr-8">{f.a}</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      <footer className="max-w-6xl mx-auto px-6 py-10 border-t border-border text-sm text-muted flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className="font-display text-base text-ink">
            Skintel<span className="text-primary">.</span>
          </span>
          <span>© {new Date().getFullYear()}</span>
        </div>
        <div className="flex gap-5">
          <Link to="/pricing" className="hover:text-ink transition-colors duration-200 ease-emil">
            Pricing
          </Link>
          <Link to="/login" className="hover:text-ink transition-colors duration-200 ease-emil">
            Sign in
          </Link>
        </div>
      </footer>
    </div>
  );
}
