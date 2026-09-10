import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { Dispute, QueueItem } from '../api/types';
import { Card, EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { useToast } from '../components/Toast';
import { dateTime } from '../lib/format';

export function DisputesPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const queue = useQuery({ queryKey: ['admin-reviews'], queryFn: () => api.get<{ queue: QueueItem[] }>('/admin/reviews') });
  const [resolving, setResolving] = useState<Dispute | null>(null);
  const [cancelling, setCancelling] = useState<Dispute | null>(null);

  const resolve = useMutation({
    mutationFn: ({ id, resolution, status }: { id: string; resolution: string; status: 'resolved' | 'closed' }) =>
      api.post(`/admin/disputes/${id}/resolve`, { status, resolution }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-reviews'] });
      toast('Dispute resolved');
    },
  });

  const cancelOrder = useMutation({
    mutationFn: ({ orderId, disputeId, reason }: { orderId: string; disputeId: string; reason: string }) =>
      api.post(`/admin/orders/${orderId}/cancel`, { reason, dispute_id: disputeId }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-reviews'] });
      qc.invalidateQueries({ queryKey: ['reconciliation'] });
      qc.invalidateQueries({ queryKey: ['orders'] });
      toast('Order cancelled and dispute resolved');
    },
  });

  if (queue.isLoading) return <LoadingState />;
  if (queue.isError) return <ErrorState error={queue.error} onRetry={() => queue.refetch()} />;

  const disputes = (queue.data?.queue.filter((q): q is Extract<QueueItem, { type: 'dispute' }> => q.type === 'dispute')) ?? [];

  return (
    <div>
      <PageHeader title="Disputes" subtitle="Reports awaiting a decision. Resolve a dispute, or cancel the order it's about." />

      {disputes.length === 0 ? (
        <EmptyState>No open disputes right now.</EmptyState>
      ) : (
        disputes.map((d) => (
          <Card key={d.id}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16 }}>
              <div>
                <Link to={`/orders/${d.order_id}`}>Order {d.order_id.slice(0, 8)}</Link>
                <p className="muted" style={{ margin: '4px 0' }}>{dateTime(d.created_at)}</p>
                <p style={{ marginTop: 8 }}>{d.reason}</p>
              </div>
              <div className="btn-row" style={{ flexShrink: 0 }}>
                <button type="button" className="btn" onClick={() => setResolving(d)}>
                  Resolve
                </button>
                <button type="button" className="btn btn-danger" onClick={() => setCancelling(d)}>
                  Cancel order &amp; resolve
                </button>
              </div>
            </div>
          </Card>
        ))
      )}

      <ConfirmDialog
        open={resolving !== null}
        title="Resolve dispute"
        description="This closes the dispute but does not change the order itself."
        reason={{ label: 'Resolution (shared with both parties)', minLength: 10, placeholder: 'What was decided and why…' }}
        confirmLabel="Resolve"
        onClose={() => setResolving(null)}
        onConfirm={async (resolution) => {
          if (!resolving) return;
          await resolve.mutateAsync({ id: resolving.id, resolution: resolution!, status: 'resolved' });
        }}
      />

      <ConfirmDialog
        open={cancelling !== null}
        title="Cancel order & resolve dispute"
        description="Cancels the order (any status short of already paid out) and resolves this dispute with the same reason. Both parties are notified; if payment had been confirmed, every admin gets a refund-owed notice."
        reason={{ label: 'Reason', minLength: 10, placeholder: 'Why the order is being cancelled…' }}
        confirmLabel="Cancel order"
        danger
        onClose={() => setCancelling(null)}
        onConfirm={async (reason) => {
          if (!cancelling) return;
          await cancelOrder.mutateAsync({ orderId: cancelling.order_id, disputeId: cancelling.id, reason: reason! });
        }}
      />
    </div>
  );
}
