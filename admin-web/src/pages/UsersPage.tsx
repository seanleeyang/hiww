import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminUser } from '../api/types';
import { ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { idCheckLabel } from '../lib/status';

export function UsersPage() {
  const qc = useQueryClient();
  const users = useQuery({ queryKey: ['admin-users'], queryFn: () => api.get<{ users: AdminUser[] }>('/admin/users') });
  const [flagging, setFlagging] = useState<AdminUser | null>(null);

  const review = useMutation({
    mutationFn: ({ userId, status }: { userId: string; status: 'approved' | 'rejected' }) =>
      api.post(`/admin/users/${userId}/kyc-review`, { status, note: `Set to ${status} from admin console` }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-users'] }),
  });
  const flag = useMutation({
    mutationFn: ({ userId, risk_status, reason }: { userId: string; risk_status: string; reason: string }) =>
      api.post(`/admin/users/${userId}/flag`, { risk_status, reason }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-users'] }),
  });

  if (users.isLoading) return <LoadingState />;
  if (users.isError) return <ErrorState error={users.error} onRetry={() => users.refetch()} />;

  return (
    <div>
      <PageHeader title="Users" subtitle="Every account. Review ID checks and flag risky accounts." />

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
          {users.data!.users.map((u) => (
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
                <StatusPill
                  label={u.risk_status}
                  tone={u.risk_status === 'clear' ? 'positive' : u.risk_status === 'restricted' ? 'negative' : 'warning'}
                />
              </td>
              <td>
                <div className="btn-row">
                  {u.kyc_status !== 'approved' && (
                    <button type="button" className="btn btn-small" onClick={() => review.mutate({ userId: u.id, status: 'approved' })}>
                      Approve ID
                    </button>
                  )}
                  {u.kyc_status !== 'rejected' && (
                    <button type="button" className="btn btn-small" onClick={() => review.mutate({ userId: u.id, status: 'rejected' })}>
                      Reject ID
                    </button>
                  )}
                  {u.risk_status === 'clear' ? (
                    <button type="button" className="btn btn-small btn-danger" onClick={() => setFlagging(u)}>
                      Flag
                    </button>
                  ) : (
                    <button
                      type="button"
                      className="btn btn-small"
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
    </div>
  );
}
