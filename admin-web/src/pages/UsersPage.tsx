import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from '../api/client';
import type { AdminUser } from '../api/types';
import { ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { KycRejectDialog, type KycRejectReason } from '../components/KycRejectDialog';
import { ViolationHistoryDialog } from '../components/ViolationHistoryDialog';
import { useToast } from '../components/Toast';
import { idCheckLabel, riskStatusLabel, riskStatusTone } from '../lib/status';
import { dateTime } from '../lib/format';

export function UsersPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const users = useQuery({ queryKey: ['admin-users'], queryFn: () => api.get<{ users: AdminUser[] }>('/admin/users') });
  const [flagging, setFlagging] = useState<AdminUser | null>(null);
  const [rejecting, setRejecting] = useState<AdminUser | null>(null);
  const [strikingUser, setStrikingUser] = useState<AdminUser | null>(null);
  const [historyUser, setHistoryUser] = useState<AdminUser | null>(null);
  const [search, setSearch] = useState('');
  const [riskFilter, setRiskFilter] = useState('');
  // This table lists every user regardless of ID-check status (unlike the ID
  // Checks page's pending-only queue), so a decided row sticks around with
  // one of Approve/Reject always still clickable -- e.g. reject someone,
  // and "Approve ID" is right there to accidentally re-approve them before
  // they've even resubmitted anything. Once a decision exists, both buttons
  // collapse into a single deliberate "Reconsider" step per row; only after
  // that does the flip action (whichever one still makes sense) reappear.
  const [reconsideringIds, setReconsideringIds] = useState<Set<string>>(new Set());

  const onError = (err: unknown) => toast(err instanceof ApiError ? err.message : 'Something went wrong', 'error');

  const review = useMutation({
    mutationFn: ({
      userId,
      status,
      reason_code,
      note,
    }: {
      userId: string;
      status: 'approved' | 'rejected';
      reason_code?: KycRejectReason;
      note?: string;
    }) => api.post(`/admin/users/${userId}/kyc-review`, { status, reason_code, note }),
    onSuccess: (_data, variables) => {
      setReconsideringIds((prev) => {
        const next = new Set(prev);
        next.delete(variables.userId);
        return next;
      });
      qc.invalidateQueries({ queryKey: ['admin-users'] });
      toast(variables.status === 'approved' ? 'ID check approved' : 'ID check rejected — the user has been notified why');
    },
    onError,
  });
  const flag = useMutation({
    mutationFn: ({ userId, risk_status, reason }: { userId: string; risk_status: string; reason: string }) =>
      api.post(`/admin/users/${userId}/flag`, { risk_status, reason }),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ['admin-users'] });
      toast(variables.risk_status === 'clear' ? 'Flag cleared' : 'Account flagged');
    },
    onError,
  });
  const strike = useMutation({
    mutationFn: ({ userId, reason }: { userId: string; reason: string }) =>
      api.post<{ count: number; risk_status: string; suspended_until: string | null }>(
        `/admin/users/${userId}/violations`,
        { reason }
      ),
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ['admin-users'] });
      const ordinal = data.count === 1 ? '1st' : data.count === 2 ? '2nd' : `${data.count}${data.count === 3 ? 'rd' : 'th'}`;
      const consequence =
        data.risk_status === 'flagged'
          ? 'warned (no lockout yet)'
          : data.suspended_until
            ? `suspended until ${new Date(data.suspended_until).toLocaleDateString()}`
            : 'permanently banned';
      toast(`${ordinal} strike recorded — account ${consequence}`, data.risk_status === 'restricted' ? 'error' : 'success');
    },
    onError,
  });

  const filtered = useMemo(() => {
    let items = users.data?.users ?? [];
    if (riskFilter) items = items.filter((u) => u.risk_status === riskFilter);
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter(
      (u) =>
        u.full_name.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q) ||
        u.membership_id.toLowerCase().includes(q)
    );
  }, [users.data, search, riskFilter]);

  if (users.isLoading) return <LoadingState />;
  if (users.isError) return <ErrorState error={users.error} onRetry={() => users.refetch()} />;

  return (
    <div>
      <PageHeader title="Users" subtitle="Every account. Review ID checks and flag risky accounts." />

      <div style={{ display: 'flex', gap: 12, marginBottom: 16, flexWrap: 'wrap' }}>
        <input
          placeholder="Search by name, email, or member ID…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ maxWidth: 320 }}
        />
        <select value={riskFilter} onChange={(e) => setRiskFilter(e.target.value)}>
          <option value="">All risk levels</option>
          <option value="clear">Clear</option>
          <option value="flagged">Flagged</option>
          <option value="restricted">Restricted</option>
        </select>
      </div>

      <table>
        <thead>
          <tr>
            <th>User</th>
            <th>Member ID</th>
            <th>Type</th>
            <th>Role</th>
            <th>ID check</th>
            <th>Risk</th>
            <th>Strikes</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {filtered.map((u) => (
            <tr key={u.id}>
              <td>
                {u.full_name}
                <div className="muted">{u.email}</div>
              </td>
              <td className="muted">{u.membership_id}</td>
              <td>{u.user_type}</td>
              <td>{u.role}</td>
              <td>
                <StatusPill
                  label={idCheckLabel(u.kyc_status)}
                  tone={u.kyc_status === 'approved' ? 'positive' : u.kyc_status === 'rejected' ? 'negative' : 'warning'}
                />
              </td>
              <td>
                <StatusPill label={riskStatusLabel(u.risk_status)} tone={riskStatusTone(u.risk_status)} />
                {u.risk_status === 'restricted' && (
                  <div className="muted" style={{ fontSize: 12 }}>
                    {u.suspended_until ? `Until ${dateTime(u.suspended_until)}` : 'Permanent'}
                  </div>
                )}
              </td>
              <td>
                <button
                  type="button"
                  className="btn btn-small btn-ghost"
                  onClick={() => setHistoryUser(u)}
                  title="View violation history"
                >
                  {u.violation_count}
                </button>
              </td>
              <td>
                <div className="btn-row">
                  {u.kyc_status === 'pending' || reconsideringIds.has(u.id) ? (
                    <>
                      {u.kyc_status !== 'approved' && (
                        <button
                          type="button"
                          className="btn btn-small"
                          disabled={review.isPending}
                          onClick={() => review.mutate({ userId: u.id, status: 'approved' })}
                        >
                          Approve ID
                        </button>
                      )}
                      {u.kyc_status !== 'rejected' && (
                        <button
                          type="button"
                          className="btn btn-small"
                          disabled={review.isPending}
                          onClick={() => setRejecting(u)}
                        >
                          Reject ID
                        </button>
                      )}
                      {u.kyc_status !== 'pending' && (
                        <button
                          type="button"
                          className="btn btn-small btn-ghost"
                          onClick={() =>
                            setReconsideringIds((prev) => {
                              const next = new Set(prev);
                              next.delete(u.id);
                              return next;
                            })
                          }
                        >
                          Cancel
                        </button>
                      )}
                    </>
                  ) : (
                    <button
                      type="button"
                      className="btn btn-small btn-ghost"
                      onClick={() => setReconsideringIds((prev) => new Set(prev).add(u.id))}
                    >
                      Reconsider
                    </button>
                  )}
                  {u.risk_status === 'clear' ? (
                    <button type="button" className="btn btn-small btn-danger" disabled={flag.isPending} onClick={() => setFlagging(u)}>
                      Flag
                    </button>
                  ) : (
                    <button
                      type="button"
                      className="btn btn-small"
                      disabled={flag.isPending}
                      onClick={() => flag.mutate({ userId: u.id, risk_status: 'clear', reason: 'Cleared from admin console' })}
                    >
                      Clear flag
                    </button>
                  )}
                  <button
                    type="button"
                    className="btn btn-small btn-danger"
                    disabled={strike.isPending}
                    onClick={() => setStrikingUser(u)}
                  >
                    Log violation
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <ConfirmDialog
        open={flagging !== null}
        title="Flag this account"
        reason={{ label: 'Reason', minLength: 3, placeholder: 'Why this account is being flagged…' }}
        confirmLabel="Flag"
        danger
        onClose={() => setFlagging(null)}
        onConfirm={async (reason) => {
          if (!flagging) return;
          await flag.mutateAsync({ userId: flagging.id, risk_status: 'flagged', reason: reason! });
        }}
      />

      <KycRejectDialog
        open={rejecting !== null}
        onClose={() => setRejecting(null)}
        onConfirm={async ({ reason_code, note }) => {
          if (!rejecting) return;
          await review.mutateAsync({ userId: rejecting.id, status: 'rejected', reason_code, note });
        }}
      />

      <ConfirmDialog
        open={strikingUser !== null}
        title="Log a violation"
        description={
          strikingUser
            ? `This will be strike ${strikingUser.violation_count + 1} for ${strikingUser.full_name}. 1st = warning, 2nd = 7-day suspension, 3rd = permanent ban.`
            : undefined
        }
        reason={{ label: 'Reason', minLength: 3, placeholder: 'What did they do…' }}
        confirmLabel="Log violation"
        danger
        onClose={() => setStrikingUser(null)}
        onConfirm={async (reason) => {
          if (!strikingUser) return;
          await strike.mutateAsync({ userId: strikingUser.id, reason: reason! });
        }}
      />

      <ViolationHistoryDialog
        userId={historyUser?.id ?? null}
        userName={historyUser?.full_name}
        onClose={() => setHistoryUser(null)}
      />
    </div>
  );
}
