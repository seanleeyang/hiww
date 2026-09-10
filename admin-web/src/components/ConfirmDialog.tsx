import { useState, type ReactNode } from 'react';
import { ApiError } from '../api/client';
import { useModalA11y } from './useModalA11y';

interface ReasonField {
  label: string;
  placeholder?: string;
  minLength?: number;
}

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description?: ReactNode;
  /** When present, the dialog collects free text (e.g. a cancel reason) and
   * passes it to `onConfirm`. */
  reason?: ReasonField;
  confirmLabel?: string;
  danger?: boolean;
  onConfirm: (reason?: string) => Promise<void>;
  onClose: () => void;
}

/** A single reusable action-confirmation modal — every destructive or
 * state-changing admin action (cancel order, hide review, remove listing…)
 * goes through this so the "are you sure, and why" pattern stays consistent. */
export function ConfirmDialog({
  open,
  title,
  description,
  reason,
  confirmLabel = 'Confirm',
  danger,
  onConfirm,
  onClose,
}: ConfirmDialogProps) {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const modalRef = useModalA11y(open, onClose);

  if (!open) return null;

  const minLength = reason?.minLength ?? 0;
  const remaining = minLength - text.trim().length;
  const reasonTooShort = Boolean(reason) && remaining > 0;

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await onConfirm(reason ? text.trim() : undefined);
      setText('');
      onClose();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Something went wrong');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" role="dialog" aria-modal="true" aria-label={title} tabIndex={-1} ref={modalRef} onClick={(e) => e.stopPropagation()}>
        <h2>{title}</h2>
        {description && <div className="modal-description">{description}</div>}
        {reason && (
          <label className="modal-reason">
            {reason.label}
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder={reason.placeholder}
              rows={3}
              autoFocus
            />
            {minLength > 0 && (
              <span className={remaining > 0 ? 'field-hint' : 'field-hint field-hint-ok'}>
                {remaining > 0 ? `${remaining} more character${remaining === 1 ? '' : 's'} needed` : 'Looks good'}
              </span>
            )}
          </label>
        )}
        {error && <p className="form-error">{error}</p>}
        <div className="modal-actions">
          <button type="button" className="btn btn-ghost" onClick={onClose} disabled={busy}>
            Cancel
          </button>
          <button
            type="button"
            className={danger ? 'btn btn-danger' : 'btn btn-primary'}
            onClick={submit}
            disabled={busy || reasonTooShort}
          >
            {busy ? 'Working…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
