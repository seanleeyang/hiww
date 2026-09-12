import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminUser, Order, QueueItem } from '../api/types';
import { Card, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { MoneyActionDialog } from '../components/MoneyActionDialog';
import { useToast } from '../components/Toast';
import { orderStatusLabel, orderStatusTone } from '../lib/status';
import { dateTime, money } from '../lib/format';

const TIMELINE_STEPS: Array<{ key: keyof Order; label: string }> = [
  { key: 'created_at', label: 'Order created' },
  { key: 'confirmed_at', label: 'Payment confirmed' },
  { key: 'purchased_at', label: 'Items purchased' },
  { key: 'shipped_at', label: 'Shipped' },
  { key: 'delivered_at', label: 'Delivered' },
  { key: 'cancelled_at', label: 'Cancelled' },
];

export function OrderDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const toast = useToast();
  const [cancelling, setCancelling] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [recordingPayout, setRecordingPayout] = useState(false);
  const [recordingRefund, setRecordingRefund] = useState(false);
  const [copied, setCopied] = useState(false);

  const order = useQuery({ queryKey: ['order', id], queryFn: () => api.get<Order>(`/orders/${id}`), enabled: Boolean(id) });
  const users = useQuery({ queryKey: ['admin-users'], queryFn: () => api.get<{ users: AdminUser[] }>('/admin/users') });
  const queue = useQuery({ queryKey: ['admin-reviews'], queryFn: () => api.get<{ queue: QueueItem[] }>('/admin/reviews') });

  const invalidateAll = () => {
    qc.invalidateQueries({ queryKey: ['order', id] });
    qc.invalidateQueries({ queryKey: ['orders'] });
    qc.invalidateQueries({ queryKey: ['reconciliation'] });
    qc.invalidateQueries({ queryKey: ['admin-reviews'] });
  };

  const confirmPayment = useMutation({
    mutationFn: () => api.post('/payments/confirm', { order_id: id }),
    onSuccess: () => {
      invalidateAll();
      toast('Payment confirmed');
    },
  });
  const cancelOrder = useMutation({
    mutationFn: (reason: string) => api.post(`/admin/orders/${id}/cancel`, { reason }),
    onSuccess: () => {
      invalidateAll();
      toast('Order cancelled');
    },
  });
  const recordPayout = useMutation({
    mutationFn: (input: { method: string; reference: string; note?: string }) =>
      api.post('/payments/payout', { order_id: id, ...input }),
    onSuccess: () => {
      invalidateAll();
      toast('Payout recorded');
    },
  });
  const recordRefund = useMutation({
    mutationFn: (input: { method: string; reference: string; note?: string }) =>
      api.post(`/admin/orders/${id}/refund`, input),
    onSuccess: () => {
      invalidateAll();
      toast('Refund recorded');
    },
  });

  if (order.isLoading) return <LoadingState />;
  if (order.isError) return <ErrorState error={order.error} onRetry={() => order.refetch()} />;
  const o = order.data!;

  const nameById = new Map((users.data?.users ?? []).map((u) => [u.id, u.full_name]));
  const linkedDispute = queue.data?.queue.find((q) => q.type === 'dispute' && q.order_id === o.id);
  const payoutAmount = money(o.traveller_payout ?? o.total_price);
  const refundAmount = money(o.shopper_total ?? o.total_price);
  const paymentConfirmed = Boolean(o.confirmed_at);

  function copyId() {
    void navigator.clipboard.writeText(o.id).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    });
  }

  return (
    <div>
      <Link to="/orders" className="breadcrumb">
        ← Orders
      </Link>

      <PageHeader
        title={o.item_description}
        subtitle={
          <>
            Order <code className="mono-id">{o.id.slice(0, 8)}</code>
            <button type="button" className="btn-inline-copy" onClick={copyId}>
              {copied ? 'Copied' : 'Copy full ID'}
            </button>
          </>
        }
        actions={
          <div className="btn-row">
            {o.status === 'pending_payment' && (
              <button type="button" className="btn btn-primary" onClick={() => setConfirming(true)}>
                Confirm payment
              </button>
            )}
            {o.status === 'delivered' && !linkedDispute && (
              <button type="button" className="btn btn-primary" onClick={() => setRecordingPayout(true)}>
                Record payout
              </button>
            )}
            {o.status === 'cancelled' && paymentConfirmed && (
              <button type="button" className="btn btn-primary" onClick={() => setRecordingRefund(true)}>
                Record refund
              </button>
            )}
            {o.status !== 'cancelled' && !linkedDispute && (
              <button type="button" className="btn btn-danger" onClick={() => setCancelling(true)}>
                Cancel order
              </button>
            )}
          </div>
        }
      />

      {linkedDispute && (
        <div className="error-state" style={{ marginBottom: 16 }}>
          <p>
            This order has an open dispute — payout, refund, and cancellation are all locked here until it's resolved.
          </p>
          <Link to="/disputes" className="btn btn-ghost">
            Go to Disputes
          </Link>
        </div>
      )}

      <div className="section">
        <Card title="Status & timeline">
          <div style={{ marginBottom: 14 }}>
            <StatusPill label={orderStatusLabel(o.status)} tone={orderStatusTone(o.status)} />
          </div>
          <ol className="timeline">
            {TIMELINE_STEPS.filter((step) => o[step.key]).map((step) => (
              <li key={step.key}>
                <span className="timeline-label">{step.label}</span>
                <span className="timeline-time">{dateTime(o[step.key] as string)}</span>
              </li>
            ))}
          </ol>
        </Card>

        <Card title="Parties">
          <p>
            <strong>Shopper:</strong> {nameById.get(o.shopper_id) ?? o.shopper_id}
          </p>
          <p>
            <strong>Traveler:</strong> {nameById.get(o.traveler_id) ?? o.traveler_id}
          </p>
        </Card>

        {(o.delivery_address_street || o.delivery_address_city) && (
          <Card title="Delivery address">
            <p>
              {[
                o.delivery_address_street,
                o.delivery_address_street2,
                o.delivery_address_subdistrict,
                o.delivery_address_district,
                o.delivery_address_city,
                o.delivery_address_postal_code,
                o.delivery_address_country,
              ]
                .filter(Boolean)
                .join(', ')}
            </p>
          </Card>
        )}

        <Card title="Money">
          <div className="money-breakdown">
            <div className="money-row">
              <span>Total price</span>
              <span>{money(o.total_price)}</span>
            </div>
            <div className="money-row">
              <span>Platform fees</span>
              <span>{money(o.fees)}</span>
            </div>
            {o.shopper_total && (
              <div className="money-row money-row-total">
                <span>Shopper pays</span>
                <span>{money(o.shopper_total)}</span>
              </div>
            )}
            {o.traveller_payout && (
              <div className="money-row money-row-total">
                <span>Traveler receives</span>
                <span>{money(o.traveller_payout)}</span>
              </div>
            )}
          </div>
        </Card>

        {(o.purchase_proof_url || o.item_photo_url || o.shipping_proof_url || o.delivery_proof_url) && (
          <Card title="Proof photos">
            <div className="btn-row">
              {o.item_photo_url && (
                <a className="btn btn-ghost" href={o.item_photo_url} target="_blank" rel="noreferrer">
                  Item photo
                </a>
              )}
              {o.purchase_proof_url && (
                <a className="btn btn-ghost" href={o.purchase_proof_url} target="_blank" rel="noreferrer">
                  Purchase receipt
                </a>
              )}
              {o.shipping_proof_url && (
                <a className="btn btn-ghost" href={o.shipping_proof_url} target="_blank" rel="noreferrer">
                  Shipping proof
                </a>
              )}
              {o.delivery_proof_url && (
                <a className="btn btn-ghost" href={o.delivery_proof_url} target="_blank" rel="noreferrer">
                  Delivery proof
                </a>
              )}
            </div>
          </Card>
        )}
      </div>

      <ConfirmDialog
        open={confirming}
        title="Confirm payment"
        description="Only confirm once the shopper's money is really in your account."
        confirmLabel="Confirm payment"
        onClose={() => setConfirming(false)}
        onConfirm={async () => {
          await confirmPayment.mutateAsync();
        }}
      />

      <ConfirmDialog
        open={cancelling}
        title="Cancel this order"
        description={
          paymentConfirmed
            ? `Payment for this order (${money(o.shopper_total ?? o.total_price)}) has already been confirmed. Cancelling will create a ${refundAmount} refund obligation — every admin gets notified, and it'll show under Money → Awaiting refund until you record it.`
            : 'No payment has been confirmed for this order yet — cancelling now creates no refund obligation.'
        }
        reason={{ label: 'Reason', minLength: 10, placeholder: 'Why this order is being cancelled…' }}
        confirmLabel="Cancel order"
        danger
        onClose={() => setCancelling(false)}
        onConfirm={async (reason) => {
          await cancelOrder.mutateAsync(reason!);
        }}
      />

      <MoneyActionDialog
        open={recordingPayout}
        title="Record payout"
        description="Record that you've sent the traveler their payout out of band."
        amount={payoutAmount}
        context={o.item_description}
        confirmLabel="Record payout"
        onClose={() => setRecordingPayout(false)}
        onConfirm={async (input) => {
          await recordPayout.mutateAsync(input);
        }}
      />

      <MoneyActionDialog
        open={recordingRefund}
        title="Record refund"
        description="Record that you've refunded the shopper out of band."
        amount={refundAmount}
        context={o.item_description}
        confirmLabel="Record refund"
        onClose={() => setRecordingRefund(false)}
        onConfirm={async (input) => {
          await recordRefund.mutateAsync(input);
        }}
      />

      <button type="button" className="btn btn-ghost" onClick={() => navigate('/orders')} style={{ marginTop: 8 }}>
        ← Back to orders
      </button>
    </div>
  );
}
