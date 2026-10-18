import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { track } from '@vercel/analytics';

/**
 * Minimal waitlist landing at "/". Traffic mostly arrives from short-video comment
 * replies on phones, so the signup sits in the first screen and a sticky bar brings it
 * back once it scrolls away. The bar pins to the top: Safari's floating address bar and
 * the TikTok/Instagram in-app browsers all put chrome at the bottom, which covered it. The previous long landing lives at /classic.
 *
 * Attribution: ?ref=<tag> (or ?s=<tag>) is kept in localStorage (same key the old page
 * used) and sent as the waitlist `source`, so each video's link can be compared.
 */

const REF_KEY = 'skintel_ref';

function readRef(): string | null {
  try {
    const q = new URLSearchParams(window.location.search);
    const fromUrl = q.get('ref') ?? q.get('s');
    if (fromUrl) localStorage.setItem(REF_KEY, fromUrl.slice(0, 40));
    return fromUrl ?? localStorage.getItem(REF_KEY);
  } catch {
    return null;
  }
}

function WaitlistForm({ joined, onJoined, center }: { joined: boolean; onJoined: () => void; center?: boolean }) {
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    const clean = email.trim();
    if (!clean) return;
    setBusy(true);
    setErr(null);
    try {
      const ref = readRef();
      // Never include 'founding-3mo': the waitlist email keys off it.
      const source = ref ? `home:waitlist:${ref}` : 'home:waitlist';
      const res = await fetch('/api/waitlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: clean, source }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.error === 'Invalid email' ? 'That email doesn’t look right.' : 'Something went wrong. Try again.');
      track('waitlist_join', { ref: ref ?? 'direct' });
      onJoined();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Something went wrong. Try again.');
    } finally {
      setBusy(false);
    }
  }

  if (joined) {
    return (
      <div className={`mt-6 max-w-[460px] rounded-[20px] border border-[#E6DED2] bg-[#FFFEFA] px-5 py-4 text-left ${center ? 'mx-auto' : ''}`}>
        <p className="font-display text-[26px] leading-tight">You’re on the list.</p>
        <p className="text-[15px] text-[#6B6760]">We’ll email you the day Skintel launches.</p>
      </div>
    );
  }

  return (
    <>
      <form
        onSubmit={submit}
        className={`mt-6 flex max-w-[460px] gap-2 rounded-full border border-[#E6DED2] bg-[#FFFEFA] p-1.5 shadow-[0_10px_30px_rgba(70,42,28,0.06)] ${center ? 'mx-auto' : ''}`}
      >
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="Your email"
          autoComplete="email"
          aria-label="Email"
          className="min-w-0 flex-1 bg-transparent px-3.5 text-base text-ink outline-none placeholder:text-[#9A8D80]"
        />
        <button
          disabled={busy}
          className="whitespace-nowrap rounded-full bg-[#A35848] px-5 py-3 text-[15px] font-semibold text-[#FFFEFA] transition-transform duration-200 ease-ios active:scale-[0.97] disabled:opacity-70"
        >
          {busy ? 'Joining…' : 'Join the waitlist'}
        </button>
      </form>
      <p className={`mt-3 text-[13px] ${err ? 'text-[#A35848]' : 'text-[#8A7A6C]'}`}>
        {err ?? 'Free. One email on launch day, nothing else.'}
      </p>
    </>
  );
}

const STEPS = [
  { icon: '/email/scan.png', title: 'Scan', text: 'Any bottle, any barcode.' },
  { icon: '/email/log.png', title: 'Log', text: 'Ten seconds a day.' },
  { icon: '/email/find.png', title: 'Know why', text: 'See your trigger ingredient.' },
];

export default function Home() {
  const [joined, setJoined] = useState(false);
  const [showBar, setShowBar] = useState(false);
  const heroForm = useRef<HTMLDivElement>(null);

  useEffect(() => {
    readRef();
    const el = heroForm.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => setShowBar(!e.isIntersecting && e.boundingClientRect.top < 0));
    io.observe(el);
    return () => io.disconnect();
  }, []);

  function jumpToForm() {
    window.scrollTo({ top: 0, behavior: 'smooth' });
    setTimeout(() => heroForm.current?.querySelector('input')?.focus(), 400);
  }

  return (
    <div className="min-h-[100dvh] overflow-x-hidden bg-[#F4EDE0] font-sans text-ink antialiased">
      <div className="mx-auto max-w-[1120px] px-5">
        <nav className="flex h-16 items-center justify-between">
          <Link to="/" className="font-display text-[28px] tracking-tight">Skintel</Link>
          <button onClick={jumpToForm} className="rounded-full border border-[#E6DED2] bg-[#FFFEFA] px-4 py-2 text-sm">
            Join waitlist
          </button>
        </nav>

        <section className="grid gap-2 pt-7 md:min-h-[calc(100vh-4rem)] md:grid-cols-[1.05fr_0.95fr] md:items-center md:pt-10">
          <div className="min-w-0" ref={heroForm}>
            <p className="font-mono text-[11px] tracking-[0.22em] text-[#A35848]">COMING SOON TO IPHONE</p>
            <h1 className="mt-3.5 font-display text-[clamp(44px,11vw,84px)] font-normal leading-[0.98] tracking-[-0.015em]">
              Find the ingredient <em className="font-display italic text-[#A35848]">breaking you out.</em>
            </h1>
            <p className="mt-4 max-w-[460px] text-lg leading-relaxed text-[#6B6760]">
              Scan your products, log your skin, and Skintel shows you what your bad days have in common.
            </p>
            <WaitlistForm joined={joined} onJoined={() => setJoined(true)} />
          </div>
          <div className="mx-auto mt-9 w-[min(78vw,330px)] md:ml-auto md:mr-0 md:mt-0 md:w-[360px]">
            <img
              src="/landing/phone-triggers.webp"
              alt="Skintel Triggers screen showing fragrance in 3 of 4 bad-skin days"
              width={629}
              height={1317}
              className="block w-full drop-shadow-[0_40px_50px_rgba(70,42,28,0.25)]"
            />
          </div>
        </section>

        <section className="pb-2 pt-14">
          <h2 className="font-display text-[clamp(34px,8vw,52px)] font-normal leading-[1.02] tracking-[-0.01em]">
            Three steps to<br />clearer answers.
          </h2>
          <div className="mt-6 grid gap-3 md:grid-cols-3">
            {STEPS.map((s) => (
              <div key={s.title} className="flex items-center gap-4 rounded-[20px] border border-[#E6DED2] bg-[#FFFEFA] p-4 md:flex-col md:items-start md:p-6">
                <img src={s.icon} alt="" width={44} height={44} />
                <div>
                  <p className="text-[17px] font-semibold">{s.title}</p>
                  <p className="text-[15px] text-[#6B6760]">{s.text}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="py-16 text-center md:py-20">
          <h2 className="font-display text-[clamp(34px,8vw,52px)] font-normal leading-[1.02] tracking-[-0.01em]">
            Be first when<br />it launches.
          </h2>
          <WaitlistForm joined={joined} onJoined={() => setJoined(true)} center />
        </section>

        <footer className="flex flex-wrap gap-5 border-t border-[#E6DED2] pb-[calc(env(safe-area-inset-bottom)+32px)] pt-6 text-[13px] text-[#8A7A6C]">
          <span>© Skintel</span>
          <Link to="/privacy">Privacy</Link>
          <Link to="/terms">Terms</Link>
          <a href="mailto:hello@skinstel.com">hello@skinstel.com</a>
        </footer>
      </div>

      {!joined && (
        <div
          className={`fixed left-3 right-3 top-[calc(env(safe-area-inset-top)+10px)] z-10 flex items-center justify-between gap-2.5 rounded-full bg-[rgba(26,24,20,0.92)] py-2 pl-5 pr-2 text-[#FFFEFA] backdrop-blur-md transition-transform duration-500 ease-ios md:left-auto md:right-6 md:w-auto ${
            showBar ? 'translate-y-0 shadow-[0_10px_30px_rgba(26,24,20,0.18)]' : '-translate-y-[calc(100%+env(safe-area-inset-top)+40px)] shadow-none'
          }`}
          aria-hidden={!showBar}
        >
          <span className="text-sm">Skintel is <span className="text-[#E7B8A6]">coming soon</span></span>
          <button onClick={jumpToForm} tabIndex={showBar ? 0 : -1} className="rounded-full bg-[#A35848] px-[18px] py-[11px] text-sm font-semibold">
            Join waitlist
          </button>
        </div>
      )}
    </div>
  );
}
