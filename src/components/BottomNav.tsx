import { NavLink } from 'react-router-dom';
import { LayoutDashboard, ScanLine, GitCompare, BookOpen } from 'lucide-react';

const ITEMS = [
  { to: '/app', label: 'Home', icon: LayoutDashboard, end: true },
  { to: '/app/scanner', label: 'Scanner', icon: ScanLine },
  { to: '/app/compare', label: 'Compare', icon: GitCompare },
  { to: '/app/journal', label: 'Journal', icon: BookOpen },
];

export function BottomNav() {
  return (
    <nav
      className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-card/90 backdrop-blur-xl border-t border-border"
      style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
      aria-label="Primary"
    >
      <div className="grid grid-cols-5">
        {ITEMS.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              `flex flex-col items-center justify-center gap-1 py-2.5 min-h-14 transition-colors ${
                isActive ? 'text-primary' : 'text-muted'
              }`
            }
          >
            <Icon size={22} strokeWidth={2} />
            <span className="text-[11px] font-medium tracking-tight">{label}</span>
          </NavLink>
        ))}
      </div>
    </nav>
  );
}
