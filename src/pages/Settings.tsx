import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Download, ExternalLink, LogOut, Trash2 } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { useSubscription } from '@/hooks/useSubscription';
import { ConfirmDialog } from '@/components/ConfirmDialog';

export default function Settings() {
  const { user, session, signOut } = useAuth();
  const { tier } = useSubscription();
  const nav = useNavigate();
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  async function openPortal() {
    if (!session) return;
    setErr(null);
    setBusy('portal');
    try {
      const res = await fetch('/api/stripe-portal', {
        method: 'POST',
        headers: { Authorization: `Bearer ${session.access_token}` },
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error ?? 'Failed to open portal');
      window.location.href = data.url;
    } catch (e: any) {
      setErr(e?.message ?? 'Something went wrong');
    } finally {
      setBusy(null);
    }
  }

  async function exportData() {
    if (!session) return;
    setErr(null);
    setBusy('export');
    try {
      const res = await fetch('/api/export-data', {
        headers: { Authorization: `Bearer ${session.access_token}` },
      });
      if (!res.ok) throw new Error('Export failed');
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `skintel-export-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e: any) {
      setErr(e?.message ?? 'Export failed');
    } finally {
      setBusy(null);
    }
  }

  async function deleteAccount() {
    if (!session) return;
    setBusy('delete');
    try {
      const res = await fetch('/api/delete-account', {
        method: 'POST',
        headers: { Authorization: `Bearer ${session.access_token}` },
      });
      if (!res.ok) throw new Error('Delete failed');
      await signOut();
      nav('/');
    } catch (e: any) {
      setErr(e?.message ?? 'Delete failed');
      setBusy(null);
    }
  }

  const tierLabel = tier === 'founding' ? 'Founding' : tier === 'pro' ? 'Pro' : 'Free';

  return (
    <div className="max-w-3xl">
      <h1 className="font-display text-4xl mb-6">Settings</h1>

      {err && <div className="text-sm text-bad-fg mb-4">{err}</div>}

      <div className="space-y-6">
        <div className="card p-6">
          <h2 className="font-display text-2xl mb-4">Account</h2>
          <div className="text-sm space-y-1">
            <div><span className="text-muted">Email:</span> {user?.email}</div>
          </div>
          <button className="btn-ghost mt-4" onClick={signOut}>
            <LogOut size={16} /> Sign out
          </button>
        </div>

        <div className="card p-6">
          <h2 className="font-display text-2xl mb-1">Billing</h2>
          <p className="text-muted text-sm mb-4">
            Current plan: <span className="font-medium text-ink">{tierLabel}</span>
          </p>
          {tier === 'free' ? (
            <a href="/pricing" className="btn-primary">Upgrade to Pro</a>
          ) : (
            <button className="btn-secondary" onClick={openPortal} disabled={busy === 'portal'}>
              <ExternalLink size={16} /> {busy === 'portal' ? 'Opening…' : 'Manage billing'}
            </button>
          )}
        </div>

        <div className="card p-6">
          <h2 className="font-display text-2xl mb-1">Your data</h2>
          <p className="text-muted text-sm mb-4">
            Export everything as JSON — products, ingredients, and tags.
          </p>
          <button className="btn-secondary" onClick={exportData} disabled={busy === 'export'}>
            <Download size={16} /> {busy === 'export' ? 'Preparing…' : 'Export data'}
          </button>
        </div>

        <div className="card p-6 border-bad-fg/30">
          <h2 className="font-display text-2xl mb-1 text-bad-fg">Danger zone</h2>
          <p className="text-muted text-sm mb-4">
            Delete your account and everything in it. This can't be undone.
          </p>
          <button className="btn-ghost text-bad-fg" onClick={() => setConfirmDelete(true)}>
            <Trash2 size={16} /> Delete account
          </button>
        </div>
      </div>

      <ConfirmDialog
        open={confirmDelete}
        title="Delete your account?"
        body="All products, ingredients, and subscription data will be permanently removed. You will be signed out immediately."
        confirmLabel={busy === 'delete' ? 'Deleting…' : 'Delete forever'}
        danger
        onConfirm={deleteAccount}
        onCancel={() => setConfirmDelete(false)}
      />
    </div>
  );
}
