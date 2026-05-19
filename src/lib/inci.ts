export interface ParsedIngredient {
  raw: string;
  normalized: string;
  position: number;
}

const STRIP_PARENS = /\s*\([^)]*\)\s*/g;

export function normalizeInci(name: string): string {
  return name
    .toLowerCase()
    .replace(STRIP_PARENS, ' ')
    .replace(/[*†‡]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function parseInci(raw: string): ParsedIngredient[] {
  if (!raw) return [];
  const seen = new Set<string>();
  const out: ParsedIngredient[] = [];
  const parts = raw
    .split(/[,;\n\r]+/)
    .map((s) => s.trim())
    .filter(Boolean);

  for (const original of parts) {
    const cleaned = original.replace(/^[.\-•·\d]+\s*/, '').trim();
    if (!cleaned) continue;
    const normalized = normalizeInci(cleaned);
    if (!normalized || seen.has(normalized)) continue;
    seen.add(normalized);
    out.push({ raw: cleaned, normalized, position: out.length });
  }
  return out;
}
