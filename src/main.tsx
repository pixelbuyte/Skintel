import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import './index.css';
import App from './App.tsx';
import { AuthProvider } from '@/hooks/useAuth';
import { registerServiceWorker, captureInstallPrompt } from '@/lib/pwa';
import { processQueue } from '@/lib/offlineQueue';
import { supabase } from '@/lib/supabase';
import { setupNativeShell } from '@/lib/native';

captureInstallPrompt();
registerServiceWorker();
void setupNativeShell();

// Best-effort flush of any UPCs queued while offline (e.g. drugstore basement).
// Silent — failures stay in the queue.
window.addEventListener('online', () => {
  void processQueue(async (upc) => {
    const { data: sessionData } = await supabase.auth.getSession();
    const token = sessionData.session?.access_token;
    if (!token) throw new Error('no-session');
    const r = await fetch(`/api/lookup?mode=barcode&upc=${encodeURIComponent(upc)}`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!r.ok) throw new Error(`status ${r.status}`);
  });
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
);
