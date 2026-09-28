import { type ReactNode } from 'react';
import { Sidebar, useSidebarCollapsed } from './Sidebar';
import { BottomNav } from './BottomNav';
import { MobileTopBar } from './MobileTopBar';

export function Layout({ children }: { children: ReactNode }) {
  const { collapsed, setCollapsed } = useSidebarCollapsed();
  const ml = collapsed ? 'md:ml-16' : 'md:ml-60';
  return (
    <div className="min-h-screen flex">
      <Sidebar collapsed={collapsed} onToggle={() => setCollapsed(!collapsed)} />
      <div className={`flex-1 flex flex-col w-full ${ml} transition-[margin] duration-300 ease-[cubic-bezier(0.32,0.72,0,1)]`}>
        <MobileTopBar />
        <main className="flex-1 p-4 md:p-10 max-w-6xl mx-auto w-full pb-[calc(env(safe-area-inset-bottom)+6.5rem)] md:pb-10">
          {children}
        </main>
      </div>
      <BottomNav />
    </div>
  );
}
