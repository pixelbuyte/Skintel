import { NavLink, useNavigate } from 'react-router-dom';
import { LayoutDashboard, Package, AlertTriangle, ScanLine, Settings, LogOut, Sparkles } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { useSubscription } from '@/hooks/useSubscription';

const NAV = [
  { to: '/app', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/app/products', label: 'Products', icon: Package },
  { to: '/app/culprits', label: 'Culprits', icon: AlertTriangle },
  { to: '/app/scanner', label: 'Scanner', icon: ScanLine },
  { to: '/app/settings', label: 'Settings', icon: Settings },
];

export function Sidebar() {
  const { user, signOut } = useAuth();
  const { tier } = useSubscription();
  const nav = useNavigate();

  const tierBadge = tier === 'founding' ? 'Founding' : tier === 'pro' ? 'Pro' : 'Free';

  return (
    <aside className="hidden md:flex md:flex-col fixed top-0 left-0 h-screen w-60 bg-card border-r border-border p-4">
      <div className="flex items-center gap-2 px-2 py-3 mb-4">
        <Sparkles className="text-primary" size={22} />
        <span className="font-display text-2xl">Skintel</span>
      </div>

      <nav className="flex-1 flex flex-col gap-1">
        {NAV.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition ${
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
          className="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-muted hover:bg-bg"
          onClick={async () => {
            await signOut();
            nav('/');
          }}
        >
          <LogOut size={16} />
          Sign out
        </button>
      </div>
    </aside>
  );
}
