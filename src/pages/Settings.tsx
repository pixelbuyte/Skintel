import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Download,
  ExternalLink,
  LogOut,
  Trash2,
  Shield,
  CreditCard,
  Database,
  User,
  Sparkles,
  AlertTriangle,
  Check,
  Paintbrush,
  X,
  ChevronRight,
  Pencil,
} from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { useSubscription } from '@/hooks/useSubscription';
import { ConfirmDialog } from '@/components/ConfirmDialog';
import { Avatar, AvatarBody } from '@/components/Avatar';
import {
  AVATAR_KINDS,
  AVATAR_LABELS,
  type AvatarKind,
  getAvatar,
  setAvatar,
} from '@/lib/avatar';

export default function Settings() {
  const { user, session, signOut } = useAuth();
  const { tier } = useSubscription();
  const nav = useNavigate();
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [exported, setExported] = useState(false);
  // Multi-step delete flow
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [ackData, setAckData] = useState(false);
  const [ackSub, setAckSub] = useState(false);
  const [ackPermanent, setAckPermanent] = useState(false);
  const [confirmText, setConfirmText] = useState('');
  const [deleteStep, setDeleteStep] = useState<1 | 2 | 3 | 4>(1);
  const [reason, setReason] = useState<string>('');
  const [coolingOff, setCoolingOff] = useState(false);
  const [displayName, setDisplayNameState] = useState<string>(() => {
    if (typeof window === 'undefined') return '';
    return window.localStorage.getItem('skintel:display_name:v1') ?? '';
  });
  const [editingName, setEditingName] = useState(false);
  const [nameDraft, setNameDraft] = useState(displayName);
  function saveDisplayName() {
    const v = nameDraft.trim().slice(0, 32);
    setDisplayNameState(v);
    if (typeof window !== 'undefined') {
      if (v) window.localStorage.setItem('skintel:display_name:v1', v);
      else window.localStorage.removeItem('skintel:display_name:v1');
      window.dispatchEvent(new CustomEvent('skintel:display-name-changed'));
    }
    setEditingName(false);
  }

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
      setExported(true);
      setTimeout(() => setExported(false), 2200);
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
  const isPro = tier !== 'free';
  const seed = user?.email ?? user?.id ?? 'anon';
  const [avatarKind, setAvatarKind] = useState<AvatarKind>(getAvatar());

  function pickAvatar(k: AvatarKind) {
    setAvatarKind(k);
    setAvatar(k);
  }

  return (
    <div className="max-w-3xl">
      {/* HERO */}
      <header className="mb-8 relative">
        <div className="absolute -inset-x-4 -top-4 h-28 bg-gradient-to-br from-primary/10 via-cream to-amber-50/40 blur-3xl -z-10" />
        <div className="flex items-baseline gap-3 flex-wrap">
          <h1 className="font-display text-5xl tracking-tight">Settings</h1>
          <span className="font-display italic text-3xl text-muted/70">your account</span>
        </div>
        <p className="text-muted text-sm mt-2">Manage your plan, your data, and the keys to the kingdom.</p>
      </header>

      {err && (
        <div className="mb-6 rounded-xl border border-bad-fg/30 bg-bad-bg/40 px-4 py-3 text-sm text-bad-fg flex items-center gap-2">
          <AlertTriangle size={16} />
          {err}
        </div>
      )}

      {/* PROFILE CARD */}
      <section className="card p-6 mb-4 relative overflow-hidden">
        <div className="absolute -right-6 -top-6 size-32 rounded-full bg-primary/10 blur-2xl" />
        <div className="relative flex items-center gap-4">
          <Avatar seed={seed} kind={avatarKind} size={64} className="rounded-2xl shadow-soft" />
          <div className="min-w-0 flex-1">
            <div className="text-[11px] uppercase tracking-[0.18em] text-muted mb-1">Signed in</div>
            {editingName ? (
              <div className="flex items-center gap-2">
                <input
                  autoFocus
                  value={nameDraft}
                  onChange={(e) => setNameDraft(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') saveDisplayName();
                    if (e.key === 'Escape') setEditingName(false);
                  }}
                  maxLength={32}
                  placeholder={user?.email ?? 'Your name'}
                  className="min-w-0 flex-1 px-2.5 py-1 rounded-lg border border-border bg-cream font-display text-2xl focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary"
                />
                <button
                  onClick={saveDisplayName}
                  className="size-8 shrink-0 rounded-lg bg-primary text-card inline-flex items-center justify-center"
                  aria-label="Save name"
                >
                  <Check size={15} strokeWidth={3} />
                </button>
                <button
                  onClick={() => setEditingName(false)}
                  className="size-8 shrink-0 rounded-lg border border-border text-muted inline-flex items-center justify-center hover:bg-bg"
                  aria-label="Cancel"
                >
                  <X size={15} />
                </button>
              </div>
            ) : (
              <div className="flex items-center gap-2">
                <div className="font-display text-2xl truncate">{displayName || user?.email}</div>
                <button
                  onClick={() => {
                    setNameDraft(displayName);
                    setEditingName(true);
                  }}
                  className="shrink-0 size-7 rounded-lg text-muted hover:text-primary hover:bg-primary/10 inline-flex items-center justify-center transition-colors"
                  aria-label="Edit display name"
                  title="Edit name"
                >
                  <Pencil size={14} />
                </button>
              </div>
            )}
            {displayName && !editingName && (
              <div className="text-[11px] text-muted mt-0.5 truncate">{user?.email}</div>
            )}
            <div className="flex items-center gap-2 mt-2">
              <span
                className={`inline-flex items-center gap-1.5 text-[11px] font-mono px-2.5 py-1 rounded-full border ${
                  isPro
                    ? 'bg-primary/10 text-primary border-primary/30'
                    : 'bg-card border-border text-muted'
                }`}
              >
                {isPro && <Sparkles size={11} />}
                {tierLabel} plan
              </span>
              {isPro && (
                <span className="text-[11px] font-mono text-muted">· billing active</span>
              )}
            </div>
          </div>
          <button
            onClick={signOut}
            className="hidden sm:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-border text-muted hover:text-bad-fg hover:border-bad-fg/40 transition-colors text-sm"
          >
            <LogOut size={14} />
            Sign out
          </button>
        </div>
      </section>

      {/* AVATAR PICKER */}
      <section
        className="relative overflow-hidden rounded-card border border-border p-5 mb-4 shadow-card"
        style={{
          background:
            'radial-gradient(600px circle at 0% 0%, rgba(201,129,143,0.30), transparent 55%), radial-gradient(500px circle at 100% 100%, rgba(230,169,140,0.26), transparent 55%), radial-gradient(400px circle at 50% 120%, rgba(217,199,168,0.30), transparent 60%), linear-gradient(180deg, #FFFEFA 0%, #F4EDE0 100%)',
        }}
      >
        <div
          className="pointer-events-none absolute inset-0 opacity-40"
          style={{
            backgroundImage:
              "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='80' height='80'><g fill='%23A35848' fill-opacity='0.18'><circle cx='12' cy='14' r='1'/><circle cx='62' cy='28' r='0.8'/><circle cx='34' cy='52' r='1.1'/><circle cx='70' cy='68' r='0.9'/><circle cx='20' cy='72' r='0.7'/></g></svg>\")",
            backgroundSize: '80px 80px',
          }}
        />
        <div className="relative flex items-center gap-2.5 mb-3">
          <div className="size-9 rounded-xl bg-cream border border-border inline-flex items-center justify-center text-primary shadow-soft">
            <Paintbrush size={16} />
          </div>
          <div>
            <div className="font-display text-lg leading-none">Avatar</div>
            <div className="text-[11px] text-muted mt-1">
              14 styles — monograms, botanicals, gems, light & more. Saved locally.
            </div>
          </div>
        </div>
        <div className="relative grid grid-cols-3 sm:grid-cols-6 gap-2">
          {AVATAR_KINDS.map((k) => {
            const active = avatarKind === k;
            return (
              <button
                key={k}
                onClick={() => pickAvatar(k)}
                className={`group relative rounded-xl p-2 border transition-all active:scale-95 backdrop-blur-sm ${
                  active
                    ? 'border-primary bg-cream/90 shadow-soft ring-2 ring-primary/30'
                    : 'border-white/60 bg-cream/60 hover:bg-cream/85 hover:border-primary/40'
                }`}
                aria-pressed={active}
              >
                <span className="inline-flex items-center justify-center overflow-hidden rounded-lg size-12 mx-auto">
                  <AvatarBody kind={k} seed={seed} size={48} />
                </span>
                <div className="text-[10px] uppercase tracking-wider text-muted mt-1.5 font-mono">
                  {AVATAR_LABELS[k]}
                </div>
                {active && (
                  <span className="absolute -top-1.5 -right-1.5 size-5 rounded-full bg-primary text-card inline-flex items-center justify-center shadow-soft">
                    <Check size={11} strokeWidth={3} />
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </section>

      {/* BILLING + DATA — 2col */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
        <SectionCard
          icon={<CreditCard size={18} />}
          title="Billing"
          subtitle={isPro ? 'Manage in Stripe' : 'Upgrade for full scanner'}
        >
          {tier === 'free' ? (
            <button onClick={() => nav('/pricing')} className="btn-primary w-full">
              <Sparkles size={14} /> Upgrade to Pro
            </button>
          ) : (
            <button
              className="btn-secondary w-full"
              onClick={openPortal}
              disabled={busy === 'portal'}
            >
              <ExternalLink size={14} /> {busy === 'portal' ? 'Opening…' : 'Manage billing'}
            </button>
          )}
          <ul className="mt-3 space-y-1.5 text-[12px] text-muted">
            <li className="inline-flex items-center gap-1.5"><Check size={11} className="text-primary" /> Cancel anytime</li>
            <li className="inline-flex items-center gap-1.5"><Check size={11} className="text-primary" /> Stripe-secured</li>
            <li className="inline-flex items-center gap-1.5"><Check size={11} className="text-primary" /> Receipts via email</li>
          </ul>
        </SectionCard>

        <SectionCard
          icon={<Database size={18} />}
          title="Your data"
          subtitle="Export as JSON · no lock-in"
        >
          <button
            className="btn-secondary w-full"
            onClick={exportData}
            disabled={busy === 'export'}
          >
            <Download size={14} />
            {busy === 'export' ? 'Preparing…' : exported ? 'Downloaded ✓' : 'Export everything'}
          </button>
          <ul className="mt-3 space-y-1.5 text-[12px] text-muted">
            <li className="inline-flex items-center gap-1.5"><Check size={11} className="text-primary" /> Products + ingredients</li>
            <li className="inline-flex items-center gap-1.5"><Check size={11} className="text-primary" /> Outcomes + tags</li>
            <li className="inline-flex items-center gap-1.5"><Check size={11} className="text-primary" /> Journal entries</li>
          </ul>
        </SectionCard>
      </div>

      {/* PRIVACY STRIP */}
      <section className="card p-5 mb-4 bg-gradient-to-br from-card to-cream">
        <div className="flex items-start gap-3">
          <div className="size-9 shrink-0 rounded-xl bg-emerald-100 text-emerald-700 inline-flex items-center justify-center">
            <Shield size={16} />
          </div>
          <div className="min-w-0">
            <div className="font-display text-lg">Private by default</div>
            <p className="text-sm text-muted mt-0.5">
              Postgres row-level security locks every record to your user ID. Never sold, never shared with brands.
            </p>
          </div>
        </div>
      </section>

      {/* MOBILE SIGN OUT */}
      <button
        onClick={signOut}
        className="sm:hidden w-full mb-4 inline-flex items-center justify-center gap-2 px-3 py-2.5 rounded-xl border border-border text-muted hover:text-bad-fg hover:border-bad-fg/40 transition-colors text-sm"
      >
        <LogOut size={14} />
        Sign out
      </button>

      {/* DANGER ZONE — multi-step delete */}
      <DeletePanel
        open={deleteOpen}
        onOpen={() => {
          setDeleteOpen(true);
          setDeleteStep(1);
          setAckData(false);
          setAckSub(false);
          setAckPermanent(false);
          setReason('');
          setCoolingOff(false);
          setConfirmText('');
        }}
        onClose={() => setDeleteOpen(false)}
        step={deleteStep}
        setStep={setDeleteStep}
        ackData={ackData}
        ackSub={ackSub}
        ackPermanent={ackPermanent}
        setAckData={setAckData}
        setAckSub={setAckSub}
        setAckPermanent={setAckPermanent}
        reason={reason}
        setReason={setReason}
        coolingOff={coolingOff}
        setCoolingOff={setCoolingOff}
        confirmText={confirmText}
        setConfirmText={setConfirmText}
        email={user?.email ?? ''}
        onExport={exportData}
        onArrive={() => setConfirmDelete(true)}
      />

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

function SectionCard({
  icon,
  title,
  subtitle,
  children,
}: {
  icon: React.ReactNode;
  title: string;
  subtitle: string;
  children: React.ReactNode;
}) {
  return (
    <div className="card p-5">
      <div className="flex items-center gap-2.5 mb-3">
        <div className="size-9 rounded-xl bg-card border border-border inline-flex items-center justify-center text-ink/80">
          {icon}
        </div>
        <div className="min-w-0">
          <div className="font-display text-lg leading-none">{title}</div>
          <div className="text-[11px] text-muted mt-1">{subtitle}</div>
        </div>
      </div>
      {children}
    </div>
  );
}

// Silence unused import (kept for future user-detail panels).
void User;

const DELETE_REASONS = [
  'Too expensive',
  'Not using it enough',
  'Found a better app',
  'Privacy concerns',
  'Just taking a break',
  'Other',
];

function DeletePanel(props: {
  open: boolean;
  onOpen: () => void;
  onClose: () => void;
  step: 1 | 2 | 3 | 4;
  setStep: (s: 1 | 2 | 3 | 4) => void;
  ackData: boolean;
  ackSub: boolean;
  ackPermanent: boolean;
  setAckData: (v: boolean) => void;
  setAckSub: (v: boolean) => void;
  setAckPermanent: (v: boolean) => void;
  reason: string;
  setReason: (v: string) => void;
  coolingOff: boolean;
  setCoolingOff: (v: boolean) => void;
  confirmText: string;
  setConfirmText: (v: string) => void;
  email: string;
  onExport: () => void;
  onArrive: () => void;
}) {
  const {
    open,
    onOpen,
    onClose,
    step,
    setStep,
    ackData,
    ackSub,
    ackPermanent,
    setAckData,
    setAckSub,
    setAckPermanent,
    reason,
    setReason,
    coolingOff,
    setCoolingOff,
    confirmText,
    setConfirmText,
    email,
    onExport,
    onArrive,
  } = props;

  if (!open) {
    return (
      <section className="rounded-2xl border border-border bg-card p-5 mt-2">
        <div className="flex items-center gap-2.5 mb-3">
          <div className="size-9 shrink-0 rounded-xl border border-border bg-cream inline-flex items-center justify-center text-muted">
            <AlertTriangle size={16} />
          </div>
          <div>
            <div className="font-display text-lg leading-none">Close account</div>
            <div className="text-[11px] text-muted mt-1">Permanent · this can't be undone</div>
          </div>
        </div>
        <p className="text-sm text-muted mb-4 leading-relaxed">
          Deletes your products, ingredient tags, journal entries, and any active subscription. We don't keep backups.
        </p>
        <button
          className="inline-flex items-center gap-2 px-3.5 py-2 rounded-lg border border-bad-fg/40 text-bad-fg hover:bg-bad-fg hover:text-cream hover:border-bad-fg transition-colors text-sm"
          onClick={onOpen}
        >
          <Trash2 size={14} /> Start account deletion
        </button>
      </section>
    );
  }

  const allAcked = ackData && ackSub && ackPermanent;
  const typedOk = confirmText.trim().toUpperCase() === 'DELETE MY ACCOUNT';

  return (
    <section className="rounded-2xl border border-bad-fg/40 bg-card p-5 mt-2 animate-in fade-in duration-300">
      {/* Header w/ close */}
      <div className="flex items-center gap-2.5 mb-4">
        <div className="size-9 shrink-0 rounded-xl bg-bad-bg/60 text-bad-fg inline-flex items-center justify-center">
          <AlertTriangle size={16} />
        </div>
        <div className="min-w-0 flex-1">
          <div className="font-display text-lg leading-none">Close account</div>
          <div className="text-[11px] text-muted mt-1">Step {step} of 4 · cancel anytime</div>
        </div>
        <button
          onClick={onClose}
          className="size-8 rounded-lg text-muted hover:bg-bg inline-flex items-center justify-center"
          aria-label="Cancel deletion"
        >
          <X size={16} />
        </button>
      </div>

      {/* Progress dots */}
      <div className="flex items-center gap-1.5 mb-5">
        {[1, 2, 3, 4].map((n) => (
          <span
            key={n}
            className={`h-1 flex-1 rounded-full transition-colors ${
              step >= n ? 'bg-bad-fg/70' : 'bg-border'
            }`}
          />
        ))}
      </div>

      {/* STEP 1 — Export reminder */}
      {step === 1 && (
        <div className="space-y-4">
          <div>
            <div className="text-[11px] uppercase tracking-[0.18em] text-muted mb-1.5">
              Step 1 · Export first
            </div>
            <h3 className="font-display text-xl">Have you exported your data?</h3>
          </div>
          <p className="text-sm text-muted leading-relaxed">
            Once you delete, your products, ingredient correlations, journal entries, and tags are gone. We don't keep backups and we can't restore them. Download an offline copy now if you might want it later.
          </p>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={onExport}
              className="inline-flex items-center gap-2 px-3.5 py-2 rounded-lg border border-border bg-cream hover:bg-bg transition-colors text-sm"
            >
              <Download size={14} />
              Export my data first
            </button>
            <button
              type="button"
              onClick={() => setStep(2)}
              className="inline-flex items-center gap-2 px-3.5 py-2 rounded-lg bg-ink text-cream hover:opacity-90 transition-opacity text-sm ml-auto"
            >
              I've handled it
              <ChevronRight size={14} />
            </button>
          </div>
        </div>
      )}

      {/* STEP 2 — Reason + cooling-off */}
      {step === 2 && (
        <div className="space-y-4">
          <div>
            <div className="text-[11px] uppercase tracking-[0.18em] text-muted mb-1.5">
              Step 2 · Before you go
            </div>
            <h3 className="font-display text-xl">Why are you leaving?</h3>
          </div>

          <div className="space-y-2">
            {DELETE_REASONS.map((r) => {
              const picked = reason === r;
              return (
                <label
                  key={r}
                  className={`flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-colors ${
                    picked ? 'border-primary/50 bg-primary/5' : 'border-border bg-cream hover:bg-bg/60'
                  }`}
                >
                  <span
                    className={`size-4 rounded-full border inline-flex items-center justify-center shrink-0 ${
                      picked ? 'border-primary' : 'border-border'
                    }`}
                  >
                    {picked && <span className="size-2 rounded-full bg-primary" />}
                  </span>
                  <span className="text-sm">{r}</span>
                  <input
                    type="radio"
                    name="delete-reason"
                    className="sr-only"
                    checked={picked}
                    onChange={() => setReason(r)}
                  />
                </label>
              );
            })}
          </div>

          <AckRow
            checked={coolingOff}
            onChange={setCoolingOff}
            label="I've taken a moment to think about it — I still want to permanently delete my account."
          />

          <div className="flex flex-wrap gap-2 pt-2">
            <button
              type="button"
              onClick={() => setStep(1)}
              className="inline-flex items-center gap-1 px-3 py-2 rounded-lg text-muted hover:text-ink text-sm"
            >
              ← Back
            </button>
            <button
              type="button"
              disabled={!reason || !coolingOff}
              onClick={() => setStep(3)}
              className="inline-flex items-center gap-2 px-3.5 py-2 rounded-lg bg-ink text-cream disabled:opacity-40 disabled:cursor-not-allowed hover:opacity-90 transition-opacity text-sm ml-auto"
            >
              Continue
              <ChevronRight size={14} />
            </button>
          </div>
        </div>
      )}

      {/* STEP 3 — Acknowledgments */}
      {step === 3 && (
        <div className="space-y-4">
          <div>
            <div className="text-[11px] uppercase tracking-[0.18em] text-muted mb-1.5">
              Step 3 · Acknowledge
            </div>
            <h3 className="font-display text-xl">Confirm you understand</h3>
          </div>

          <div className="space-y-2">
            <AckRow
              checked={ackData}
              onChange={setAckData}
              label="I understand my products, ingredient data, journal entries, and tags will be permanently erased."
            />
            <AckRow
              checked={ackSub}
              onChange={setAckSub}
              label="I understand any active subscription will be cancelled and I won't be refunded for the current billing period."
            />
            <AckRow
              checked={ackPermanent}
              onChange={setAckPermanent}
              label="I understand this action cannot be reversed. Signing up again starts a fresh account."
            />
          </div>

          <div className="flex flex-wrap gap-2 pt-2">
            <button
              type="button"
              onClick={() => setStep(2)}
              className="inline-flex items-center gap-1 px-3 py-2 rounded-lg text-muted hover:text-ink text-sm"
            >
              ← Back
            </button>
            <button
              type="button"
              disabled={!allAcked}
              onClick={() => setStep(4)}
              className="inline-flex items-center gap-2 px-3.5 py-2 rounded-lg bg-ink text-cream disabled:opacity-40 disabled:cursor-not-allowed hover:opacity-90 transition-opacity text-sm ml-auto"
            >
              Continue
              <ChevronRight size={14} />
            </button>
          </div>
        </div>
      )}

      {/* STEP 4 — Type to confirm */}
      {step === 4 && (
        <div className="space-y-4">
          <div>
            <div className="text-[11px] uppercase tracking-[0.18em] text-muted mb-1.5">
              Step 4 · Final confirmation
            </div>
            <h3 className="font-display text-xl">Last chance, {email.split('@')[0]}.</h3>
          </div>
          <p className="text-sm text-muted leading-relaxed">
            Type <span className="font-mono text-bad-fg bg-bad-bg/40 px-1.5 py-0.5 rounded">DELETE MY ACCOUNT</span> below to enable the final button.
          </p>
          <input
            type="text"
            value={confirmText}
            onChange={(e) => setConfirmText(e.target.value)}
            placeholder="DELETE MY ACCOUNT"
            autoComplete="off"
            spellCheck={false}
            className="w-full px-3.5 py-2.5 rounded-lg border border-border bg-cream text-ink font-mono placeholder:text-muted/60 focus:outline-none focus:ring-2 focus:ring-bad-fg/30 focus:border-bad-fg transition"
          />

          <div className="flex flex-wrap gap-2 pt-2">
            <button
              type="button"
              onClick={() => setStep(3)}
              className="inline-flex items-center gap-1 px-3 py-2 rounded-lg text-muted hover:text-ink text-sm"
            >
              ← Back
            </button>
            <button
              type="button"
              onClick={onClose}
              className="inline-flex items-center gap-2 px-3.5 py-2 rounded-lg border border-border bg-cream hover:bg-bg transition-colors text-sm"
            >
              Cancel — keep my account
            </button>
            <button
              type="button"
              disabled={!typedOk}
              onClick={onArrive}
              className="inline-flex items-center gap-2 px-3.5 py-2 rounded-lg bg-bad-fg text-cream disabled:opacity-40 disabled:cursor-not-allowed hover:bg-bad-fg/85 transition-opacity text-sm ml-auto"
            >
              <Trash2 size={14} />
              Permanently delete
            </button>
          </div>
        </div>
      )}
    </section>
  );
}

function AckRow({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label: string;
}) {
  return (
    <label
      className={`flex items-start gap-3 p-3 rounded-xl border cursor-pointer transition-colors ${
        checked ? 'border-bad-fg/40 bg-bad-bg/30' : 'border-border bg-cream hover:bg-bg/60'
      }`}
    >
      <span
        className={`mt-0.5 size-5 rounded-md border inline-flex items-center justify-center shrink-0 transition-colors ${
          checked ? 'border-bad-fg bg-bad-fg text-cream' : 'border-border bg-cream'
        }`}
      >
        {checked && <Check size={13} strokeWidth={3} />}
      </span>
      <span className="text-sm leading-relaxed">{label}</span>
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="sr-only"
      />
    </label>
  );
}
