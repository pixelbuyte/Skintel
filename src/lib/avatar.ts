// Avatar system — user picks a style, stored locally. Used in Sidebar + Settings.
// Variants are pure SVG / CSS so they render anywhere without assets.
// Palette is brand-locked (rose / blush / clay / mauve / sand) for the premium
// beauty audience — never random rainbow hues.

export type AvatarKind =
  | 'letter'
  | 'monogram'
  | 'bloom'
  | 'leaf'
  | 'silk'
  | 'aura'
  | 'pearl'
  | 'dewdrop'
  | 'gem'
  | 'marble'
  | 'gradient'
  | 'halo'
  | 'orb'
  | 'prism';

const STORAGE_KEY = 'skintel:avatar:v1';

export const AVATAR_KINDS: AvatarKind[] = [
  'letter',
  'monogram',
  'bloom',
  'leaf',
  'silk',
  'aura',
  'pearl',
  'dewdrop',
  'gem',
  'marble',
  'gradient',
  'halo',
  'orb',
  'prism',
];

export const AVATAR_LABELS: Record<AvatarKind, string> = {
  letter: 'Initial',
  monogram: 'Monogram',
  bloom: 'Bloom',
  leaf: 'Leaf',
  silk: 'Silk',
  aura: 'Aura',
  pearl: 'Pearl',
  dewdrop: 'Dewdrop',
  gem: 'Gem',
  marble: 'Marble',
  gradient: 'Gradient',
  halo: 'Halo',
  orb: 'Orb',
  prism: 'Prism',
};

export function getAvatar(): AvatarKind {
  if (typeof window === 'undefined') return 'letter';
  try {
    const v = window.localStorage.getItem(STORAGE_KEY) as AvatarKind | null;
    if (v && AVATAR_KINDS.includes(v)) return v;
  } catch {}
  return 'letter';
}

export function setAvatar(kind: AvatarKind): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, kind);
    window.dispatchEvent(new CustomEvent('skintel:avatar-changed'));
  } catch {}
}

// Cheap stable hash for color seeding.
export function hashStr(s: string): number {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

// Brand-locked gradient pairs — warm rose / blush / clay / mauve / sand.
// Every pair harmonizes with the cream (#FFFEFA) + sand (#F4EDE0) surfaces.
const AVATAR_GRADIENTS: [string, string][] = [
  ['#C9818F', '#A35848'], // rose → terracotta (primary)
  ['#E0B0A0', '#B98FA0'], // peach-rose → mauve
  ['#D99CA3', '#8E4538'], // blush → deep rose
  ['#E6A98C', '#A35848'], // clay peach → terracotta
  ['#B98FA0', '#7E5566'], // mauve → plum
  ['#E8B4B8', '#C9818F'], // soft pink → rose
  ['#D9C7A8', '#A38A6A'], // sand → taupe
  ['#CDA0A8', '#9C6B7E'], // dusty rose → wine
];

export function hashColors(seed: string): [string, string] {
  const h = hashStr(seed);
  return AVATAR_GRADIENTS[h % AVATAR_GRADIENTS.length];
}
