import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { Want } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { money } from '../lib/format';

export function WantsPage() {
  const qc = useQueryClient();
  const wants = useQuery({ queryKey: ['admin-wants'], queryFn: () => api.get<{ requests: Want[] }>('/admin/requests') });
  const [removing, setRemoving] = useState<Want | null>(null);
  const [cancellingAll, setCancellingAll] = useState(false);

  const remove = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => api.post(`/admin/requests/${id}/remove`, { reason }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-wants'] }),
  });
  const removeAll = useMutation({
    mutationFn: () => api.post('/admin/requests/remove-all'),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-wants'] }),
  });

  if (wants.isLoading) return <LoadingState />;
  if (wants.isError) return <ErrorState error={wants.error} onRetry={() => wants.refetch()} />;

  return (
    <div>
      <PageHeader
        title="Wants"
        subtitle="Every want posted. Removing takes down a problem listing — it does not touch orders already built on it."
        actions={
          <button type="button" className="btn btn-danger" onClick={() => setCancellingAll(true)}>
            Cancel ALL wants
          </button>
        }
      />

      {wants.data!.requests.length === 0 ? (
        <EmptyState>No wants yet.</EmptyState>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Item</th>
              <th>Shopper</th>
              <th>Budget</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {wants.data!.requests.map((w) => (
              <tr key={w.id}>
                <td>{w.title || w.item_description}</td>
                <td>
                  {w.shopper_name}
                  <div className="muted">{w.shopper_email}</div>
                </td>
                <td>{money(w.budget)}</td>
                <td>
                  <StatusPill label={w.status} tone={w.status === 'cancelled' ? 'negative' : w.status === 'completed' ? 'positive' : 'neutral'} />
                </td>
                <td>
                  {w.status === 'open' && (
                    <button type="button" className="btn btn-small" onClick={() => setRemoving(w)}>
                      Remove
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <ConfirmDialog
        open={removing !== null}
        title="Remove this want"
        reason={{ label: 'Reason', minLength: 3, placeholder: 'Why this listing is being removed…' }}
        confirmLabel="Remove"
        danger
        onClose={() => setRemoving(null)}
        onConfirm={async (reason) => {
          if (!removing) return;
          await remove.mutateAsync({ id: removing.id, reason: reason! });
        }}
      />

      <ConfirmDialog
        open={cancellingAll}
        title="Cancel every live want"
        description="Cancels every open or accepted want. This is a bulk moderation action — use with care."
        confirmLabel="Cancel all"
        danger
        onClose={() => setCancellingAll(false)}
        onConfirm={async () => {
          await removeAll.mutateAsync();
        }}
      />
    </div>
  );
}
