import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from '../api/client';
import type { Want } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { useToast } from '../components/Toast';
import { money } from '../lib/format';
import { lifecycleTone, wantStatusLabel } from '../lib/status';

export function WantsPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const wants = useQuery({ queryKey: ['admin-wants'], queryFn: () => api.get<{ requests: Want[] }>('/admin/requests') });
  const [removing, setRemoving] = useState<Want | null>(null);
  const [cancellingAll, setCancellingAll] = useState(false);
  const [search, setSearch] = useState('');

  const onError = (err: unknown) => toast(err instanceof ApiError ? err.message : 'Something went wrong', 'error');

  const remove = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => api.post(`/admin/requests/${id}/remove`, { reason }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-wants'] });
      toast('Want removed');
    },
    onError,
  });
  const removeAll = useMutation({
    mutationFn: (reason: string) => api.post('/admin/requests/remove-all', { reason }),
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ['admin-wants'] });
      toast(`Cancelled ${(data as { removed: number }).removed} want(s)`);
    },
    onError,
  });

  const filtered = useMemo(() => {
    const items = wants.data?.requests ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter(
      (w) =>
        w.item_description.toLowerCase().includes(q) ||
        (w.title ?? '').toLowerCase().includes(q) ||
        w.shopper_name.toLowerCase().includes(q) ||
        w.shopper_email.toLowerCase().includes(q)
    );
  }, [wants.data, search]);

  const liveCount = (wants.data?.requests ?? []).filter((w) => w.status === 'open' || w.status === 'accepted').length;

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

      <input
        placeholder="Search by item or shopper…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 16, maxWidth: 320 }}
      />

      {filtered.length === 0 ? (
        <EmptyState>{search ? 'No wants match your search.' : 'No wants yet.'}</EmptyState>
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
            {filtered.map((w) => (
              <tr key={w.id}>
                <td>{w.title || w.item_description}</td>
                <td>
                  {w.shopper_name}
                  <div className="muted">{w.shopper_email}</div>
                </td>
                <td>{money(w.budget)}</td>
                <td>
                  <StatusPill label={wantStatusLabel(w.status)} tone={lifecycleTone(w.status)} />
                </td>
                <td>
                  {w.status === 'open' && (
                    <button type="button" className="btn btn-small" disabled={remove.isPending} onClick={() => setRemoving(w)}>
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
        description={`Cancels all ${liveCount} open or accepted want${liveCount === 1 ? '' : 's'} platform-wide. This is a bulk moderation action — use with care.`}
        reason={{ label: 'Reason', minLength: 10, placeholder: 'Why every live want is being cancelled…' }}
        confirmLabel="Cancel all"
        danger
        onClose={() => setCancellingAll(false)}
        onConfirm={async (reason) => {
          await removeAll.mutateAsync(reason!);
        }}
      />
    </div>
  );
}
