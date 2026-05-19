import { Link } from 'react-router-dom';
import { useState } from 'react';
import { Sparkles, FlaskConical, ScanLine, ArrowRight, ChevronDown } from 'lucide-react';
import { useFoundingCount } from '@/hooks/useFoundingCount';

const FAQS = [
  {
    q: 'How does Skintel know what breaks me out?',
    a: "You tag products as 'worked' or 'broke me out' and paste their INCI lists. We cross-reference the ingredients to find what only shows up in your breakouts.",
  },
  {
    q: 'Is my data private?',
    a: 'Yes — every row is locked to your account via Postgres row-level security. You can export everything as JSON or delete your account at any time.',
  },
  {
    q: 'What is the Founding plan?',
    a: 'First 250 subscribers pay $9/month and stay at $9/month forever. Same features as Pro — different price guarantee.',
  },
  {
    q: 'Do I need to scan a barcode?',
    a: 'No. Just paste the ingredient list from any product page. Skintel normalizes the names automatically.',
  },
];

export default function Landing() {
  const { remaining } = useFoundingCount();
  const [openFaq, setOpenFaq] = useState<number | null>(0);

  return (
    <div className="min-h-screen">
      <header className="max-w-6xl mx-auto px-6 py-6 flex items-center justify-between">
        <Link to="/" className="font-display text-2xl">Skintel</Link>
        <nav className="flex items-center gap-4 text-sm">
          <Link to="/pricing" className="text-muted hover:text-ink">Pricing</Link>
          <Link to="/login" className="btn-primary">Get started</Link>
        </nav>
      </header>

      <section className="max-w-4xl mx-auto px-6 pt-16 pb-20 text-center">
        <div className="inline-flex items-center gap-2 text-xs uppercase tracking-wider text-primary bg-primary/10 px-3 py-1 rounded-full mb-6">
          <Sparkles size={14} /> Personal ingredient intelligence
        </div>
        <h1 className="font-display text-6xl md:text-7xl leading-[1.05] mb-6">
          Stop guessing why<br />your skin broke out.
        </h1>
        <p className="text-lg text-muted max-w-2xl mx-auto mb-8">
          Log the products in your routine, tag what works, and Skintel surfaces the exact
          ingredients showing up in your breakouts — so you can avoid them next time.
        </p>
        <div className="flex items-center justify-center gap-3 flex-wrap">
          <Link to="/login" className="btn-primary">
            Start tracking free <ArrowRight size={16} />
          </Link>
          <Link to="/pricing" className="btn-secondary">See pricing</Link>
        </div>
      </section>

      <section className="max-w-6xl mx-auto px-6 py-16">
        <h2 className="font-display text-4xl text-center mb-12">How it works</h2>
        <div className="grid md:grid-cols-3 gap-6">
          {[
            { icon: <FlaskConical size={28} />, title: 'Log your routine', body: "Add the products you're using. Paste the ingredient list, tag the outcome." },
            { icon: <Sparkles size={28} />, title: 'See the pattern', body: 'Skintel surfaces ingredients that appear across your breakout products but not your safe ones.' },
            { icon: <ScanLine size={28} />, title: 'Scan before you buy', body: 'Paste any new product\'s INCI list to instantly check if it contains your triggers.' },
          ].map((s, i) => (
            <div key={i} className="card p-6">
              <div className="text-primary mb-3">{s.icon}</div>
              <h3 className="font-display text-2xl mb-2">{s.title}</h3>
              <p className="text-muted text-sm">{s.body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="max-w-3xl mx-auto px-6 py-16">
        <div className="card p-8 text-center border-primary/30">
          <div className="inline-flex items-center gap-2 text-xs uppercase tracking-wider text-primary mb-3">
            <Sparkles size={14} /> Founding members
          </div>
          <h2 className="font-display text-4xl mb-3">$9/month. Locked for life.</h2>
          <p className="text-muted mb-6">
            First 250 subscribers stay at $9/month forever. Same features as Pro — different
            guarantee.
          </p>
          <div className="text-5xl font-display mb-2">{remaining ?? '—'}</div>
          <div className="text-muted text-sm mb-6">seats remaining of 250</div>
          <Link to="/pricing" className="btn-primary">Claim a seat</Link>
        </div>
      </section>

      <section className="max-w-3xl mx-auto px-6 py-16">
        <h2 className="font-display text-4xl text-center mb-8">Questions</h2>
        <div className="space-y-2">
          {FAQS.map((f, i) => (
            <div key={i} className="card overflow-hidden">
              <button
                className="w-full px-5 py-4 flex items-center justify-between text-left"
                onClick={() => setOpenFaq(openFaq === i ? null : i)}
              >
                <span className="font-medium">{f.q}</span>
                <ChevronDown
                  size={18}
                  className={`text-muted transition ${openFaq === i ? 'rotate-180' : ''}`}
                />
              </button>
              {openFaq === i && (
                <div className="px-5 pb-4 text-muted text-sm">{f.a}</div>
              )}
            </div>
          ))}
        </div>
      </section>

      <footer className="max-w-6xl mx-auto px-6 py-8 border-t border-border text-sm text-muted flex items-center justify-between">
        <div>© {new Date().getFullYear()} Skintel</div>
        <div className="flex gap-4">
          <Link to="/pricing" className="hover:text-ink">Pricing</Link>
          <Link to="/login" className="hover:text-ink">Sign in</Link>
        </div>
      </footer>
    </div>
  );
}
