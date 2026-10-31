import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { track } from '@vercel/analytics';

/**
 * Minimal landing at "/". Skintel is live on the App Store, so the page has two jobs: get
 * the app, and sell the web launch offer (Skintel+ at $6.49/month for the first three
 * months, then $8.99). Traffic mostly arrives from short-video comment replies on phones,
 * so both sit on the first screen, and a bar pinned to the top (Safari and in-app browsers
 * put their chrome at the bottom) is there from the first paint until the offer card shows.
 * The previous long landing lives at /classic.
 *
 * Attribution: ?ref=<tag> (or ?s=<tag>) is kept in localStorage and sent with checkout.
 * Checkout is guest-only: Stripe is opened with the email typed here (read-only there),
 * and the webhook puts Skintel+ on the Skintel account with that email.
 */

const REF_KEY = 'skintel_ref';
const APP_STORE_URL = 'https://apps.apple.com/us/app/skinstel-scan-track-clear/id6812903021';

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

function AppStoreButton({ dark = true }: { dark?: boolean }) {
  return (
    <a
      href={APP_STORE_URL}
      onClick={() => track('app_store_click', { ref: readRef() ?? 'direct' })}
      className={`inline-flex items-center gap-2.5 rounded-full px-5 py-3 text-[15px] font-semibold transition-transform duration-200 ease-ios active:scale-[0.97] ${
        dark ? 'bg-ink text-[#FFFEFA]' : 'border border-[#E6DED2] bg-[#FFFEFA] text-ink'
      }`}
    >
      <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
        <path d="M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.8-3.5.8s-1.8-.8-3-.8C7 7.3 5.6 8.2 4.8 9.6c-1.6 2.8-.4 6.9 1.1 9.2.8 1.1 1.7 2.3 2.8 2.3s1.6-.7 2.9-.7 1.7.7 2.9.7 1.9-1.1 2.6-2.2c.8-1.2 1.2-2.4 1.2-2.5-.1 0-2.4-.9-2.4-3.8zM14.2 5.6c.6-.8 1.1-1.8.9-2.8-.9 0-2 .6-2.6 1.4-.6.6-1.1 1.7-.9 2.7 1 .1 2-.5 2.6-1.3z" />
      </svg>
      Download on the App Store
    </a>
  );
}

/** A bottle under a scan beam; the verdict pops in each pass. CSS only, honours reduced motion. */
function ScanDemo() {
  return (
    <div className="relative mx-auto w-full max-w-[300px] overflow-hidden rounded-[28px] border border-[#E6DED2] bg-[#EFE5D8] p-5">
      <style>{`
        @keyframes sk-beam{0%,100%{transform:translateY(-70px)}50%{transform:translateY(70px)}}
        @keyframes sk-pop{0%,45%{opacity:0;transform:translateY(8px) scale(.96)}55%,92%{opacity:1;transform:none}100%{opacity:0}}
        .sk-beam{animation:sk-beam 2.6s cubic-bezier(.45,0,.55,1) infinite}
        .sk-pop{animation:sk-pop 5.2s cubic-bezier(.32,.72,0,1) infinite}
        @media (prefers-reduced-motion:reduce){.sk-beam{animation:none}.sk-pop{animation:none;opacity:1}}
      `}</style>
      <div className="relative flex h-[210px] items-center justify-center">
        {['left-3 top-3 border-l-[3px] border-t-[3px]', 'right-3 top-3 border-r-[3px] border-t-[3px]', 'left-3 bottom-3 border-b-[3px] border-l-[3px]', 'right-3 bottom-3 border-b-[3px] border-r-[3px]'].map((c) => (
          <span key={c} className={`absolute h-6 w-6 rounded-[3px] border-[#A35848] ${c}`} />
        ))}
        <img src="/landing/bottle.webp" alt="" width={77} height={240} className="h-[180px] w-auto drop-shadow-[0_14px_18px_rgba(70,42,28,0.2)]" />
        <span className="sk-beam absolute left-6 right-6 top-1/2 h-[3px] rounded-full bg-[#A35848] shadow-[0_0_14px_3px_rgba(163,88,72,0.45)]" />
      </div>
      <div className="sk-pop mt-3 rounded-2xl bg-[#FFFEFA] px-4 py-3 text-left shadow-[0_10px_24px_rgba(70,42,28,0.10)]">
        <p className="font-mono text-[10px] tracking-[0.18em] text-[#8A7A6C]">DAILY GENTLE CLEANSER</p>
        <p className="mt-1 text-[15px] font-semibold">Not great for your skin</p>
        <p className="mt-1 text-[13px] text-[#6B6760]"><b className="text-ink">Fragrance</b> was in 3 of your 4 bad-skin days.</p>
      </div>
    </div>
  );
}

type Plan = 'prepay' | 'monthly' | 'facescan';

/** Must match FACE_SCAN_DEADLINE in api/stripe-checkout.ts (Nov 14, 2026, 11:59 pm Pacific). */
const FACE_SCAN_DEADLINE = Date.parse('2026-11-15T07:59:59Z');

async function startCheckout(email: string, plan: Plan) {
  const ref = readRef();
  const res = await fetch('/api/stripe-checkout?offer=launch', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, plan, ref }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data?.url) {
    throw new Error(
      data?.error === 'Invalid email' ? 'That email doesn’t look right.'
        : data?.error === 'Offer ended' ? 'Early access has closed.'
          : 'Checkout isn’t available right now. Try again in a minute.',
    );
  }
  track('launch_checkout', { plan, ref: ref ?? 'direct' });
  window.location.href = data.url;
}

function OfferCard() {
  const [plan, setPlan] = useState<Plan>('prepay');
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
      await startCheckout(clean, plan);
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Something went wrong. Try again.');
      setBusy(false);
    }
  }

  const option = (id: Plan, title: string, price: string, note: string, badge?: string) => (
    <button
      type="button"
      onClick={() => setPlan(id)}
      aria-pressed={plan === id}
      className={`relative flex w-full items-center gap-3.5 rounded-[18px] border bg-[#FFFEFA] px-4 py-3.5 text-left transition-colors duration-200 ${
        plan === id ? 'border-[#A35848] ring-1 ring-[#A35848]' : 'border-[#E6DED2]'
      }`}
    >
      {badge && (
        <span className="absolute -top-2.5 right-4 rounded-full bg-[#A35848] px-2.5 py-0.5 font-mono text-[10px] tracking-[0.12em] text-[#FFFEFA]">{badge}</span>
      )}
      <span className={`flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 ${plan === id ? 'border-[#A35848]' : 'border-[#D8D1C5]'}`}>
        {plan === id && <span className="h-2.5 w-2.5 rounded-full bg-[#A35848]" />}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-[16px] font-semibold">{title}</span>
        <span className="block text-[13px] text-[#6B6760]">{note}</span>
      </span>
      <span className="text-[17px] font-semibold tabular-nums">{price}</span>
    </button>
  );

  return (
    <form onSubmit={submit} className="mx-auto w-full max-w-[460px] rounded-[26px] border border-[#E6DED2] bg-[#FBF7F0] p-5 shadow-[0_20px_50px_rgba(70,42,28,0.08)]">
      <div className="flex flex-col gap-3">
        {option('prepay', '3 months up front', '$19.47', '$6.49 a month · price locked in', 'BEST DEAL')}
        {option('monthly', 'Monthly', '$6.49/mo', 'For your first 3 months')}
      </div>
      <p className="mt-3 text-[12.5px] leading-relaxed text-[#6B6760]">
        {plan === 'monthly'
          ? 'Monthly is $6.49 for months 1–3 while the launch offer runs. Cancel and come back later, and it may be gone. Paying up front is the only way to lock it in.'
          : 'One payment covers your first 3 months. No surprises in between.'}{' '}
        Then $8.99/month. Cancel any time.
      </p>

      <label htmlFor="offer-email" className="mt-4 block text-[14px] font-semibold">
        Email you use in the Skintel app
      </label>
      <input
        id="offer-email"
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="you@example.com"
        autoComplete="email"
        className="mt-1.5 w-full rounded-[14px] border border-[#E6DED2] bg-[#FFFEFA] px-4 py-3 text-base text-ink outline-none placeholder:text-[#9A8D80] focus:border-[#A35848]"
      />
      <p className="mt-1.5 text-[12.5px] leading-relaxed text-[#6B6760]">
        Skintel+ goes on the account with this email. Already in the app? Use the email under <b className="text-ink">You → Account &amp; data</b>. New? Sign in to the app with this email after paying.
      </p>

      <button
        disabled={busy}
        className="mt-4 w-full rounded-full bg-[#A35848] py-3.5 text-[16px] font-semibold text-[#FFFEFA] transition-transform duration-200 ease-ios active:scale-[0.98] disabled:opacity-70"
      >
        {busy ? 'Opening checkout…' : plan === 'prepay' ? 'Get 3 months for $19.47' : 'Start at $6.49/month'}
      </button>
      <p className={`mt-2.5 text-center text-[12px] ${err ? 'text-[#A35848]' : 'text-[#8A7A6C]'}`}>
        {err ?? 'Secure checkout by Stripe. Billed by Skintel, not Apple.'}
      </p>
      <p className="mt-1 text-center text-[12px] text-[#8A7A6C]">
        Any problem? Email <a href="mailto:skinstelreview@gmail.com" className="underline">skinstelreview@gmail.com</a>. We reply within 24 hours.
      </p>
    </form>
  );
}

function useCountdown(deadline: number) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(id);
  }, []);
  const left = Math.max(0, deadline - now);
  return {
    ended: left === 0,
    parts: [
      ['DAYS', Math.floor(left / 86_400_000)],
      ['HRS', Math.floor(left / 3_600_000) % 24],
      ['MIN', Math.floor(left / 60_000) % 60],
      ['SEC', Math.floor(left / 1000) % 60],
    ] as const,
  };
}

/** A face under a scan beam, zone dots lighting up, then the locked Day 1 card. CSS only. */
function FaceScanDemo() {
  const zones = [
    { name: 'Forehead', x: 50, y: 24 },
    { name: 'Nose', x: 50, y: 50 },
    { name: 'Left cheek', x: 30, y: 58 },
    { name: 'Right cheek', x: 70, y: 58 },
    { name: 'Chin', x: 50, y: 80 },
  ];
  return (
    <div className="relative mx-auto w-full max-w-[300px] overflow-hidden rounded-[28px] border border-[#3A332B] bg-[#1A1814] p-5 text-[#F4EDE0]">
      <style>{`
        @keyframes fs-beam{0%,100%{transform:translateY(0)}50%{transform:translateY(196px)}}
        @keyframes fs-dot{0%,30%{opacity:.15;transform:translate(-50%,-50%) scale(.6)}45%,100%{opacity:1;transform:translate(-50%,-50%) scale(1)}}
        .fs-beam{animation:fs-beam 3s cubic-bezier(.45,0,.55,1) infinite}
        .fs-dot{animation:fs-dot 3s cubic-bezier(.32,.72,0,1) infinite alternate}
        @media (prefers-reduced-motion:reduce){.fs-beam{animation:none;opacity:0}.fs-dot{animation:none}}
      `}</style>
      <p className="font-mono text-[10px] tracking-[0.18em] text-[#EAD8C8]">YOUR SKIN MAP · DAY 1 OF 7</p>
      <div className="relative mx-auto mt-3 h-[200px] w-[150px]">
        <svg viewBox="0 0 150 200" className="absolute inset-0 h-full w-full" aria-hidden>
          <ellipse cx="75" cy="100" rx="62" ry="88" fill="none" stroke="#F4EDE0" strokeOpacity=".28" strokeWidth="1.5" />
          <ellipse cx="75" cy="100" rx="44" ry="70" fill="none" stroke="#F4EDE0" strokeOpacity=".1" />
          <path d="M52 78q8-5 16 0M82 78q8-5 16 0M75 92v20q-5 4 0 6M62 140q13 8 26 0" fill="none" stroke="#F4EDE0" strokeOpacity=".35" strokeWidth="1.5" strokeLinecap="round" />
        </svg>
        {zones.map((z, i) => (
          <span
            key={z.name}
            className="fs-dot absolute h-3 w-3 rounded-full bg-[#A35848] shadow-[0_0_12px_4px_rgba(163,88,72,0.55)]"
            style={{ left: `${z.x}%`, top: `${z.y}%`, animationDelay: `${i * 0.25}s` }}
          />
        ))}
        <span className="fs-beam absolute -left-3 -right-3 top-0 h-[3px] rounded-full bg-[#A35848] shadow-[0_0_14px_3px_rgba(163,88,72,0.5)]" />
      </div>
      <div className="relative mt-4 overflow-hidden rounded-2xl bg-[#FFFEFA] px-4 py-3 text-ink">
        <div className="space-y-2 blur-[5px]" aria-hidden>
          {['Forehead · Shine', 'Nose · Texture', 'Cheeks · Redness'].map((r) => (
            <div key={r} className="flex justify-between text-[13px]"><span>{r}</span><span>Some</span></div>
          ))}
        </div>
        <div className="absolute inset-0 flex flex-col items-center justify-center bg-[#FFFEFA]/40">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="#A35848" aria-hidden><path d="M17 10V7a5 5 0 0 0-10 0v3H5v12h14V10h-2Zm-8 0V7a3 3 0 0 1 6 0v3H9Z" /></svg>
          <p className="mt-1 text-[14px] font-semibold">6 days left to unlock</p>
          <p className="text-[11px] text-[#6B6760]">Scan daily to build your full report</p>
        </div>
      </div>
    </div>
  );
}

function FaceScanOffer() {
  const { ended, parts } = useCountdown(FACE_SCAN_DEADLINE);
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
      await startCheckout(clean, 'facescan');
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Something went wrong. Try again.');
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto w-full max-w-[460px] rounded-[26px] border border-[#E6DED2] bg-[#FBF7F0] p-5 shadow-[0_20px_50px_rgba(70,42,28,0.08)]">
      <div className="flex flex-wrap items-center gap-2">
        <span className="rounded-full bg-[#A35848] px-2.5 py-1 font-mono text-[10px] tracking-[0.14em] text-[#FFFEFA]">LIMITED-TIME DEAL</span>
        <span className="rounded-full border border-[#A35848] px-2.5 py-1 font-mono text-[10px] tracking-[0.14em] text-[#A35848]">LIMITED ACCESS</span>
      </div>
      {ended ? (
        <p className="mt-4 text-[16px] font-semibold">Early access has closed. Face Scan comes to everyone soon.</p>
      ) : (
        <>
          <p className="mt-4 text-[13px] font-semibold text-[#6B6760]">Early access closes in</p>
          <div className="mt-2 grid grid-cols-4 gap-2" role="timer" aria-live="off">
            {parts.map(([label, n]) => (
              <div key={label} className="rounded-[14px] bg-[#1A1814] py-2.5 text-center text-[#FFFEFA]">
                <div className="font-mono text-[22px] font-semibold tabular-nums">{String(n).padStart(2, '0')}</div>
                <div className="font-mono text-[9px] tracking-[0.16em] text-[#EAD8C8]">{label}</div>
              </div>
            ))}
          </div>
          <div className="mt-4 flex items-baseline justify-between">
            <span className="text-[16px] font-semibold">Skintel+ with Face Scan</span>
            <span className="text-[17px] font-semibold tabular-nums">$7.99/mo</span>
          </div>
          <p className="mt-1 text-[12.5px] leading-relaxed text-[#6B6760]">
            Skintel+ starts today, and Face Scan opens on your account first. $7.99 a month for as long as you stay subscribed (regular Skintel+ is $8.99). Cancel any time.
          </p>
          <form onSubmit={submit}>
            <label htmlFor="face-email" className="mt-4 block text-[14px] font-semibold">Email you use in the Skintel app</label>
            <input
              id="face-email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              autoComplete="email"
              className="mt-1.5 w-full rounded-[14px] border border-[#E6DED2] bg-[#FFFEFA] px-4 py-3 text-base text-ink outline-none placeholder:text-[#9A8D80] focus:border-[#A35848]"
            />
            <button
              disabled={busy}
              className="mt-4 w-full rounded-full bg-ink py-3.5 text-[16px] font-semibold text-[#FFFEFA] transition-transform duration-200 ease-ios active:scale-[0.98] disabled:opacity-70"
            >
              {busy ? 'Opening checkout…' : 'Get early access · $7.99/month'}
            </button>
          </form>
          <p className={`mt-2.5 text-center text-[12px] ${err ? 'text-[#A35848]' : 'text-[#8A7A6C]'}`}>
            {err ?? 'Secure checkout by Stripe. Billed by Skintel, not Apple.'}
          </p>
        </>
      )}
    </div>
  );
}

const STEPS = [
  { icon: '/email/scan.png', title: 'Scan', text: 'Any bottle, any barcode.' },
  { icon: '/email/log.png', title: 'Log', text: 'Ten seconds a day.' },
  { icon: '/email/find.png', title: 'Know why', text: 'See your trigger ingredient.' },
];

export default function Home() {
  const [showBar, setShowBar] = useState(true);
  const offer = useRef<HTMLElement>(null);
  const card = useRef<HTMLDivElement>(null);

  useEffect(() => {
    readRef();
    // The bar is there from the first paint and only steps aside while the offer card itself
    // is on screen (it would only repeat what the card says).
    const el = card.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => setShowBar(!e.isIntersecting));
    io.observe(el);
    return () => io.disconnect();
  }, []);

  function jumpToOffer() {
    offer.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  return (
    <div className="min-h-[100dvh] overflow-x-hidden bg-[#F4EDE0] font-sans text-ink antialiased">
      <div className="mx-auto max-w-[1120px] px-5 pt-[calc(env(safe-area-inset-top)+68px)]">
        <nav className="flex h-14 items-center">
          <Link to="/" className="font-display text-[28px] tracking-tight">Skintel</Link>
        </nav>

        <section className="grid gap-2 pt-7 md:min-h-[calc(100vh-8rem)] md:grid-cols-[1.05fr_0.95fr] md:items-center md:pt-10">
          <div className="min-w-0">
            <p className="font-mono text-[11px] tracking-[0.22em] text-[#A35848]">NOW ON IPHONE</p>
            <h1 className="mt-3.5 font-display text-[clamp(44px,11vw,84px)] font-normal leading-[0.98] tracking-[-0.015em]">
              Find the ingredient <em className="font-display italic text-[#A35848]">breaking you out.</em>
            </h1>
            <p className="mt-4 max-w-[460px] text-lg leading-relaxed text-[#6B6760]">
              Scan your products, log your skin, and Skintel shows you what your bad days have in common.
            </p>
            <div className="mt-6 flex flex-wrap items-center gap-3">
              <AppStoreButton />
              <button onClick={jumpToOffer} className="rounded-full bg-[#A35848] px-5 py-3 text-[15px] font-semibold text-[#FFFEFA]">
                Skintel+ for $6.49
              </button>
            </div>
            <p className="mt-3 text-[13px] text-[#8A7A6C]">Free to download. Skintel+ launch price for your first 3 months.</p>
            <a href="#face-scan" className="mt-4 inline-flex items-center gap-2 rounded-full border border-[#E6DED2] bg-[#FFFEFA] py-1.5 pl-1.5 pr-3.5 text-[13px] font-semibold">
              <span className="rounded-full bg-[#A35848] px-2 py-0.5 font-mono text-[10px] tracking-[0.12em] text-[#FFFEFA]">NEW</span>
              Face Scan early access · limited time →
            </a>
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

        <section id="offer" ref={offer} className="scroll-mt-20 pb-4 pt-16 md:pt-20">
          <div className="grid items-center gap-10 md:grid-cols-[0.9fr_1.1fr]">
            <div className="text-center md:text-left">
              <p className="font-mono text-[11px] tracking-[0.22em] text-[#A35848]">LAUNCH OFFER · FIRST 3 MONTHS</p>
              <h2 className="mt-3 font-display text-[clamp(38px,9vw,58px)] font-normal leading-[1.0] tracking-[-0.01em]">
                Skintel+ for <em className="italic text-[#A35848]">$6.49</em> a month.
              </h2>
              <p className="mx-auto mt-3 max-w-[400px] text-[16px] leading-relaxed text-[#6B6760] md:mx-0">
                Unlimited scans, Ask Skintel and your trigger report. $8.99/month in the app, less here while it lasts.
              </p>
              <div className="mt-7 hidden md:block"><ScanDemo /></div>
            </div>
            <div ref={card}><OfferCard /></div>
          </div>
          <div className="mt-10 md:hidden"><ScanDemo /></div>
        </section>

        <section id="face-scan" className="scroll-mt-20 pb-4 pt-16 md:pt-20">
          <div className="grid items-center gap-10 md:grid-cols-[0.9fr_1.1fr]">
            <div className="text-center md:text-left">
              <p className="font-mono text-[11px] tracking-[0.22em] text-[#A35848]">NEW · FACE SCAN EARLY ACCESS</p>
              <h2 className="mt-3 font-display text-[clamp(38px,9vw,58px)] font-normal leading-[1.0] tracking-[-0.01em]">
                Map your skin <em className="italic text-[#A35848]">zone by zone.</em>
              </h2>
              <p className="mx-auto mt-3 max-w-[400px] text-[16px] leading-relaxed text-[#6B6760] md:mx-0">
                One selfie a day for 7 days. Skintel reads shine, redness and texture on each zone, then unlocks your full skin report on Day 7.
              </p>
              <div className="mt-7"><FaceScanDemo /></div>
            </div>
            <FaceScanOffer />
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
            Free to start.<br />Skintel+ when you’re ready.
          </h2>
          <div className="mt-6 flex justify-center"><AppStoreButton /></div>
        </section>

        <footer className="flex flex-wrap gap-5 border-t border-[#E6DED2] pb-[calc(env(safe-area-inset-bottom)+32px)] pt-6 text-[13px] text-[#8A7A6C]">
          <span>© Skintel</span>
          <Link to="/privacy">Privacy</Link>
          <Link to="/terms">Terms</Link>
          <a href="mailto:hello@skinstel.com">hello@skinstel.com</a>
        </footer>
      </div>

      <div
        className={`fixed left-3 right-3 top-[calc(env(safe-area-inset-top)+10px)] z-10 flex items-center justify-between gap-2.5 rounded-full bg-[rgba(26,24,20,0.92)] py-2 pl-5 pr-2 text-[#FFFEFA] backdrop-blur-md transition-transform duration-500 ease-ios md:left-auto md:right-6 md:w-auto ${
          showBar ? 'translate-y-0 shadow-[0_10px_30px_rgba(26,24,20,0.18)]' : '-translate-y-[calc(100%+env(safe-area-inset-top)+40px)] shadow-none'
        }`}
        aria-hidden={!showBar}
      >
        <button onClick={jumpToOffer} tabIndex={showBar ? 0 : -1} className="min-w-0 truncate text-left text-sm">
          Launch offer <span className="text-[#E7B8A6]">$6.49/mo</span>
        </button>
        <a href={APP_STORE_URL} tabIndex={showBar ? 0 : -1} className="shrink-0 rounded-full bg-[#A35848] px-[18px] py-[11px] text-sm font-semibold">
          Get the app
        </a>
      </div>
    </div>
  );
}
