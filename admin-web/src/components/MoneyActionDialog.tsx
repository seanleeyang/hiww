import { useState } from 'react';
import { ApiError } from '../api/client';
import { useModalA11y } from './useModalA11y';

interface MoneyActionDialogProps {
  open: boolean;
  title: string;
  description?: string;
  /** The already-formatted amount (e.g. "฿4,500.00") — restated prominently
   * so the admin has a final on-screen check of the figure they're
   * attesting to, since it's easy to lose track of once the row's table is
   * behind the modal. */
  amount: string;
  /** What the amount is for — the order's item description, shown next to
   * the amount so two similarly-priced orders can't be confused. */
  context: string;
  /** Read-only "where this is going" line — e.g. the traveller's own bank
   * account for a payout. Never an editable field: the destination account
   * always comes from the recipient's own profile server-side, not from
   * anything typed into this dialog, so a rogue admin can't redirect a
   * payout by editing a form. */
  destination?: { label: string; value: string } | null;
  confirmLabel: string;
  onConfirm: (input: { method: string; reference: string; note?: string }) => Promise<void>;
  onClose: () => void;
}

/** Shared shape for "record a payout" / "record a refund" — both need a
 * method + reference (proof the money actually moved out of band) plus an
 * optional note. See POST /api/payments/payout and
 * POST /api/admin/orders/:id/refund. */
export function MoneyActionDialog({
  open,
  title,
  description,
  amount,
  context,
  destination,
  confirmLabel,
  onConfirm,
  onClose,
}: MoneyActionDialogProps) {
  const [method, setMethod] = useState('bank_transfer');
  const [reference, setReference] = useState('');
  const [note, setNote] = useState('');
  const [referenceTouched, setReferenceTouched] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const modalRef = useModalA11y(open, onClose);

  if (!open) return null;

  const referenceMissing = reference.trim().length === 0;

  async function submit() {
    setReferenceTouched(true);
    if (referenceMissing) return;
    setBusy(true);
    setError(null);
    try {
      await onConfirm({ method, reference: reference.trim(), note: note.trim() || undefined });
      setReference('');
      setNote('');
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
        {description && <p className="modal-description">{description}</p>}
        <div className="modal-amount">
          <span className="modal-amount-value">{amount}</span>
          <span className="modal-amount-context">{context}</span>
        </div>
        {destination && (
          <div className="modal-description" style={{ fontSize: '0.9em' }}>
            <strong>{destination.label}:</strong> {destination.value}
          </div>
        )}
        <label>
          Method
          <select value={method} onChange={(e) => setMethod(e.target.value)}>
            <option value="bank_transfer">Bank transfer</option>
            <option value="promptpay">PromptPay</option>
            <option value="wise">Wise</option>
            <option value="other">Other</option>
          </select>
        </label>
        <label>
          Reference (transaction id, confirmation code…) <span className="required-mark">Required</span>
          <input
            value={reference}
            onChange={(e) => setReference(e.target.value)}
            onBlur={() => setReferenceTouched(true)}
            autoFocus
          />
          {referenceTouched && referenceMissing && (
            <span className="field-hint field-hint-error">Enter a reference before recording this.</span>
          )}
        </label>
        <label>
          Note (optional)
          <input value={note} onChange={(e) => setNote(e.target.value)} />
        </label>
        {error && <p className="form-error">{error}</p>}
        <div className="modal-actions">
          <button type="button" className="btn btn-ghost" onClick={onClose} disabled={busy}>
            Cancel
          </button>
          <button type="button" className="btn btn-primary" onClick={submit} disabled={busy}>
            {busy ? 'Working…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
