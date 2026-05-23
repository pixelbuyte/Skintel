import { Link } from 'react-router-dom';
import { Sparkles, Camera, Calendar, Wand2, Bot, TrendingUp, Rocket, ArrowRight, Check, Clock } from 'lucide-react';

type Status = 'shipped' | 'next' | 'planned' | 'moonshot';

type Version = {
  tag: string;
  title: string;
  status: Status;
  timeframe: string;
  icon: typeof Sparkles;
  intro: string;
  trigger?: string;
  features: string[];
  example?: string;
  tech?: string;
  buildTime?: string;
  tier?: string;
  why?: string;
};

const VERSIONS: Version[] = [
  {
    tag: 'v1',
    title: 'The Foundation',
    status: 'shipped',
    timeframe: 'Live now',
    icon: Sparkles,
    intro: 'The wedge. Get to 50 paying users before touching anything below.',
    features: [
      'Log products + tag outcomes (good / bad / unsure)',
      'Correlation engine finds personal red-flag ingredients',
      'Scanner: paste any INCI → instant verdict',
      'AI ingredient analysis (Claude Haiku 4.5)',
      'URL paste, photo OCR, barcode lookup, product search',
      'Routine analyzer + AI recommendations + skin journal',
      '$9/mo Pro · $9/mo Founding (locked-for-life, 250 seats)',
    ],
  },
  {
    tag: 'v2',
    title: 'Camera Scan',
    status: 'next',
    timeframe: 'Months 1–2 post-launch',
    icon: Camera,
    intro: 'Photo of the back of a product → auto-extracts INCI + runs scanner. Mobile becomes useful.',
    trigger: '10+ users ask for it OR camera scan is #1 requested on Reddit',
    features: [
      'Snap a photo of the ingredient label',
      'OCR extracts the full INCI list',
      'Runs through her personal scanner instantly',
      'Removes the biggest friction point — no more typing',
    ],
    tech: 'Gemini 2.0 Flash OCR (~$0.00002/image, basically free). One call: "Extract the INCI ingredient list."',
    buildTime: '2–3 hours',
  },
  {
    tag: 'v3',
    title: 'Routine Scheduler & Timing',
    status: 'planned',
    timeframe: 'Months 2–4',
    icon: Calendar,
    intro: 'Tells her WHEN to use each product, not just whether it\'s safe.',
    features: [
      'Set up morning + evening routines from her actual products',
      'Smart conflict rules (Retinol + Vitamin C, AHAs + BHAs, etc)',
      'Reminders for weekly exfoliants, sunscreen, treatments',
      'Calendar view of routine over the week',
      'Layering order suggestions ("Apply this BEFORE this")',
    ],
    example: 'Adds a new BHA serum → app says "Use 2–3x per week max. Don\'t pair with retinol in the same routine. Best in PM."',
    tech: 'Static rules database for known conflicts (no AI needed). Optional web push notifications.',
    buildTime: '1 week',
  },
  {
    tag: 'v4',
    title: 'Event-Based Recommendations',
    status: 'planned',
    timeframe: 'Months 4–6',
    icon: Wand2,
    intro: 'She tells the app what\'s happening — it recommends what to use from HER OWN STASH.',
    features: [
      '"I have a wedding tomorrow" → tonight\'s prep routine from her shelf',
      '"Going to the beach" → which sunscreen to pack, what AHA to skip',
      '"Important meeting Monday" → brightening regimen using her vitamin C',
      'Recommendations only reference products she already owns',
    ],
    why: 'Most skincare advice on the internet recommends products to BUY. Skintel uniquely recommends what she ALREADY HAS. Never been done well.',
    tech: 'Claude Haiku or Gemini Flash. Input: product list + event + red-flags. Output: recipe using only owned products.',
    buildTime: '1–2 weeks',
    tier: 'Pro-only · could justify $14.99/mo "AI Stylist" tier',
  },
  {
    tag: 'v5',
    title: 'Personal AI Assistant',
    status: 'planned',
    timeframe: 'Months 6–12',
    icon: Bot,
    intro: 'Conversational interface for everything skincare.',
    features: [
      '"What should I use tonight?"',
      '"I\'m flying tomorrow — what do I pack?"',
      '"My skin feels tight, what in my stash helps?"',
      '"Should I buy this Sephora link?" → fetches ingredients + scans against profile',
      '"When did I last use my retinol?" / "What\'s my skin trend this month?"',
    ],
    tech: 'Full LLM with function calling. Access to her library, log history, red-flags, and a curated skincare knowledge base (not generic web).',
    buildTime: '3–4 weeks for polish',
    tier: 'Premium $19.99/mo · or include in Pro as retention hook',
  },
  {
    tag: 'v6',
    title: 'Trend Awareness & Smart Shopping',
    status: 'planned',
    timeframe: 'Month 12+',
    icon: TrendingUp,
    intro: 'Surface what\'s trending RIGHT NOW, filtered through her personal profile.',
    features: [
      '"Trending on TikTok Shop this week — and safe for your profile"',
      '"Sephora 20% off Sunday Riley — these 3 match your safe-ingredient list"',
      '"New K-beauty launch contains 2 of your red-flags — skip it"',
      '"Your tretinoin is running low based on usage — reorder?"',
    ],
    why: 'Endgame. She doesn\'t just track skincare — she shops through Skintel because everything is filtered through HER skin profile. Affiliate commissions from Sephora / Ulta / Amazon / TikTok Shop become meaningful revenue.',
    tech: 'TikTok Shop trending data, Sephora/Ulta affiliate APIs, price tracking, usage-based inventory.',
    buildTime: 'Ongoing, modular',
  },
  {
    tag: 'v7+',
    title: 'Long-term Moonshots',
    status: 'moonshot',
    timeframe: 'Year 2+',
    icon: Rocket,
    intro: 'Once the core platform compounds, the surface area expands.',
    features: [
      'Community red-flag database — anonymized aggregate intelligence',
      'Brand partnerships — B2B revenue from ingredient-trend data',
      'Dermatologist integration — export profile as PDF for visits',
      'Cycle-aware recs — pair with period tracking for hormonal phase',
      'iOS native app — Capacitor wrap or full native build',
    ],
  },
];

const PRINCIPLES = [
  { title: 'Always personal, never generic', body: 'Skintel\'s edge is that everything is filtered through HER data.' },
  { title: 'Stash-first, shopping-second', body: 'Use what she has, then recommend what to buy.' },
  { title: 'Every feature must compound', body: 'New features should make her existing data more valuable.' },
  { title: 'Privacy first, no exceptions', body: 'No selling user data. Post-Dobbs, women\'s wellness data is sacred.' },
  { title: 'Validate before building', body: 'Don\'t build v3 until v2 users beg for it. Don\'t build v4 until v3 has retention.' },
];

const PRICING = [
  { phase: 'v1–v2', plans: ['Free (5 products)', 'Pro $9/mo', 'Founding $9/mo · locked-for-life · 250 cap'] },
  { phase: 'v3–v4', plans: ['Free', 'Pro $9/mo', 'Stylist $14.99/mo (event-based AI recs)', 'Founding members keep $9 forever'] },
  { phase: 'v5+', plans: ['Free', 'Pro $9/mo', 'Stylist $14.99/mo', 'Premium $19.99/mo (full AI + trends)', 'Founding members keep $9 forever'] },
];

function StatusPill({ status }: { status: Status }) {
  const map: Record<Status, { label: string; cls: string; icon: typeof Check }> = {
    shipped: { label: 'Shipped', cls: 'bg-good-bg text-good-fg', icon: Check },
    next: { label: 'Next up', cls: 'bg-unsure-bg text-unsure-fg', icon: Clock },
    planned: { label: 'Planned', cls: 'bg-card text-muted border border-border', icon: Clock },
    moonshot: { label: 'Moonshot', cls: 'bg-bad-bg text-bad-fg', icon: Rocket },
  };
  const { label, cls, icon: Icon } = map[status];
  return (
    <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-mono ${cls}`}>
      <Icon size={12} /> {label}
    </span>
  );
}

export default function Roadmap() {
  return (
    <div className="min-h-screen bg-bg text-ink">
      <header className="border-b border-border">
        <div className="max-w-5xl mx-auto px-6 py-4 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2">
            <Sparkles className="text-primary" size={22} />
            <span className="font-display text-2xl">Skintel</span>
          </Link>
          <nav className="flex gap-4 text-sm">
            <Link to="/pricing" className="text-muted hover:text-ink">Pricing</Link>
            <Link to="/login" className="text-muted hover:text-ink">Sign in</Link>
          </nav>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-6 py-12">
        <section className="mb-12">
          <p className="font-mono text-xs uppercase tracking-wider text-primary mb-3">Public roadmap</p>
          <h1 className="font-display text-5xl md:text-6xl leading-tight mb-4">
            The path from wedge to platform
          </h1>
          <p className="text-lg text-muted max-w-2xl">
            Skintel starts as a personal ingredient tracker. It ends as the layer that filters every skincare decision —
            what to use tonight, what to pack, what to buy — through your own skin profile.
          </p>
        </section>

        <section className="mb-16">
          <div className="grid md:grid-cols-4 gap-3 text-sm">
            <div className="card p-3 text-center bg-good-bg text-good-fg">
              <div className="font-mono text-xs">v1</div>
              <div className="font-medium">Shipped</div>
            </div>
            <div className="card p-3 text-center bg-unsure-bg text-unsure-fg">
              <div className="font-mono text-xs">v2</div>
              <div className="font-medium">Next</div>
            </div>
            <div className="card p-3 text-center">
              <div className="font-mono text-xs">v3–v6</div>
              <div className="font-medium">Planned</div>
            </div>
            <div className="card p-3 text-center bg-bad-bg text-bad-fg">
              <div className="font-mono text-xs">v7+</div>
              <div className="font-medium">Moonshots</div>
            </div>
          </div>
        </section>

        <section className="space-y-8 mb-20">
          {VERSIONS.map((v) => {
            const Icon = v.icon;
            return (
              <article key={v.tag} className="card p-6 md:p-8">
                <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4 mb-4">
                  <div className="flex items-start gap-4">
                    <div className="w-12 h-12 rounded-xl bg-bg flex items-center justify-center shrink-0">
                      <Icon size={22} className="text-primary" />
                    </div>
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <span className="font-mono text-xs text-muted">{v.tag}</span>
                        <span className="text-muted">·</span>
                        <span className="font-mono text-xs text-muted">{v.timeframe}</span>
                      </div>
                      <h2 className="font-display text-3xl">{v.title}</h2>
                    </div>
                  </div>
                  <StatusPill status={v.status} />
                </div>

                <p className="text-base mb-4">{v.intro}</p>

                {v.trigger && (
                  <div className="rounded-lg bg-unsure-bg text-unsure-fg p-3 mb-4 text-sm">
                    <span className="font-medium">Trigger to build:</span> {v.trigger}
                  </div>
                )}

                <ul className="space-y-1.5 mb-4">
                  {v.features.map((f, i) => (
                    <li key={i} className="flex gap-2 text-sm">
                      <ArrowRight size={14} className="mt-1 shrink-0 text-primary" />
                      <span>{f}</span>
                    </li>
                  ))}
                </ul>

                {v.example && (
                  <div className="rounded-lg bg-bg p-3 mb-4 text-sm">
                    <span className="font-medium">Example:</span> <span className="italic">{v.example}</span>
                  </div>
                )}

                {v.why && (
                  <p className="text-sm text-ink/80 mb-3">
                    <span className="font-medium">Why it matters:</span> {v.why}
                  </p>
                )}

                <div className="flex flex-wrap gap-x-6 gap-y-1 text-xs font-mono text-muted">
                  {v.tech && <div><span className="text-ink/60">Tech:</span> {v.tech}</div>}
                  {v.buildTime && <div><span className="text-ink/60">Build:</span> {v.buildTime}</div>}
                  {v.tier && <div><span className="text-ink/60">Pricing:</span> {v.tier}</div>}
                </div>
              </article>
            );
          })}
        </section>

        <section className="mb-20">
          <h2 className="font-display text-4xl mb-6">Pricing evolution</h2>
          <div className="space-y-3">
            {PRICING.map((p) => (
              <div key={p.phase} className="card p-5 flex flex-col md:flex-row gap-4">
                <div className="md:w-24 shrink-0">
                  <div className="font-mono text-xs text-muted">PHASE</div>
                  <div className="font-display text-2xl">{p.phase}</div>
                </div>
                <ul className="flex-1 space-y-1 text-sm">
                  {p.plans.map((plan, i) => (
                    <li key={i} className="flex gap-2">
                      <Check size={14} className="mt-1 shrink-0 text-good-fg" />
                      <span>{plan}</span>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
          <p className="text-sm text-muted mt-4 italic">
            Founding members always honored — lifetime $9/mo, no exceptions, no migrations.
          </p>
        </section>

        <section className="mb-20">
          <h2 className="font-display text-4xl mb-6">Guiding principles</h2>
          <div className="grid md:grid-cols-2 gap-4">
            {PRINCIPLES.map((p) => (
              <div key={p.title} className="card p-5">
                <div className="font-display text-xl mb-1">{p.title}</div>
                <p className="text-sm text-muted">{p.body}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="card p-8 text-center bg-card">
          <h2 className="font-display text-3xl mb-2">Want a say in what ships next?</h2>
          <p className="text-muted mb-6">
            Founding members get direct input on the v2 + v3 roadmap. 250 seats, locked-in-for-life pricing.
          </p>
          <div className="flex justify-center gap-3">
            <Link to="/pricing" className="btn-primary">See pricing</Link>
            <Link to="/" className="btn-secondary">Back home</Link>
          </div>
        </section>
      </main>

      <footer className="border-t border-border mt-16">
        <div className="max-w-5xl mx-auto px-6 py-6 text-xs text-muted flex items-center justify-between">
          <span>© Skintel</span>
          <span className="font-mono">Last updated 2026-05-22</span>
        </div>
      </footer>
    </div>
  );
}
