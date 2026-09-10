import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { Trip } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { dateTime } from '../lib/format';

export function TripsPage() {
  const qc = useQueryClient();
  const trips = useQuery({ queryKey: ['admin-trips'], queryFn: () => api.get<{ trips: Trip[] }>('/admin/trips') });
  const [removing, setRemoving] = useState<Trip | null>(null);
  const [cancellingAll, setCancellingAll] = useState(false);

  const remove = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => api.post(`/admin/trips/${id}/remove`, { reason }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-trips'] }),
  });
  const removeAll = useMutation({
    mutationFn: () => api.post('/admin/trips/remove-all'),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-trips'] }),
  });

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

      {trips.data!.trips.length === 0 ? (
        <EmptyState>No trips yet.</EmptyState>
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
            {trips.data!.trips.map((t) => (
              <tr key={t.id}>
                <td>
                  {t.title || `${t.departure_country} → ${t.arrival_country}`}
                </td>
                <td>
                  {t.traveler_name}
                  <div className="muted">{t.traveler_email}</div>
                </td>
                <td>
                  <StatusPill label={t.status} tone={t.status === 'cancelled' ? 'negative' : t.status === 'completed' ? 'positive' : 'neutral'} />
                </td>
                <td>
                  {dateTime(t.departure_date)} – {dateTime(t.return_date)}
                </td>
                <td>
                  {t.status === 'published' && (
                    <button type="button" className="btn btn-small" onClick={() => setRemoving(t)}>
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
        description="Cancels every published or in-progress trip. This is a bulk moderation action — use with care."
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
