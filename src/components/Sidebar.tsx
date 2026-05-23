import { useEffect, useState } from 'react';
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
  ChevronsLeft,
  ChevronsRight,
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

const STORAGE_KEY = 'skintel_sidebar_collapsed';

export function useSidebarCollapsed() {
  const [collapsed, setCollapsed] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false;
    return localStorage.getItem(STORAGE_KEY) === '1';
  });
  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, collapsed ? '1' : '0');
  }, [collapsed]);
  return { collapsed, setCollapsed };
}

export function Sidebar({
  collapsed,
  onToggle,
}: {
  collapsed: boolean;
  onToggle: () => void;
}) {
  const { user, signOut } = useAuth();
  const { tier } = useSubscription();
  const nav = useNavigate();

  const tierBadge = tier === 'founding' ? 'Founding' : tier === 'pro' ? 'Pro' : 'Free';
  const width = collapsed ? 'w-16' : 'w-60';

  return (
    <aside
      className={`hidden md:flex md:flex-col fixed top-0 left-0 h-screen ${width} bg-card border-r border-border p-3 transition-[width] duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] z-30`}
    >
      <div className={`flex items-center ${collapsed ? 'justify-center' : 'justify-between'} px-2 py-3 mb-3`}>
        {!collapsed && (
          <div className="flex items-center gap-2">
            <Sparkles className="text-primary" size={22} />
            <span className="font-display text-2xl">Skintel</span>
          </div>
        )}
        <button
          type="button"
          onClick={onToggle}
          className="min-h-9 min-w-9 inline-flex items-center justify-center rounded-lg text-muted hover:bg-bg hover:text-ink transition-colors"
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          title={collapsed ? 'Expand' : 'Collapse'}
        >
          {collapsed ? <ChevronsRight size={18} /> : <ChevronsLeft size={18} />}
        </button>
      </div>

      <nav className="flex-1 flex flex-col gap-1">
        {NAV.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            title={collapsed ? label : undefined}
            className={({ isActive }) =>
              `flex items-center ${collapsed ? 'justify-center' : 'gap-3'} px-3 py-2.5 rounded-xl text-sm transition-colors ${
                isActive ? 'bg-primary text-card' : 'text-ink hover:bg-bg'
              }`
            }
          >
            <Icon size={18} />
            {!collapsed && label}
          </NavLink>
        ))}
      </nav>

      <div className="border-t border-border pt-3 mt-3">
        {!collapsed && (
          <div className="px-2 mb-2">
            <div className="text-xs text-muted truncate">{user?.email}</div>
            <div className="inline-block mt-1 px-2 py-0.5 rounded-full text-xs bg-bg border border-border">
              {tierBadge}
            </div>
          </div>
        )}
        <button
          type="button"
          title={collapsed ? 'Sign out' : undefined}
          className={`w-full flex items-center ${collapsed ? 'justify-center' : 'gap-2'} px-3 py-2.5 rounded-xl text-sm text-muted hover:bg-bg transition-colors`}
          onClick={async () => {
            await signOut();
            nav('/');
          }}
        >
          <LogOut size={16} />
          {!collapsed && 'Sign out'}
        </button>
      </div>
    </aside>
  );
}
