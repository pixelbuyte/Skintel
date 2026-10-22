/**
 * Tidies the brand and name a product page gives us. Retail titles are long
 * ("CeraVe Foaming Facial Cleanser for Oily Skin with Hyaluronic Acid, Niacinamide, ...")
 * and the brand is often missing, so the Add product form used to open with an empty Brand
 * and a name that ran off the field. Pure functions, no network.
 */

const KNOWN_BRANDS = [
  'La Roche-Posay', 'Paula\'s Choice', 'The Ordinary', 'The INKEY List', 'Drunk Elephant', 'Glow Recipe',
  'First Aid Beauty', 'Peter Thomas Roth', 'Youth To The People', 'Summer Fridays', 'Beauty of Joseon',
  'Hero Cosmetics', 'Mario Badescu', 'Sunday Riley', 'Dr. Jart+', 'Dr. Dennis Gross', 'Burt\'s Bees',
  'L\'Oreal Paris', 'L\'Oréal Paris', 'Estée Lauder', 'Estee Lauder', 'Rare Beauty', 'Fenty Skin',
  'Kiehl\'s', 'Neutrogena', 'Cetaphil', 'Clinique', 'Aveeno', 'Vanicream', 'Tatcha', 'Eucerin',
  'Bioderma', 'Avène', 'Avene', 'Vichy', 'Garnier', 'Differin', 'Supergoop', 'EltaMD', 'Innisfree',
  'COSRX', 'Hada Labo', 'Naturium', 'Byoma', 'Dermalogica', 'Murad', 'Laneige', 'Skinfix', 'PanOxyl',
  'Nivea', 'Dove', 'Simple', 'Origins', 'Lancôme', 'Lancome', 'Shiseido', 'SkinCeuticals', 'Bliss',
  'Cocokind', 'Versed', 'Olay', 'CeraVe', 'Biossance', 'Farmacy', 'Fresh', 'Glossier', 'Skin1004',
  'Anua', 'Round Lab', 'Isntree', 'Torriden', 'Medicube', 'Good Molecules', 'Acure', 'Pacifica',
  'Alpha-H', 'REN', 'Bioré', 'Biore', 'Stridex', 'Acnefree', 'Mighty Patch', 'Hero',
];

/** Retailer hosts: their domain says nothing about the brand. */
const RETAILER_NAMES = [
  'amazon', 'sephora', 'ulta', 'target', 'walmart', 'cvs', 'walgreens', 'boots', 'lookfantastic', 'cultbeauty',
  'dermstore', 'yesstyle', 'stylevana', 'iherb', 'ebay', 'nordstrom', 'macys', 'kohls', 'beautylish', 'sokoglam',
];
const RETAILERS = new RegExp(`(^|\\.)(${RETAILER_NAMES.join('|')})\\.`);

const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, '');

function brandFromName(name: string): string | null {
  const lower = name.toLowerCase();
  // Longest match first so "Paula's Choice" wins over a shorter prefix.
  const sorted = [...KNOWN_BRANDS].sort((a, b) => b.length - a.length);
  for (const b of sorted) {
    if (lower.startsWith(b.toLowerCase()) && (name.length === b.length || /[\s\-–—,:]/.test(name[b.length]))) {
      return b;
    }
  }
  return null;
}

function brandFromHost(host: string): string | null {
  if (RETAILERS.test(host)) return null;
  const label = host.replace(/^www\./, '').split('.')[0];
  const known = KNOWN_BRANDS.find((b) => norm(b) === norm(label));
  return known ?? null;
}

/** Drops a site suffix ("… | Sephora", "… - Amazon.com") and anything after the first
 *  descriptive clause ("for Oily Skin", "with Hyaluronic Acid", a comma or size). */
function shorten(name: string): string {
  let n = name.replace(/\s+/g, ' ').trim();
  n = n.split(/\s+[|–—]\s+|\s+-\s+/)[0];
  n = n.split(/,|\s\(|\s+for\s+|\s+with\s+|\s+\d+(\.\d+)?\s?(fl\.?\s?)?(oz|ml|g)\b/i)[0];
  n = n.trim();
  if (n.length > 48) {
    const cut = n.slice(0, 48);
    n = cut.slice(0, Math.max(cut.lastIndexOf(' '), 20));
  }
  return n.trim();
}

export function tidyProductNames(
  brand: string | undefined,
  productName: string | undefined,
  host: string,
): { brand?: string; productName?: string } {
  let b = (brand ?? '').trim();
  let name = (productName ?? '').trim();

  // A site name is not a brand (og:site_name "Sephora", "Amazon.com").
  if (b && RETAILER_NAMES.some((r) => norm(b).startsWith(r))) b = '';

  if (!b && name) b = brandFromName(name) ?? '';
  if (!b) b = brandFromHost(host.toLowerCase()) ?? '';

  if (b && name.toLowerCase().startsWith(b.toLowerCase())) {
    const rest = name.slice(b.length).replace(/^[\s\-–—,:]+/, '');
    if (rest.length >= 3) name = rest;
  }
  const short = shorten(name);
  if (short.length >= 3) name = short;

  return { brand: b || undefined, productName: name || undefined };
}
