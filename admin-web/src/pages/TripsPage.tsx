import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from '../api/client';
import type { Trip } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { useToast } from '../components/Toast';
import { dateTime } from '../lib/format';
import { lifecycleTone, tripStatusLabel } from '../lib/status';

export function TripsPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const trips = useQuery({ queryKey: ['admin-trips'], queryFn: () => api.get<{ trips: Trip[] }>('/admin/trips') });
  const [removing, setRemoving] = useState<Trip | null>(null);
  const [cancellingAll, setCancellingAll] = useState(false);
  const [search, setSearch] = useState('');

  const onError = (err: unknown) => toast(err instanceof ApiError ? err.message : 'Something went wrong', 'error');

  const remove = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => api.post(`/admin/trips/${id}/remove`, { reason }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-trips'] });
      toast('Trip removed');
    },
    onError,
  });
  const removeAll = useMutation({
    mutationFn: (reason: string) => api.post('/admin/trips/remove-all', { reason }),
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ['admin-trips'] });
      toast(`Cancelled ${(data as { removed: number }).removed} trip(s)`);
    },
    onError,
  });

  const filtered = useMemo(() => {
    const items = trips.data?.trips ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter(
      (t) =>
        (t.title ?? '').toLowerCase().includes(q) ||
        t.traveler_name.toLowerCase().includes(q) ||
        t.traveler_email.toLowerCase().includes(q) ||
        t.departure_country.toLowerCase().includes(q) ||
        t.arrival_country.toLowerCase().includes(q)
    );
  }, [trips.data, search]);

  const liveCount = (trips.data?.trips ?? []).filter((t) => t.status === 'published' || t.status === 'in_progress').length;

  if (trips.isLoading) return <LoadingState />;
  if (trips.isError) return <ErrorState error={trips.error} onRetry={() => trips.refetch()} />;

  return (
    <div>
      <PageHeader
        title="Trips"
        subtitle="Every trip posted. Removing takes down a problem listing — it does not touch orders already built on it."
        actions={
          <button type="button" className="btn btn-danger" onClick={() => setCancellingAll(true)}>
            Cancel ALL trips
          </button>
        }
      />

      <input
        placeholder="Search by route, title, or traveler…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 16, maxWidth: 320 }}
      />

      {filtered.length === 0 ? (
        <EmptyState>{search ? 'No trips match your search.' : 'No trips yet.'}</EmptyState>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Route</th>
              <th>Traveler</th>
              <th>Status</th>
              <th>Dates</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((t) => (
              <tr key={t.id}>
                <td>
                  {t.title || `${t.departure_country} → ${t.arrival_country}`}
                </td>
                <td>
                  {t.traveler_name}
                  <div className="muted">{t.traveler_email}</div>
                </td>
                <td>
                  <StatusPill label={tripStatusLabel(t.status)} tone={lifecycleTone(t.status)} />
                </td>
                <td>
                  {dateTime(t.departure_date)} – {dateTime(t.return_date)}
                </td>
                <td>
                  {t.status === 'published' && (
                    <button type="button" className="btn btn-small" disabled={remove.isPending} onClick={() => setRemoving(t)}>
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
        title="Remove this trip"
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
        title="Cancel every live trip"
        description={`Cancels all ${liveCount} published or in-progress trip${liveCount === 1 ? '' : 's'} platform-wide. This is a bulk moderation action — use with care.`}
        reason={{ label: 'Reason', minLength: 10, placeholder: 'Why every live trip is being cancelled…' }}
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
