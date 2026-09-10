import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { QueueItem } from '../api/types';
import { Card, EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { riskLabel, riskTone } from '../lib/status';
import { money } from '../lib/format';

type ReceiptItem = Extract<QueueItem, { type: 'receipt' }>;
type MessageItem = Extract<QueueItem, { type: 'message' }>;

export function FlaggedContentPage() {
  const qc = useQueryClient();
  const [tab, setTab] = useState<'receipts' | 'messages'>('receipts');
  const queue = useQuery({ queryKey: ['admin-reviews'], queryFn: () => api.get<{ queue: QueueItem[] }>('/admin/reviews') });

  const clearReceipt = useMutation({
    mutationFn: (orderId: string) => api.post(`/admin/orders/${orderId}/clear-receipt-flag`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-reviews'] }),
  });
  const clearMessage = useMutation({
    mutationFn: (messageId: string) => api.post(`/admin/messages/${messageId}/clear-flag`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-reviews'] }),
  });

  if (queue.isLoading) return <LoadingState />;
  if (queue.isError) return <ErrorState error={queue.error} onRetry={() => queue.refetch()} />;

  const receipts = (queue.data?.queue.filter((q): q is ReceiptItem => q.type === 'receipt')) ?? [];
  const messages = (queue.data?.queue.filter((q): q is MessageItem => q.type === 'message')) ?? [];

  return (
    <div>
      <PageHeader title="Flagged content" subtitle="Receipts and chat messages the AI checks flagged for review." />

      <div className="tabs">
        <button type="button" className={tab === 'receipts' ? 'tab active' : 'tab'} onClick={() => setTab('receipts')}>
          Receipts ({receipts.length})
        </button>
        <button type="button" className={tab === 'messages' ? 'tab active' : 'tab'} onClick={() => setTab('messages')}>
          Messages ({messages.length})
        </button>
      </div>

      {tab === 'receipts' &&
        (receipts.length === 0 ? (
          <EmptyState>No flagged receipts.</EmptyState>
        ) : (
          receipts.map((r) => (
            <Card key={r.id}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16 }}>
                <div>
                  <Link to={`/orders/${r.order_id}`}>{r.item_description}</Link>{' '}
                  <StatusPill label={riskLabel(r.risk)} tone={riskTone(r.risk)} />
                  <p className="muted" style={{ margin: '4px 0' }}>{money(r.total_price)}</p>
                  {r.summary && <p>{r.summary}</p>}
                  {r.flags.length > 0 && <p className="muted">Flags: {r.flags.join(', ')}</p>}
                  {r.receipt_url && (
                    <a href={r.receipt_url} target="_blank" rel="noreferrer">
                      View receipt photo
                    </a>
                  )}
                </div>
                <button type="button" className="btn" onClick={() => clearReceipt.mutate(r.order_id)}>
                  Clear flag
                </button>
              </div>
            </Card>
          ))
        ))}

      {tab === 'messages' &&
        (messages.length === 0 ? (
          <EmptyState>No flagged messages.</EmptyState>
        ) : (
          messages.map((m) => (
            <Card key={m.id}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16 }}>
                <div>
                  <Link to={`/orders/${m.order_id}`}>Order {m.order_id.slice(0, 8)}</Link>{' '}
                  <StatusPill label={riskLabel(m.risk)} tone={riskTone(m.risk)} />
                  {m.hidden && <StatusPill label="Hidden from both parties" tone="negative" />}
                  <p className="muted" style={{ margin: '4px 0' }}>From {m.sender_name}</p>
                  <p>{m.body}</p>
                  {m.summary && <p className="muted">{m.summary}</p>}
                </div>
                <button type="button" className="btn" onClick={() => clearMessage.mutate(m.id)}>
                  Clear flag
                </button>
              </div>
            </Card>
          ))
        ))}
    </div>
  );
}
