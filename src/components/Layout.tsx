import { type ReactNode } from 'react';
import { Sidebar } from './Sidebar';

export function Layout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen flex">
      <Sidebar />
      <main className="flex-1 ml-0 md:ml-60 p-6 md:p-10 max-w-6xl mx-auto w-full">{children}</main>
    </div>
  );
}
