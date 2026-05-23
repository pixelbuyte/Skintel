import { Link } from 'react-router-dom';
import { useEffect, useState, type ReactNode } from 'react';
import { ArrowRight } from 'lucide-react';

export function PublicPage({
  eyebrow,
  title,
  children,
}: {
  eyebrow: string;
  title: string;
  children: ReactNode;
}) {
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

      <main className="max-w-3xl mx-auto px-6 pt-12 md:pt-20 pb-20">
        <div className="text-xs uppercase tracking-[0.18em] text-muted font-medium mb-3">
          {eyebrow}
        </div>
        <h1 className="font-display text-4xl md:text-5xl leading-tight mb-10">{title}</h1>
        <div className="prose-skintel space-y-5 text-base text-ink/85 leading-relaxed max-w-[68ch]">
          {children}
        </div>
      </main>

      <footer className="max-w-6xl mx-auto px-6 py-12 border-t border-border text-sm text-muted">
        <div className="grid sm:grid-cols-3 gap-8 mb-8">
          <div>
            <div className="text-ink font-medium mb-3">Product</div>
            <ul className="space-y-2">
              <li><Link to="/pricing" className="hover:text-ink transition-colors duration-200 ease-emil">Pricing</Link></li>
              <li><Link to="/roadmap" className="hover:text-ink transition-colors duration-200 ease-emil">Roadmap</Link></li>
              <li><Link to="/login" className="hover:text-ink transition-colors duration-200 ease-emil">Sign in</Link></li>
            </ul>
          </div>
          <div>
            <div className="text-ink font-medium mb-3">Company</div>
            <ul className="space-y-2">
              <li><Link to="/about" className="hover:text-ink transition-colors duration-200 ease-emil">About</Link></li>
              <li><Link to="/contact" className="hover:text-ink transition-colors duration-200 ease-emil">Contact</Link></li>
            </ul>
          </div>
          <div>
            <div className="text-ink font-medium mb-3">Legal</div>
            <ul className="space-y-2">
              <li><Link to="/privacy" className="hover:text-ink transition-colors duration-200 ease-emil">Privacy</Link></li>
              <li><Link to="/terms" className="hover:text-ink transition-colors duration-200 ease-emil">Terms</Link></li>
            </ul>
          </div>
        </div>
        <div className="flex items-center justify-between pt-6 border-t border-border">
          <span className="font-display text-base text-ink">
            Skintel<span className="text-primary">.</span>
          </span>
          <span>© {new Date().getFullYear()}</span>
        </div>
      </footer>
    </div>
  );
}
