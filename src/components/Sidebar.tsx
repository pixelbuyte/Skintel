import { useEffect, useRef, useState } from 'react';
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
  CreditCard,
  UserCircle2,
} from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { useSubscription } from '@/hooks/useSubscription';
import { Avatar } from '@/components/Avatar';

const NAV = [
  { to: '/app', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/app/products', label: 'Products', icon: Package },
  { to: '/app/culprits', label: 'Triggers', icon: AlertTriangle },
  { to: '/app/scanner', label: 'Scanner', icon: ScanLine },
  { to: '/app/journal', label: 'Journal', icon: BookOpen },
  { to: '/app/routine', label: 'Routine', icon: Sun },
  { to: '/app/recommend', label: 'Recommend', icon: Lightbulb },
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
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  const tierBadge = tier === 'founding' ? 'Founding' : tier === 'pro' ? 'Pro' : 'Free';
  const width = collapsed ? 'w-16' : 'w-60';

  // Close profile menu on outside click.
  useEffect(() => {
    if (!menuOpen) return;
    const handle = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handle);
    return () => document.removeEventListener('mousedown', handle);
  }, [menuOpen]);

  const seed = user?.email ?? user?.id ?? 'anon';

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

      {/* PROFILE DOCK */}
      <div ref={menuRef} className="relative mt-3">
        {/* Profile chip — click opens menu */}
        <button
          type="button"
          onClick={() => setMenuOpen((v) => !v)}
          aria-expanded={menuOpen}
          className={`w-full flex items-center ${
            collapsed ? 'justify-center' : 'gap-3'
          } rounded-xl border border-border bg-bg/60 hover:bg-bg active:scale-[0.98] transition-all px-2 py-2 ${
            menuOpen ? 'ring-2 ring-primary/20 border-primary/30' : ''
          }`}
          title={collapsed ? user?.email ?? '' : undefined}
        >
          <Avatar seed={seed} size={32} className="rounded-xl" />
          {!collapsed && (
            <span className="min-w-0 flex-1 text-left">
              <span className="block text-[13px] font-medium text-ink truncate">
                {user?.email}
              </span>
              <span className="inline-flex items-center gap-1 mt-0.5">
                <span
                  className={`size-1.5 rounded-full ${
                    tier === 'free' ? 'bg-muted' : 'bg-primary'
                  }`}
                />
                <span className="text-[10px] uppercase tracking-wider text-muted font-mono">
                  {tierBadge}
                </span>
              </span>
            </span>
          )}
        </button>

        {/* Floating menu */}
        {menuOpen && (
          <div
            className={`absolute ${
              collapsed ? 'left-full ml-2 bottom-0' : 'left-0 right-0 bottom-full mb-2'
            } z-40 rounded-xl border border-border bg-cream shadow-sheet p-1 min-w-[200px]`}
          >
            <NavLink
              to="/app/settings"
              onClick={() => setMenuOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition-colors ${
                  isActive ? 'bg-primary text-card' : 'text-ink hover:bg-card'
                }`
              }
            >
              <Settings size={15} />
              Settings
            </NavLink>
            <button
              type="button"
              onClick={() => {
                setMenuOpen(false);
                nav('/pricing');
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm text-ink hover:bg-card transition-colors"
            >
              <CreditCard size={15} />
              Billing
            </button>
            <button
              type="button"
              onClick={() => {
                setMenuOpen(false);
                nav('/app/settings');
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm text-ink hover:bg-card transition-colors"
            >
              <UserCircle2 size={15} />
              Account
            </button>
            <div className="h-px bg-border my-1" />
            <button
              type="button"
              onClick={async () => {
                setMenuOpen(false);
                await signOut();
                nav('/');
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm text-bad-fg hover:bg-bad-bg transition-colors"
            >
              <LogOut size={15} />
              Sign out
            </button>
          </div>
        )}
      </div>
    </aside>
  );
}
