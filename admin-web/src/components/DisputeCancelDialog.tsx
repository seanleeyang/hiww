import { useState } from 'react';
import { ApiError } from '../api/client';
import { useModalA11y } from './useModalA11y';

const OTHER = 'other';

/** Canned phrases for the common ways a disputed order actually gets
 * cancelled — picking one fills the reason box with it (still editable);
 * "Other" clears it for a free-typed explanation instead. This is purely a
 * UI convenience: the backend still just receives one free-text `reason`
 * string, exactly as before — no schema change, so it stays whatever a
 * plain `/admin/orders/:id/cancel` cancellation (outside a dispute) already
 * expects. */
const DISPUTE_CANCEL_REASONS: { value: string; label: string }[] = [
  { value: 'Item was never shipped by the traveler', label: 'Item was never shipped' },
  { value: 'Item arrived damaged or not as described', label: 'Item damaged / not as described' },
  { value: 'Shopper and traveler mutually agreed to cancel', label: 'Mutual agreement to cancel' },
  { value: 'Suspected fraudulent activity on this order', label: 'Suspected fraud' },
  { value: OTHER, label: 'Other (explain below)' },
];

interface DisputeCancelDialogProps {
  open: boolean;
  onClose: () => void;
  onConfirm: (reason: string) => Promise<void>;
}

export function DisputeCancelDialog({ open, onClose, onConfirm }: DisputeCancelDialogProps) {
  const [preset, setPreset] = useState(DISPUTE_CANCEL_REASONS[0].value);
  const [customReason, setCustomReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const modalRef = useModalA11y(open, onClose);

  if (!open) return null;

  const isOther = preset === OTHER;
  const reason = isOther ? customReason.trim() : preset;
  const reasonTooShort = reason.length < 10;

  async function submit() {
    if (reasonTooShort) return;
    setBusy(true);
    setError(null);
    try {
      await onConfirm(reason);
      setPreset(DISPUTE_CANCEL_REASONS[0].value);
      setCustomReason('');
      onClose();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Something went wrong');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-label="Cancel order & resolve dispute"
        tabIndex={-1}
        ref={modalRef}
        onClick={(e) => e.stopPropagation()}
      >
        <h2>Cancel order &amp; resolve dispute</h2>
        <p className="modal-description">
          Cancels the order (any status short of already paid out) and resolves this dispute with the same reason.
          Both parties are notified; if payment had been confirmed, every admin gets a refund-owed notice.
        </p>
        <label>
          Reason
          <select value={preset} onChange={(e) => setPreset(e.target.value)} autoFocus>
            {DISPUTE_CANCEL_REASONS.map((r) => (
              <option key={r.value} value={r.value}>
                {r.label}
              </option>
            ))}
          </select>
        </label>
        {isOther && (
          <label className="modal-reason">
            Explain why
            <textarea
              value={customReason}
              onChange={(e) => setCustomReason(e.target.value)}
              rows={3}
              placeholder="Why the order is being cancelled…"
            />
            {reasonTooShort && <span className="field-hint field-hint-error">At least 10 characters.</span>}
          </label>
        )}
        {error && <p className="form-error">{error}</p>}
        <div className="modal-actions">
          <button type="button" className="btn btn-ghost" onClick={onClose} disabled={busy}>
            Cancel
          </button>
          <button type="button" className="btn btn-danger" onClick={submit} disabled={busy || reasonTooShort}>
            {busy ? 'Working…' : 'Cancel order'}
          </button>
        </div>
      </div>
    </div>
  );
}
