export function IngredientChip({ name, intensity }: { name: string; intensity?: 'high' | 'medium' | 'none' }) {
  const cls =
    intensity === 'high'
      ? 'bg-bad-bg text-bad-fg'
      : intensity === 'medium'
      ? 'bg-unsure-bg text-unsure-fg'
      : 'bg-bg text-ink';
  return (
    <span className={`inline-flex items-center px-2.5 py-1 rounded-md text-xs font-mono ${cls}`}>
      {name}
    </span>
  );
}
