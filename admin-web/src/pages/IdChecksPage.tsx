import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { QueueItem } from '../api/types';
import { Card, EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { useToast } from '../components/Toast';
import { ApiError } from '../api/client';
import { dateTime } from '../lib/format';

type KycItem = Extract<QueueItem, { type: 'kyc' }>;

export function IdChecksPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const queue = useQuery({ queryKey: ['admin-reviews'], queryFn: () => api.get<{ queue: QueueItem[] }>('/admin/reviews') });
  const [rejecting, setRejecting] = useState<KycItem | null>(null);

  const review = useMutation({
    mutationFn: ({ userId, status, note }: { userId: string; status: 'approved' | 'rejected'; note: string }) =>
      api.post(`/admin/users/${userId}/kyc-review`, { status, note }),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ['admin-reviews'] });
      toast(variables.status === 'approved' ? 'ID check approved' : 'ID check rejected');
    },
    onError: (err) => toast(err instanceof ApiError ? err.message : 'Something went wrong', 'error'),
  });

  if (queue.isLoading) return <LoadingState />;
  if (queue.isError) return <ErrorState error={queue.error} onRetry={() => queue.refetch()} />;

  const items = (queue.data?.queue.filter((q): q is KycItem => q.type === 'kyc')) ?? [];

  return (
    <div>
      <PageHeader title="ID checks" subtitle="Accounts awaiting identity verification — shown to users as “ID check”." />

      {items.length === 0 ? (
        <EmptyState>Nothing pending.</EmptyState>
      ) : (
        items.map((item) => (
          <Card key={item.id}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16 }}>
              <div>
                <strong>{item.full_name}</strong>
                <p className="muted" style={{ margin: '4px 0' }}>
                  {item.email} · {dateTime(item.created_at)}
                </p>
              </div>
              <div className="btn-row" style={{ flexShrink: 0 }}>
                <button
                  type="button"
                  className="btn btn-primary"
                  disabled={review.isPending}
                  onClick={() => review.mutate({ userId: item.user_id, status: 'approved', note: 'Approved from admin console' })}
                >
                  Approve
                </button>
                <button type="button" className="btn btn-danger" disabled={review.isPending} onClick={() => setRejecting(item)}>
                  Reject
                </button>
              </div>
            </div>
          </Card>
        ))
      )}

      <ConfirmDialog
        open={rejecting !== null}
        title="Reject ID check"
        reason={{ label: 'Reason (internal note)', minLength: 3, placeholder: 'Why this is being rejected…' }}
        confirmLabel="Reject"
        danger
        onClose={() => setRejecting(null)}
        onConfirm={async (note) => {
          if (!rejecting) return;
          await review.mutateAsync({ userId: rejecting.user_id, status: 'rejected', note: note! });
        }}
      />
    </div>
  );
}
