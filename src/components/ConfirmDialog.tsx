import type { ReactNode } from 'react';

export function ConfirmDialog({
  open,
  title,
  body,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  danger,
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  body: ReactNode;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/30 p-4" onClick={onCancel}>
      <div className="card p-6 max-w-md w-full" onClick={(e) => e.stopPropagation()}>
        <h3 className="font-display text-xl mb-2">{title}</h3>
        <div className="text-muted text-sm mb-5">{body}</div>
        <div className="flex justify-end gap-2">
          <button className="btn-secondary" onClick={onCancel}>{cancelLabel}</button>
          <button
            className={danger ? 'btn bg-bad-fg text-card hover:opacity-90' : 'btn-primary'}
            onClick={onConfirm}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
