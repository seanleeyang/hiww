import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from '../api/client';
import type { AdminReview } from '../api/types';
import { Card, EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { useToast } from '../components/Toast';
import { dateTime } from '../lib/format';

export function ReviewsPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const reviews = useQuery({ queryKey: ['admin-reviews-list'], queryFn: () => api.get<{ reviews: AdminReview[] }>('/admin/order-reviews') });
  const [hiding, setHiding] = useState<AdminReview | null>(null);

  const onError = (err: unknown) => toast(err instanceof ApiError ? err.message : 'Something went wrong', 'error');

  const hide = useMutation({
    mutationFn: (id: string) => api.post(`/admin/order-reviews/${id}/hide`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-reviews-list'] });
      toast('Review hidden');
    },
    onError,
  });
  const unhide = useMutation({
    mutationFn: (id: string) => api.post(`/admin/order-reviews/${id}/unhide`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-reviews-list'] });
      toast('Review restored');
    },
    onError,
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
                disabled={unhide.isPending}
                onClick={() => (r.hidden_at ? unhide.mutate(r.id) : setHiding(r))}
              >
                {r.hidden_at ? 'Unhide' : 'Hide'}
              </button>
            </div>
          </Card>
        ))
      )}

      <ConfirmDialog
        open={hiding !== null}
        title="Hide this review"
        description={hiding ? `Removes it from ${hiding.reviewee_name}'s public reviews. You can unhide it again any time.` : undefined}
        confirmLabel="Hide review"
        danger
        onClose={() => setHiding(null)}
        onConfirm={async () => {
          if (!hiding) return;
          await hide.mutateAsync(hiding.id);
        }}
      />
    </div>
  );
}
