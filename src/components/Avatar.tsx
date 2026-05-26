import { useEffect, useState } from 'react';
import {
  type AvatarKind,
  getAvatar,
  hashColors,
  hashStr,
} from '@/lib/avatar';

type Props = {
  seed: string; // email or user id
  kind?: AvatarKind; // optional override; otherwise reads from storage
  size?: number; // px
  className?: string;
};

export function Avatar({ seed, kind, size = 64, className = '' }: Props) {
  const [resolved, setResolved] = useState<AvatarKind>(kind ?? getAvatar());

  useEffect(() => {
    if (kind) {
      setResolved(kind);
      return;
    }
    setResolved(getAvatar());
    const onChange = () => setResolved(getAvatar());
    window.addEventListener('skintel:avatar-changed', onChange as EventListener);
    return () => window.removeEventListener('skintel:avatar-changed', onChange as EventListener);
  }, [kind]);

  return (
    <span
      className={`inline-flex items-center justify-center shrink-0 overflow-hidden rounded-2xl ${className}`}
      style={{ width: size, height: size }}
      aria-label="avatar"
    >
      <AvatarBody kind={resolved} seed={seed} size={size} />
    </span>
  );
}

export function AvatarBody({
  kind,
  seed,
  size,
}: {
  kind: AvatarKind;
  seed: string;
  size: number;
}) {
  const initial = (seed ?? '?').trim().charAt(0).toUpperCase() || '?';
  const [c1, c2] = hashColors(seed);

  switch (kind) {
    case 'letter':
      return <LetterAvatar initial={initial} c1={c1} c2={c2} size={size} />;
    case 'monogram':
      return <MonogramAvatar initial={initial} c1={c1} c2={c2} size={size} />;
    case 'bloom':
      return <BloomAvatar c1={c1} c2={c2} size={size} />;
    case 'leaf':
      return <LeafAvatar c1={c1} c2={c2} size={size} />;
    case 'silk':
      return <SilkAvatar c1={c1} c2={c2} size={size} />;
    case 'aura':
      return <AuraAvatar c1={c1} c2={c2} size={size} />;
    case 'pearl':
      return <PearlAvatar c1={c1} c2={c2} size={size} />;
    case 'dewdrop':
      return <DewdropAvatar c1={c1} c2={c2} size={size} />;
    case 'gem':
      return <GemAvatar c1={c1} c2={c2} size={size} />;
    case 'marble':
      return <MarbleAvatar c1={c1} c2={c2} size={size} />;
    case 'gradient':
      return <GradientAvatar c1={c1} c2={c2} size={size} />;
    case 'halo':
      return <HaloAvatar c1={c1} c2={c2} size={size} />;
    case 'orb':
      return <OrbAvatar seed={seed} c1={c1} c2={c2} size={size} />;
    case 'prism':
      return <PrismAvatar c1={c1} c2={c2} size={size} />;
    default:
      return <LetterAvatar initial={initial} c1={c1} c2={c2} size={size} />;
  }
}

function LetterAvatar({
  initial,
  c1,
  c2,
  size,
}: {
  initial: string;
  c1: string;
  c2: string;
  size: number;
}) {
  return (
    <span
      className="w-full h-full inline-flex items-center justify-center font-display text-cream"
      style={{
        background: `linear-gradient(135deg, ${c1}, ${c2})`,
        fontSize: size * 0.45,
        letterSpacing: '-0.02em',
      }}
    >
      {initial}
    </span>
  );
}

// Elegant serif monogram inside a thin double ring — classic, editorial.
function MonogramAvatar({
  initial,
  c1,
  c2,
  size,
}: {
  initial: string;
  c1: string;
  c2: string;
  size: number;
}) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="monoBg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={c1} />
          <stop offset="1" stopColor={c2} />
        </linearGradient>
      </defs>
      <rect width="100" height="100" fill="url(#monoBg)" />
      <circle cx="50" cy="50" r="33" fill="none" stroke="#fff" strokeOpacity="0.82" strokeWidth="1.5" />
      <circle cx="50" cy="50" r="38" fill="none" stroke="#fff" strokeOpacity="0.42" strokeWidth="0.75" />
      <text
        x="50"
        y="50"
        textAnchor="middle"
        dominantBaseline="central"
        fontSize="40"
        fill="#fff"
        fillOpacity="0.96"
        fontFamily="Georgia, 'Times New Roman', serif"
        style={{ letterSpacing: '0.01em' }}
      >
        {initial}
      </text>
    </svg>
  );
}

// Five-petal bloom — soft, botanical, beauty-forward.
function BloomAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  const petals = [0, 72, 144, 216, 288];
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="bloomBg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={c1} />
          <stop offset="1" stopColor={c2} />
        </linearGradient>
      </defs>
      <rect width="100" height="100" fill="url(#bloomBg)" />
      {petals.map((deg) => (
        <ellipse
          key={deg}
          cx="50"
          cy="31"
          rx="11"
          ry="19"
          fill="#fff"
          fillOpacity="0.88"
          transform={`rotate(${deg} 50 50)`}
        />
      ))}
      <circle cx="50" cy="50" r="9" fill="#fff" fillOpacity="0.96" />
      <circle cx="50" cy="50" r="5" fill={c2} fillOpacity="0.55" />
    </svg>
  );
}

// Faceted gem (brilliant cut) with light play — luxe, jewel-like.
function GemAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="gemBg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={c1} />
          <stop offset="1" stopColor={c2} />
        </linearGradient>
      </defs>
      <rect width="100" height="100" fill="url(#gemBg)" />
      {/* stone body */}
      <polygon points="50,22 74,42 50,80 26,42" fill="#fff" fillOpacity="0.16" />
      {/* table + crown facets */}
      <polygon points="38,42 62,42 50,52" fill="#fff" fillOpacity="0.72" />
      <polygon points="50,22 62,42 38,42" fill="#fff" fillOpacity="0.5" />
      <polygon points="26,42 38,42 50,52" fill="#fff" fillOpacity="0.3" />
      <polygon points="74,42 62,42 50,52" fill="#fff" fillOpacity="0.42" />
      {/* pavilion facets — lifted for 32px legibility */}
      <polygon points="26,42 50,52 50,80" fill="#fff" fillOpacity="0.42" />
      <polygon points="74,42 50,52 50,80" fill="#fff" fillOpacity="0.5" />
      {/* facet edges */}
      <g stroke="#fff" strokeOpacity="0.5" strokeWidth="1" fill="none">
        <polygon points="50,22 74,42 50,80 26,42" />
        <path d="M38,42 H62 M26,42 L50,52 L74,42 M50,52 V80 M50,22 L38,42 M50,22 L62,42" />
      </g>
    </svg>
  );
}

// Generative gradient orb with floating dots — deterministic from seed.
function OrbAvatar({
  seed,
  c1,
  c2,
  size,
}: {
  seed: string;
  c1: string;
  c2: string;
  size: number;
}) {
  const h = hashStr(seed);
  const dots: { cx: number; cy: number; r: number; o: number }[] = [];
  for (let i = 0; i < 6; i++) {
    const k = (h >> (i * 3)) & 0xff;
    dots.push({
      cx: 18 + (k % 64),
      cy: 18 + ((k >> 3) % 64),
      r: 1.5 + ((k >> 5) % 4),
      o: 0.25 + ((k % 7) / 14),
    });
  }
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <radialGradient id="orbBg" cx="0.35" cy="0.3" r="0.9">
          <stop offset="0" stopColor={c1} />
          <stop offset="1" stopColor={c2} />
        </radialGradient>
      </defs>
      <rect width="100" height="100" fill="url(#orbBg)" />
      {dots.map((d, i) => (
        <circle key={i} cx={d.cx} cy={d.cy} r={d.r} fill="#fff" fillOpacity={d.o} />
      ))}
      <circle cx="36" cy="32" r="10" fill="#fff" fillOpacity="0.25" />
    </svg>
  );
}

// Stacked prism / triangle architecture.
function PrismAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="prismBg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={c2} />
          <stop offset="1" stopColor={c1} />
        </linearGradient>
      </defs>
      <rect width="100" height="100" fill="url(#prismBg)" />
      <polygon points="50,16 80,72 20,72" fill="#fff" fillOpacity="0.16" />
      <polygon points="50,30 72,72 28,72" fill="#fff" fillOpacity="0.34" />
      <polygon points="50,46 64,72 36,72" fill="#fff" fillOpacity="0.6" />
      <line x1="20" y1="80" x2="80" y2="80" stroke="#fff" strokeOpacity="0.35" strokeWidth="1.5" />
    </svg>
  );
}

// Elegant botanical leaf with a gently curved blade and a soft center vein.
function LeafAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="leafBg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={c1} />
          <stop offset="100%" stopColor={c2} />
        </linearGradient>
      </defs>
      <rect width="100" height="100" fill="url(#leafBg)" />
      <path d="M50 18 C72 30 78 58 50 84 C22 58 28 30 50 18 Z" fill="#fff" fillOpacity={0.4} />
      <path
        d="M50 18 C72 30 78 58 50 84 C22 58 28 30 50 18 Z"
        fill="none"
        stroke="#fff"
        strokeOpacity={0.92}
        strokeWidth={2.4}
        strokeLinejoin="round"
      />
      <path
        d="M50 22 C49 42 49 64 50 80"
        fill="none"
        stroke="#fff"
        strokeOpacity={0.85}
        strokeWidth={2}
        strokeLinecap="round"
      />
      <path
        d="M50 38 C58 38 64 36 70 33 M50 52 C58 52 65 51 72 49 M50 66 C57 66 63 64 68 61"
        fill="none"
        stroke="#fff"
        strokeOpacity={0.55}
        strokeWidth={1.4}
        strokeLinecap="round"
      />
      <path
        d="M50 38 C42 38 36 36 30 33 M50 52 C42 52 35 51 28 49 M50 66 C43 66 37 64 32 61"
        fill="none"
        stroke="#fff"
        strokeOpacity={0.55}
        strokeWidth={1.4}
        strokeLinecap="round"
      />
    </svg>
  );
}

// Flowing silk: smooth overlapping ribbon waves drifting across the frame.
function SilkAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="silkBg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={c1} />
          <stop offset="100%" stopColor={c2} />
        </linearGradient>
      </defs>
      <rect width="100" height="100" fill="url(#silkBg)" />
      <path
        d="M-4 30 C24 14 44 46 70 30 C84 22 96 26 104 22 L104 50 C96 54 84 50 70 58 C44 74 24 42 -4 58 Z"
        fill="#fff"
        fillOpacity={0.34}
      />
      <path
        d="M-4 52 C24 36 44 68 70 52 C84 44 96 48 104 44 L104 66 C96 70 84 66 70 74 C44 90 24 58 -4 74 Z"
        fill="#fff"
        fillOpacity={0.5}
      />
      <path
        d="M-4 30 C24 14 44 46 70 30 C84 22 96 26 104 22"
        fill="none"
        stroke="#fff"
        strokeOpacity={0.9}
        strokeWidth={2.2}
        strokeLinecap="round"
      />
      <path
        d="M-4 74 C24 58 44 90 70 74 C84 66 96 70 104 66"
        fill="none"
        stroke={c2}
        strokeOpacity={0.6}
        strokeWidth={2}
        strokeLinecap="round"
      />
    </svg>
  );
}

// Soft concentric radial glow — layered translucent halo blooming from center.
function AuraAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <radialGradient id="auraBg" cx="50%" cy="50%" r="75%">
          <stop offset="0%" stopColor={c1} />
          <stop offset="100%" stopColor={c2} />
        </radialGradient>
        <radialGradient id="auraBloom" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#fff" stopOpacity="0.9" />
          <stop offset="60%" stopColor="#fff" stopOpacity="0.25" />
          <stop offset="100%" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
      </defs>
      <rect width="100" height="100" fill="url(#auraBg)" />
      <circle cx="50" cy="50" r="44" fill="none" stroke="#fff" strokeWidth="1.5" strokeOpacity="0.32" />
      <circle cx="50" cy="50" r="34" fill="none" stroke="#fff" strokeWidth="2" strokeOpacity="0.42" />
      <circle cx="50" cy="50" r="24" fill="none" stroke={c2} strokeWidth="2.5" strokeOpacity="0.5" />
      <circle cx="50" cy="50" r="30" fill="url(#auraBloom)" fillOpacity="0.9" />
      <circle cx="50" cy="50" r="13" fill="#fff" fillOpacity="0.85" />
    </svg>
  );
}

// Iridescent pearl sphere with a soft off-center highlight and faint rim.
function PearlAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="pearlBg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor={c1} />
          <stop offset="100%" stopColor={c2} />
        </linearGradient>
        <radialGradient id="pearlHi" cx="38%" cy="34%" r="62%">
          <stop offset="0%" stopColor="#fff" stopOpacity="0.96" />
          <stop offset="45%" stopColor="#fff" stopOpacity="0.4" />
          <stop offset="100%" stopColor="#fff" stopOpacity="0.08" />
        </radialGradient>
      </defs>
      <rect width="100" height="100" fill="url(#pearlBg)" />
      <circle cx="50" cy="50" r="36" fill="none" stroke="#fff" strokeWidth="2" strokeOpacity="0.35" />
      <circle cx="50" cy="50" r="33" fill="url(#pearlHi)" />
      <ellipse cx="40" cy="36" rx="11" ry="8" fill="#fff" fillOpacity="0.85" transform="rotate(-25 40 36)" />
      <ellipse cx="60" cy="64" rx="9" ry="5" fill={c2} fillOpacity="0.3" transform="rotate(-25 60 64)" />
    </svg>
  );
}

// Single glossy water droplet with a bright highlight.
function DewdropAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="dewdropBg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor={c1} />
          <stop offset="100%" stopColor={c2} />
        </linearGradient>
        <radialGradient id="dewdropHi" cx="42%" cy="62%" r="58%">
          <stop offset="0%" stopColor="#fff" stopOpacity="0.55" />
          <stop offset="70%" stopColor="#fff" stopOpacity="0.12" />
          <stop offset="100%" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
      </defs>
      <rect width="100" height="100" fill="url(#dewdropBg)" />
      <path
        d="M50 16 C62 38 72 52 72 64 A22 22 0 0 1 28 64 C28 52 38 38 50 16 Z"
        fill="#fff"
        fillOpacity="0.34"
        stroke="#fff"
        strokeWidth="2"
        strokeOpacity="0.6"
      />
      <ellipse cx="50" cy="62" rx="18" ry="20" fill="url(#dewdropHi)" />
      <ellipse cx="43" cy="56" rx="6" ry="9" fill="#fff" fillOpacity="0.92" transform="rotate(-18 43 56)" />
      <circle cx="58" cy="70" r="3.5" fill={c2} fillOpacity="0.3" />
    </svg>
  );
}

// Duotone mesh: a soft organic white blob offset over a smooth diagonal gradient.
function GradientAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="gradientBg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={c1} />
          <stop offset="100%" stopColor={c2} />
        </linearGradient>
        <radialGradient id="gradientBlob" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0%" stopColor="#fff" stopOpacity="0.55" />
          <stop offset="100%" stopColor="#fff" stopOpacity="0.08" />
        </radialGradient>
      </defs>
      <rect width="100" height="100" fill="url(#gradientBg)" />
      <path
        d="M64 22 C82 26 88 46 80 62 C72 78 50 84 36 76 C20 67 18 46 30 33 C40 22 50 19 64 22 Z"
        fill="url(#gradientBlob)"
        fillOpacity={0.9}
      />
    </svg>
  );
}

// Marble swirl: thin flowing white vein curves drifting over the gradient.
function MarbleAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="marbleBg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={c1} />
          <stop offset="100%" stopColor={c2} />
        </linearGradient>
      </defs>
      <rect width="100" height="100" fill="url(#marbleBg)" />
      <path
        d="M8 70 C28 58 34 78 54 64 C72 51 78 70 96 56"
        fill="none"
        stroke="#fff"
        strokeWidth={2.4}
        strokeLinecap="round"
        strokeOpacity={0.92}
      />
      <path
        d="M6 44 C26 30 40 50 58 34 C74 20 84 38 98 26"
        fill="none"
        stroke="#fff"
        strokeWidth={1.8}
        strokeLinecap="round"
        strokeOpacity={0.6}
      />
      <path
        d="M14 88 C32 80 42 92 60 82 C76 73 84 88 94 80"
        fill="none"
        stroke={c2}
        strokeWidth={1.4}
        strokeLinecap="round"
        strokeOpacity={0.45}
      />
    </svg>
  );
}

// Minimal luxe: thin elegant concentric rings centered on the gradient.
function HaloAvatar({ c1, c2, size }: { c1: string; c2: string; size: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <linearGradient id="haloBg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={c1} />
          <stop offset="100%" stopColor={c2} />
        </linearGradient>
      </defs>
      <rect width="100" height="100" fill="url(#haloBg)" />
      <circle cx="50" cy="50" r="30" fill="none" stroke="#fff" strokeWidth={2.2} strokeOpacity={0.9} />
      <circle cx="50" cy="50" r="20" fill="none" stroke="#fff" strokeWidth={1.5} strokeOpacity={0.55} />
      <circle cx="50" cy="50" r="9" fill="none" stroke={c2} strokeWidth={1.5} strokeOpacity={0.5} />
    </svg>
  );
}

