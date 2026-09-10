import { useState } from 'react';
import { ApiError } from '../api/client';

interface MoneyActionDialogProps {
  open: boolean;
  title: string;
  description?: string;
  confirmLabel: string;
  onConfirm: (input: { method: string; reference: string; note?: string }) => Promise<void>;
  onClose: () => void;
}

/** Shared shape for "record a payout" / "record a refund" — both need a
 * method + reference (proof the money actually moved out of band) plus an
 * optional note. See POST /api/payments/payout and
 * POST /api/admin/orders/:id/refund. */
export function MoneyActionDialog({ open, title, description, confirmLabel, onConfirm, onClose }: MoneyActionDialogProps) {
  const [method, setMethod] = useState('bank_transfer');
  const [reference, setReference] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  async function submit() {
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
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{title}</h2>
        {description && <p className="modal-description">{description}</p>}
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
          Reference (transaction id, confirmation code…)
          <input value={reference} onChange={(e) => setReference(e.target.value)} autoFocus />
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
          <button type="button" className="btn btn-primary" onClick={submit} disabled={busy || reference.trim().length === 0}>
            {busy ? 'Working…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
