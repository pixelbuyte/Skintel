import { useState } from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, ScanLine, GitCompare, BookOpen, Plus } from 'lucide-react';
import { AddProductSheet } from './AddProductSheet';
import { haptic } from '@/lib/haptics';

const LEFT = [
  { to: '/app', label: 'Home', icon: LayoutDashboard, end: true },
  { to: '/app/scanner', label: 'Scanner', icon: ScanLine },
];
const RIGHT = [
  { to: '/app/compare', label: 'Compare', icon: GitCompare },
  { to: '/app/journal', label: 'Journal', icon: BookOpen },
];

function Tab({ to, label, icon: Icon, end }: { to: string; label: string; icon: typeof ScanLine; end?: boolean }) {
  return (
    <NavLink
      to={to}
      end={end}
      onClick={() => haptic.tap()}
      className={({ isActive }) =>
        `pressable flex flex-col items-center justify-center gap-1 py-2 min-h-14 ${
          isActive ? 'text-primary' : 'text-muted'
        }`
      }
    >
      {({ isActive }) => (
        <>
          <Icon
            size={22}
            strokeWidth={isActive ? 2.4 : 2}
            className={`transition-transform duration-300 ease-ios ${isActive ? '-translate-y-0.5 scale-105' : ''}`}
          />
          <span className="text-[10px] font-semibold tracking-tight">{label}</span>
        </>
      )}
    </NavLink>
  );
}

export function BottomNav() {
  const [addOpen, setAddOpen] = useState(false);

  return (
    <>
      <nav
        className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-card/90 backdrop-blur-xl border-t border-border"
        style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
        aria-label="Primary"
      >
        <div className="grid grid-cols-5">
          {LEFT.map((item) => (
            <Tab key={item.to} {...item} />
          ))}
          <div className="relative flex items-start justify-center">
            <button
              type="button"
              onClick={() => {
                haptic.tap();
                setAddOpen(true);
              }}
              aria-label="Add product"
              className="pressable absolute -top-5 size-14 rounded-full bg-primary text-cream flex items-center justify-center shadow-[0_6px_20px_rgba(163,88,72,0.4)] ring-4 ring-bg active:scale-90"
            >
              <Plus size={26} strokeWidth={2.4} />
            </button>
          </div>
          {RIGHT.map((item) => (
            <Tab key={item.to} {...item} />
          ))}
        </div>
      </nav>
      <AddProductSheet open={addOpen} onOpenChange={setAddOpen} />
    </>
  );
}
