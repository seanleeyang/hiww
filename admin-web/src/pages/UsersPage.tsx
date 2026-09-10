import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from '../api/client';
import type { AdminUser } from '../api/types';
import { ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { useToast } from '../components/Toast';
import { idCheckLabel, riskStatusLabel, riskStatusTone } from '../lib/status';

export function UsersPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const users = useQuery({ queryKey: ['admin-users'], queryFn: () => api.get<{ users: AdminUser[] }>('/admin/users') });
  const [flagging, setFlagging] = useState<AdminUser | null>(null);
  const [rejecting, setRejecting] = useState<AdminUser | null>(null);
  const [search, setSearch] = useState('');

  const onError = (err: unknown) => toast(err instanceof ApiError ? err.message : 'Something went wrong', 'error');

  const review = useMutation({
    mutationFn: ({ userId, status, note }: { userId: string; status: 'approved' | 'rejected'; note: string }) =>
      api.post(`/admin/users/${userId}/kyc-review`, { status, note }),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ['admin-users'] });
      toast(variables.status === 'approved' ? 'ID check approved' : 'ID check rejected');
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

  const filtered = useMemo(() => {
    const items = users.data?.users ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((u) => u.full_name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q));
  }, [users.data, search]);

  if (users.isLoading) return <LoadingState />;
  if (users.isError) return <ErrorState error={users.error} onRetry={() => users.refetch()} />;

  return (
    <div>
      <PageHeader title="Users" subtitle="Every account. Review ID checks and flag risky accounts." />

      <input
        placeholder="Search by name or email…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 16, maxWidth: 320 }}
      />

      <table>
        <thead>
          <tr>
            <th>User</th>
            <th>Type</th>
            <th>Role</th>
            <th>ID check</th>
            <th>Risk</th>
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
              </td>
              <td>
                <div className="btn-row">
                  {u.kyc_status !== 'approved' && (
                    <button
                      type="button"
                      className="btn btn-small"
                      disabled={review.isPending}
                      onClick={() => review.mutate({ userId: u.id, status: 'approved', note: 'Approved from admin console' })}
                    >
                      Approve ID
                    </button>
                  )}
                  {u.kyc_status !== 'rejected' && (
                    <button type="button" className="btn btn-small" disabled={review.isPending} onClick={() => setRejecting(u)}>
                      Reject ID
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

      <ConfirmDialog
        open={rejecting !== null}
        title="Reject ID check"
        reason={{ label: 'Reason (internal note)', minLength: 3, placeholder: 'Why this is being rejected…' }}
        confirmLabel="Reject"
        danger
        onClose={() => setRejecting(null)}
        onConfirm={async (note) => {
          if (!rejecting) return;
          await review.mutateAsync({ userId: rejecting.id, status: 'rejected', note: note! });
        }}
      />
    </div>
  );
}
