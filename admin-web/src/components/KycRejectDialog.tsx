import { useState } from 'react';
import { ApiError } from '../api/client';
import { useModalA11y } from './useModalA11y';

/** Mirrors the backend's `reason_code` enum in `reviewKycSchema`
 * (src/modules/admin/actions.ts) — keep the two in sync. Each non-"other"
 * value has a fixed, localized phrase the user sees (src/i18n/notifications.ts);
 * "other" is the escape hatch and requires a typed explanation instead. */
export type KycRejectReason = 'photo_unclear' | 'info_mismatch' | 'selfie_mismatch' | 'other';

export const KYC_REJECT_REASONS: { value: KycRejectReason; label: string }[] = [
  { value: 'photo_unclear', label: "Photo wasn't clear" },
  { value: 'info_mismatch', label: "ID photo and the info entered don't match" },
  { value: 'selfie_mismatch', label: "Selfie doesn't match the ID photo" },
  { value: 'other', label: 'Other (explain below)' },
];

interface KycRejectDialogProps {
  open: boolean;
  onClose: () => void;
  onConfirm: (input: { reason_code: KycRejectReason; note?: string }) => Promise<void>;
}

/** Reject flow for an ID check — a fixed reason is required so the user gets
 * a clear, standardized, localized explanation of what to fix (rather than
 * whatever free text an admin happens to type); "Other" is still available
 * for anything the fixed reasons don't cover. */
export function KycRejectDialog({ open, onClose, onConfirm }: KycRejectDialogProps) {
  const [reasonCode, setReasonCode] = useState<KycRejectReason>('photo_unclear');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const modalRef = useModalA11y(open, onClose);

  if (!open) return null;

  const noteRequired = reasonCode === 'other';
  const noteMissing = noteRequired && note.trim().length < 3;

  async function submit() {
    if (noteMissing) return;
    setBusy(true);
    setError(null);
    try {
      await onConfirm({ reason_code: reasonCode, note: note.trim() || undefined });
      setReasonCode('photo_unclear');
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
      <div
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-label="Reject ID check"
        tabIndex={-1}
        ref={modalRef}
        onClick={(e) => e.stopPropagation()}
      >
        <h2>Reject ID check</h2>
        <p className="modal-description">
          The user is notified with this reason so they know what to fix before resubmitting.
        </p>
        <label>
          Reason
          <select value={reasonCode} onChange={(e) => setReasonCode(e.target.value as KycRejectReason)} autoFocus>
            {KYC_REJECT_REASONS.map((r) => (
              <option key={r.value} value={r.value}>
                {r.label}
              </option>
            ))}
          </select>
        </label>
        {noteRequired && (
          <label className="modal-reason">
            Explain what's wrong
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              rows={3}
              placeholder="Why this is being rejected…"
            />
            {noteMissing && <span className="field-hint field-hint-error">A short explanation is required.</span>}
          </label>
        )}
        {error && <p className="form-error">{error}</p>}
        <div className="modal-actions">
          <button type="button" className="btn btn-ghost" onClick={onClose} disabled={busy}>
            Cancel
          </button>
          <button type="button" className="btn btn-danger" onClick={submit} disabled={busy || noteMissing}>
            {busy ? 'Working…' : 'Reject'}
          </button>
        </div>
      </div>
    </div>
  );
}
