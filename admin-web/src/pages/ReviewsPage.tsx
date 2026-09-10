import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminReview } from '../api/types';
import { Card, EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { dateTime } from '../lib/format';

export function ReviewsPage() {
  const qc = useQueryClient();
  const reviews = useQuery({ queryKey: ['admin-reviews-list'], queryFn: () => api.get<{ reviews: AdminReview[] }>('/admin/order-reviews') });

  const hide = useMutation({
    mutationFn: (id: string) => api.post(`/admin/order-reviews/${id}/hide`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-reviews-list'] }),
  });
  const unhide = useMutation({
    mutationFn: (id: string) => api.post(`/admin/order-reviews/${id}/unhide`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-reviews-list'] }),
  });

  if (reviews.isLoading) return <LoadingState />;
  if (reviews.isError) return <ErrorState error={reviews.error} onRetry={() => reviews.refetch()} />;

  return (
    <div>
      <PageHeader title="Reviews" subtitle="Star ratings left after delivery. Hide anything abusive or inappropriate." />

      {reviews.data!.reviews.length === 0 ? (
        <EmptyState>No reviews yet.</EmptyState>
      ) : (
        reviews.data!.reviews.map((r) => (
          <Card key={r.id}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16 }}>
              <div>
                <strong>
                  {'★'.repeat(r.rating)}
                  {'☆'.repeat(5 - r.rating)}
                </strong>{' '}
                {r.hidden_at && <StatusPill label="Hidden" tone="negative" />}
                <p className="muted" style={{ margin: '4px 0' }}>
                  {r.reviewer_name} → {r.reviewee_name} · {r.item_description} · {dateTime(r.created_at)}
                </p>
                {r.comment && <p>{r.comment}</p>}
              </div>
              <button
                type="button"
                className="btn btn-small"
                onClick={() => (r.hidden_at ? unhide.mutate(r.id) : hide.mutate(r.id))}
              >
                {r.hidden_at ? 'Unhide' : 'Hide'}
              </button>
            </div>
          </Card>
        ))
      )}
    </div>
  );
}
