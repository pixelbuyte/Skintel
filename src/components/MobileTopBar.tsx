import { useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  Package,
  AlertTriangle,
  ScanLine,
  Settings,
  LogOut,
  Sparkles,
  Sun,
  Lightbulb,
  BookOpen,
  Menu,
  X,
} from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { useSubscription } from '@/hooks/useSubscription';

const NAV = [
  { to: '/app', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/app/products', label: 'Products', icon: Package },
  { to: '/app/culprits', label: 'Culprits', icon: AlertTriangle },
  { to: '/app/scanner', label: 'Scanner', icon: ScanLine },
  { to: '/app/journal', label: 'Journal', icon: BookOpen },
  { to: '/app/routine', label: 'Routine', icon: Sun },
  { to: '/app/recommend', label: 'Recommend', icon: Lightbulb },
  { to: '/app/settings', label: 'Settings', icon: Settings },
];

export function MobileTopBar() {
  const [open, setOpen] = useState(false);
  const { user, signOut } = useAuth();
  const { tier } = useSubscription();
  const nav = useNavigate();

  const tierBadge = tier === 'founding' ? 'Founding' : tier === 'pro' ? 'Pro' : 'Free';

  return (
    <>
      <header
        className="md:hidden sticky top-0 z-30 bg-card/90 backdrop-blur-xl border-b border-border"
        style={{ paddingTop: 'env(safe-area-inset-top)' }}
      >
        <div className="flex items-center justify-between px-4 py-3">
          <NavLink to="/app" className="flex items-center gap-2">
            <Sparkles className="text-primary" size={20} />
            <span className="font-display text-xl">Skintel</span>
          </NavLink>
          <button
            type="button"
            onClick={() => setOpen(true)}
            className="min-h-11 min-w-11 inline-flex items-center justify-center rounded-full hover:bg-bg transition-colors"
            aria-label="Open menu"
          >
            <Menu size={22} />
          </button>
        </div>
      </header>

      {open && (
        <div
          className="md:hidden fixed inset-0 z-50 bg-ink/40 backdrop-blur-sm"
          onClick={() => setOpen(false)}
          aria-hidden="true"
        >
          <aside
            className="absolute top-0 right-0 h-full w-72 max-w-[85vw] bg-card border-l border-border p-4 flex flex-col shadow-2xl"
            style={{ paddingTop: 'calc(env(safe-area-inset-top) + 1rem)' }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Sparkles className="text-primary" size={20} />
                <span className="font-display text-xl">Skintel</span>
              </div>
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="min-h-11 min-w-11 inline-flex items-center justify-center rounded-full hover:bg-bg"
                aria-label="Close menu"
              >
                <X size={22} />
              </button>
            </div>

            <nav className="flex-1 flex flex-col gap-1">
              {NAV.map(({ to, label, icon: Icon, end }) => (
                <NavLink
                  key={to}
                  to={to}
                  end={end}
                  onClick={() => setOpen(false)}
                  className={({ isActive }) =>
                    `flex items-center gap-3 px-3 py-3 rounded-xl text-sm transition-colors min-h-11 ${
                      isActive ? 'bg-primary text-card' : 'text-ink hover:bg-bg'
                    }`
                  }
                >
                  <Icon size={18} />
                  {label}
                </NavLink>
              ))}
            </nav>

            <div className="border-t border-border pt-3 mt-3">
              <div className="px-2 mb-2">
                <div className="text-xs text-muted truncate">{user?.email}</div>
                <div className="inline-block mt-1 px-2 py-0.5 rounded-full text-xs bg-bg border border-border">
                  {tierBadge}
                </div>
              </div>
              <button
                type="button"
                className="w-full flex items-center gap-2 px-3 py-3 rounded-xl text-sm text-muted hover:bg-bg min-h-11"
                onClick={async () => {
                  await signOut();
                  setOpen(false);
                  nav('/');
                }}
              >
                <LogOut size={16} />
                Sign out
              </button>
            </div>
          </aside>
        </div>
      )}
    </>
  );
}
