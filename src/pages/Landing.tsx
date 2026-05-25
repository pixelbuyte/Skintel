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
import { TryItDemo } from '@/components/TryItDemo';
import { useInView } from '@/lib/useInView';
import { useFoundingCount } from '@/hooks/useFoundingCount';

const FAQS = [
  {
    q: 'How does Skintel know what breaks me out?',
    a: "Tag each product 'worked' or 'broke me out' and paste its INCI list. We cross-reference ingredients to surface what only shows up in your breakouts. Patterns sharpen as you log more.",
  },
  {
    q: 'How many products do I need to log before it works?',
    a: 'Three to five is the sweet spot. You need at least two breakout products before Skintel can find common threads. The more honest tags you add, the cleaner the signal.',
  },
  {
    q: 'Do I need to scan a barcode or take photos?',
    a: 'No. Paste the ingredient list from any product page — Sephora, Ulta, the brand site, the back of the bottle. Skintel normalizes the names automatically. Barcode and label OCR are inside the Pro scanner if you want them.',
  },
  {
    q: 'Is this medical advice?',
    a: "No. Skintel surfaces correlations from products you tag — it's a tracking tool, not a diagnosis. For persistent or severe reactions, see a dermatologist.",
  },
  {
    q: 'Is my data private?',
    a: 'Every row is locked to your account via Postgres row-level security. We never sell your data or share it with brands. Export everything as JSON or wipe your account anytime from Settings.',
  },
  {
    q: 'Monthly or yearly?',
    a: 'Pro is $9 a month, or $79 a year. The yearly plan saves you two months. Cancel anytime in either — access continues through the current period.',
  },
];

const STEPS = [
  {
    n: '01',
    icon: <FlaskConical size={20} />,
    title: 'Log your routine',
    body: "Add the 3-5 products you're actually using. Paste the ingredient list, and Skintel parses the INCI so you don't have to.",
    detail: ['brand', 'product', 'outcome'],
  },
  {
    n: '02',
    icon: <Sparkles size={20} />,
    title: 'See the pattern',
    body: 'Skintel surfaces the ingredients showing up in your breakout products that never appear in your safe ones.',
    detail: ['bisabolol', 'coconut alkanes', 'linalool'],
  },
  {
    n: '03',
    icon: <ScanLine size={20} />,
    title: 'Check before you buy',
    body: 'Paste any INCI list — from a Sephora page, the back of a bottle, anywhere. Skintel checks every ingredient against your personal trigger map in seconds.',
    detail: ['watch out', 'good for you', 'everything else'],
  },
];

const MARQUEE = [
  { name: 'niacinamide', tone: 'good' },
  { name: 'bisabolol', tone: 'bad' },
  { name: 'glycerin', tone: 'good' },
  { name: 'fragrance', tone: 'bad' },
  { name: 'ceramide NP', tone: 'good' },
  { name: 'linalool', tone: 'bad' },
  { name: 'panthenol', tone: 'good' },
  { name: 'coconut alkanes', tone: 'bad' },
  { name: 'centella asiatica', tone: 'good' },
  { name: 'limonene', tone: 'bad' },
  { name: 'squalane', tone: 'good' },
  { name: 'sodium hyaluronate', tone: 'good' },
] as const;

const PRICING = [
  {
    id: 'free',
    name: 'Free',
    price: '$0',
    cadence: 'forever',
    blurb: 'Log your first products and see the basics.',
    features: ['Up to 5 products', 'Personal trigger detection', 'Manual INCI paste', 'Export your data'],
    cta: 'Start free',
    href: '/login',
    highlight: false,
  },
  {
    id: 'pro-monthly',
    name: 'Pro Monthly',
    price: '$9',
    cadence: '/ month',
    blurb: 'The full scanner. Cancel anytime.',
    features: [
      'Unlimited products',
      'Ingredient scanner',
      'Barcode + label OCR',
      'Routine + journal',
      'Cancel anytime',
    ],
    cta: 'Go Pro monthly',
    href: '/pricing#pro-monthly',
    highlight: true,
  },
  {
    id: 'pro-yearly',
    name: 'Pro Yearly',
    price: '$79',
    cadence: '/ year',
    blurb: 'Same as Pro. Two months off.',
    features: [
      'Everything in Pro',
      'Save $29 vs monthly',
      'Two months free',
      'Priority email support',
    ],
    cta: 'Go Pro yearly',
    href: '/pricing#pro-yearly',
    highlight: false,
  },
] as const;

function FadeUp({ children, delay = 0 }: { children: React.ReactNode; delay?: number }) {
  const { ref, inView } = useInView<HTMLDivElement>({ threshold: 0.12 });
  return (
    <div
      ref={ref}
      className={`fade-up${inView ? ' in-view' : ''}`}
      style={{ transitionDelay: inView ? `${delay}ms` : '0ms' }}
    >
      {children}
    </div>
  );
}

function ComingSoonWaitlist() {
  const { remaining, total } = useFoundingCount();
  const [email, setEmail] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [joined, setJoined] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    const clean = email.trim().toLowerCase();
    if (!clean) return;
    setSubmitting(true);
    try {
      const res = await fetch('/api/waitlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: clean, source: 'landing' }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.error ?? 'Signup failed');
      setJoined(true);
    } catch (e: any) {
      setErr(e?.message ?? 'Something went wrong');
    } finally {
      setSubmitting(false);
    }
  }

  const seatsLine =
    typeof remaining === 'number'
      ? `${remaining} of ${total} founding spots left.`
      : `${total} founding spots total.`;

  return (
    <div className="card p-7 md:p-10 relative overflow-hidden">
      <div
        aria-hidden
        className="absolute -top-24 -right-24 size-72 bg-primary/10 blur-3xl rounded-full"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 rounded-card"
        style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }}
      />
      <div className="relative">
        <div className="inline-flex items-center gap-2 text-xs uppercase tracking-[0.14em] text-primary bg-primary/8 border border-primary/15 px-3 py-1.5 rounded-full mb-5">
          <Sparkles size={12} /> Coming June 2026
        </div>
        <h2 className="font-display text-4xl md:text-5xl leading-tight mb-4">
          The app is coming.
        </h2>
        <p className="text-muted text-lg max-w-[58ch] leading-relaxed mb-6">
          Skintel for iOS launches June 2026. Join the waitlist and be first to know —
          or lock in lifetime access for $5 before it's gone forever.
        </p>

        <div className="text-sm text-primary font-medium mb-6">{seatsLine}</div>

        {!joined ? (
          <form onSubmit={submit} className="flex flex-col sm:flex-row gap-3 mb-4 max-w-xl">
            <input
              type="email"
              required
              autoComplete="email"
              placeholder="you@example.com"
              className="input flex-1"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              disabled={submitting}
            />
            <button
              type="submit"
              disabled={submitting}
              className="btn-secondary active:scale-[0.97] transition-transform duration-150 ease-emil whitespace-nowrap"
            >
              {submitting ? 'Joining…' : 'Join waitlist'}
            </button>
          </form>
        ) : (
          <div className="card p-5 mb-4 border-good-fg/30 bg-good-bg/40">
            <div className="font-display text-lg text-good-fg mb-1">You're on the list!</div>
            <div className="text-sm text-good-fg/90">
              Want lifetime access before the price goes up?
            </div>
          </div>
        )}

        {err && (
          <div className="text-sm text-bad-fg mb-3" role="alert">
            {err}
          </div>
        )}

        <div className="flex items-center gap-3 flex-wrap">
          <Link
            to="/pricing#founding"
            className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
          >
            Get lifetime access — $5 <ArrowRight size={14} />
          </Link>
          <span className="text-xs text-muted">One-time. Forever. No subscription.</span>
        </div>
      </div>
    </div>
  );
}

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
    <div className="min-h-[100dvh] bg-bg text-ink overflow-x-hidden relative">
      <div aria-hidden className="pointer-events-none fixed inset-0 bg-grain opacity-[0.03] mix-blend-multiply z-0" />

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
          <div className="animate-rise-in" style={{ animationDelay: '40ms' }}>
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
              your skin <span className="italic text-primary">broke out.</span>
            </h1>

            <p className="text-lg text-muted max-w-[60ch] mb-8 leading-relaxed">
              Log the 3-5 products in your current routine. Tag what works. Skintel surfaces the
              exact ingredients showing up across your breakouts, so you can skip them next time.
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

            <div className="mt-10 flex items-center gap-5 text-xs text-muted flex-wrap">
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

          <div className="relative animate-rise-in" style={{ animationDelay: '180ms' }}>
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
                  Skip this one. Both ingredients showed up in your last 3 breakouts.
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

      <section className="max-w-3xl mx-auto px-6 pb-16 md:pb-24">
        <FadeUp>
          <TryItDemo />
        </FadeUp>
      </section>

      <section
        aria-label="Ingredients ticker"
        className="border-y border-border bg-card/40 overflow-hidden"
      >
        <div className="relative py-5 group">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-y-0 left-0 w-24 bg-gradient-to-r from-bg to-transparent z-10"
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-y-0 right-0 w-24 bg-gradient-to-l from-bg to-transparent z-10"
          />
          <div className="flex gap-3 whitespace-nowrap will-change-transform animate-marquee group-hover:[animation-play-state:paused]">
            {[...MARQUEE, ...MARQUEE, ...MARQUEE].map((m, i) => (
              <span
                key={i}
                className={`font-mono text-xs px-3 py-1 rounded-full border ${
                  m.tone === 'good'
                    ? 'bg-good-bg/40 border-good-fg/15 text-good-fg/90'
                    : 'bg-bad-bg/40 border-bad-fg/15 text-bad-fg/90'
                }`}
              >
                {m.name}
              </span>
            ))}
          </div>
        </div>
      </section>

      <section className="max-w-6xl mx-auto px-6 py-16 md:py-24">
        <FadeUp>
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
        </FadeUp>

        <ol className="space-y-14 md:space-y-20">
          {STEPS.map((s, i) => (
            <FadeUp key={s.n} delay={i * 60}>
              <li className="grid md:grid-cols-[120px_1fr_minmax(0,360px)] gap-x-10 gap-y-6 items-start">
                <div className="flex items-baseline gap-3 md:block">
                  <div className="font-display text-5xl md:text-6xl text-primary/30 leading-none">
                    {s.n}
                  </div>
                  <div className="text-primary/80 md:mt-2">{s.icon}</div>
                </div>

                <div className="max-w-[55ch]">
                  <h3 className="font-display text-2xl md:text-3xl mb-3 leading-tight">
                    {s.title}
                  </h3>
                  <p className="text-muted text-base leading-relaxed">{s.body}</p>
                </div>

                <div className="md:pt-2">
                  <ul className="space-y-1.5">
                    {s.detail.map((d) => (
                      <li
                        key={d}
                        className="flex items-center gap-2.5 font-mono text-xs text-ink/70"
                      >
                        <span className="size-1 rounded-full bg-primary/60" />
                        {d}
                      </li>
                    ))}
                  </ul>
                </div>
              </li>
            </FadeUp>
          ))}
        </ol>
      </section>

      <section className="max-w-4xl mx-auto px-6 py-16 md:py-20">
        <FadeUp>
          <ComingSoonWaitlist />
        </FadeUp>
      </section>

      <section className="max-w-6xl mx-auto px-6 py-16 md:py-24">
        <FadeUp>
          <div className="max-w-2xl mb-12">
            <div className="text-xs uppercase tracking-[0.18em] text-muted font-medium mb-3">
              Pricing
            </div>
            <h2 className="font-display text-4xl md:text-5xl leading-tight mb-4">
              One plan. Less than
              <br />
              the serum you just regretted.
            </h2>
            <p className="text-muted text-lg max-w-[52ch] leading-relaxed">
              Start free, upgrade when you want the full scanner. No annual lock-in.
            </p>
          </div>
        </FadeUp>

        <div className="grid md:grid-cols-3 gap-5">
          {PRICING.map((p, i) => (
            <FadeUp key={p.id} delay={i * 80}>
              <div
                className={`card p-7 h-full relative overflow-hidden flex flex-col ${
                  p.highlight ? 'border-primary/30 shadow-soft' : ''
                }`}
              >
                {p.highlight && (
                  <div
                    aria-hidden
                    className="absolute -top-12 -right-12 size-44 bg-primary/8 blur-3xl rounded-full"
                  />
                )}
                <div
                  aria-hidden
                  className="pointer-events-none absolute inset-0 rounded-card"
                  style={{ boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7)' }}
                />
                <div className="relative flex-1">
                  {p.highlight && (
                    <div className="inline-flex items-center gap-1.5 text-[10px] uppercase tracking-[0.14em] text-primary bg-primary/10 px-2.5 py-1 rounded-full mb-4 font-medium">
                      <Sparkles size={10} /> Most popular
                    </div>
                  )}
                  <div className="text-sm text-muted mb-1">{p.name}</div>
                  <div className="flex items-baseline gap-2 mb-1">
                    <div className="font-display text-5xl leading-none">{p.price}</div>
                    <div className="text-muted text-sm">{p.cadence}</div>
                  </div>
                  <p className="text-sm text-muted mb-6 mt-2">{p.blurb}</p>

                  <ul className="space-y-2 mb-6 text-sm">
                    {p.features.map((f) => (
                      <li key={f} className="flex items-start gap-2.5">
                        <span className="size-4 mt-0.5 rounded-full bg-primary/10 text-primary flex items-center justify-center shrink-0">
                          <Check size={11} strokeWidth={3} />
                        </span>
                        <span>{f}</span>
                      </li>
                    ))}
                  </ul>
                </div>

                <Link
                  to={p.href}
                  className={`${
                    p.highlight ? 'btn-primary' : 'btn-secondary'
                  } w-full active:scale-[0.985] transition-transform duration-150 ease-emil relative`}
                >
                  {p.cta} <ArrowRight size={14} />
                </Link>
              </div>
            </FadeUp>
          ))}
        </div>
      </section>

      <section className="max-w-3xl mx-auto px-6 py-16 md:py-24">
        <FadeUp>
          <div className="mb-10">
            <div className="text-xs uppercase tracking-[0.18em] text-muted font-medium mb-3">
              Questions
            </div>
            <h2 className="font-display text-4xl md:text-5xl leading-tight">Good ones, mostly.</h2>
          </div>
        </FadeUp>

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

      <footer className="max-w-6xl mx-auto px-6 py-12 border-t border-border text-sm text-muted relative">
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-8 mb-10">
          <div className="sm:col-span-2 md:col-span-1">
            <Link to="/" className="font-display text-2xl text-ink leading-none">
              Skintel<span className="text-primary">.</span>
            </Link>
            <p className="text-muted text-sm mt-3 max-w-[28ch] leading-relaxed">
              Personal ingredient intelligence. Built for people whose skin keeps secrets.
            </p>
          </div>
          <div>
            <div className="text-ink font-medium mb-3">Product</div>
            <ul className="space-y-2">
              <li>
                <Link to="/pricing" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Pricing
                </Link>
              </li>
              <li>
                <Link to="/roadmap" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Roadmap
                </Link>
              </li>
              <li>
                <Link to="/login" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Sign in
                </Link>
              </li>
            </ul>
          </div>
          <div>
            <div className="text-ink font-medium mb-3">Company</div>
            <ul className="space-y-2">
              <li>
                <Link to="/about" className="hover:text-ink transition-colors duration-200 ease-emil">
                  About
                </Link>
              </li>
              <li>
                <Link to="/contact" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Contact
                </Link>
              </li>
            </ul>
          </div>
          <div>
            <div className="text-ink font-medium mb-3">Legal</div>
            <ul className="space-y-2">
              <li>
                <Link to="/privacy" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Privacy
                </Link>
              </li>
              <li>
                <Link to="/terms" className="hover:text-ink transition-colors duration-200 ease-emil">
                  Terms
                </Link>
              </li>
            </ul>
          </div>
        </div>
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 pt-6 border-t border-border">
          <span>© {new Date().getFullYear()} Skintel. All rights reserved.</span>
          <span className="text-xs">Not medical advice. Patterns, not prescriptions.</span>
        </div>
      </footer>
    </div>
  );
}
