import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client';
import type { UserViolation } from '../api/types';
import { useModalA11y } from './useModalA11y';
import { dateTime } from '../lib/format';

interface ViolationHistoryDialogProps {
  userId: string | null;
  userName?: string;
  onClose: () => void;
}

/** Read-only — every strike on a user's record, most recent first, so an
 * admin can see what already happened before deciding whether (and how) to
 * escalate a new one. Fetched fresh each time it opens rather than eagerly
 * for every row in the Users table. */
export function ViolationHistoryDialog({ userId, userName, onClose }: ViolationHistoryDialogProps) {
  const open = userId !== null;
  const modalRef = useModalA11y(open, onClose);
  const history = useQuery({
    queryKey: ['user-violations', userId],
    queryFn: () => api.get<{ items: UserViolation[] }>(`/admin/users/${userId}/violations`),
    enabled: open,
  });

  if (!open) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-label="Violation history"
        tabIndex={-1}
        ref={modalRef}
        onClick={(e) => e.stopPropagation()}
      >
        <h2>Violation history{userName ? ` — ${userName}` : ''}</h2>
        {history.isLoading && <p className="muted">Loading…</p>}
        {history.isError && <p className="form-error">Could not load this account's history.</p>}
        {history.data && history.data.items.length === 0 && <p className="muted">No violations on record.</p>}
        {history.data && history.data.items.length > 0 && (
          <ol style={{ margin: '8px 0', paddingLeft: 20 }}>
            {history.data.items.map((v, i) => (
              <li key={v.id} style={{ marginBottom: 8 }}>
                <strong>Strike {history.data!.items.length - i}</strong> — {dateTime(v.created_at)}
                {v.issued_by_name ? ` · by ${v.issued_by_name}` : ''}
                <div className="muted">{v.reason}</div>
              </li>
            ))}
          </ol>
        )}
        <div className="modal-actions">
          <button type="button" className="btn btn-ghost" onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
