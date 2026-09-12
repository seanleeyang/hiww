import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminUser, MoneyOrderRow, PayoutRow, Reconciliation, RefundRow } from '../api/types';
import { Card, EmptyState, ErrorState, LoadingState, PageHeader, Stat, StatGrid } from '../components/ui';
import { MoneyActionDialog } from '../components/MoneyActionDialog';
import { useToast } from '../components/Toast';
import { money } from '../lib/format';

export function MoneyPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const recon = useQuery({ queryKey: ['reconciliation'], queryFn: () => api.get<Reconciliation>('/ops/reconciliation') });
  const users = useQuery({ queryKey: ['admin-users'], queryFn: () => api.get<{ users: AdminUser[] }>('/admin/users') });
  const [payingOut, setPayingOut] = useState<MoneyOrderRow | null>(null);
  const [refunding, setRefunding] = useState<MoneyOrderRow | null>(null);
  const [search, setSearch] = useState('');

  const invalidate = () => qc.invalidateQueries({ queryKey: ['reconciliation'] });
  const payout = useMutation({
    mutationFn: (input: { order_id: string; method: string; reference: string; note?: string }) =>
      api.post('/payments/payout', input),
    onSuccess: () => {
      invalidate();
      toast('Payout recorded');
    },
  });
  const refund = useMutation({
    mutationFn: ({ orderId, ...input }: { orderId: string; method: string; reference: string; note?: string }) =>
      api.post(`/admin/orders/${orderId}/refund`, input),
    onSuccess: () => {
      invalidate();
      toast('Refund recorded');
    },
  });

  const membershipById = useMemo(
    () => new Map((users.data?.users ?? []).map((u) => [u.id, u.membership_id])),
    [users.data]
  );

  const q = search.trim().toLowerCase();
  const matchesOrderRow = (o: MoneyOrderRow) =>
    !q ||
    o.item_description.toLowerCase().includes(q) ||
    (o.shopper_id && (membershipById.get(o.shopper_id) ?? '').toLowerCase().includes(q)) ||
    (o.traveler_id && (membershipById.get(o.traveler_id) ?? '').toLowerCase().includes(q));
  // Payouts/refunds don't carry shopper/traveler ids (see PayoutRow/RefundRow)
  // — only item text and the payment reference/method are searchable here.
  const matchesMoneyRow = (r: PayoutRow | RefundRow) =>
    !q ||
    r.item_description.toLowerCase().includes(q) ||
    r.method.toLowerCase().includes(q) ||
    r.reference.toLowerCase().includes(q);

  if (recon.isLoading) return <LoadingState />;
  if (recon.isError) return <ErrorState error={recon.error} onRetry={() => recon.refetch()} />;
  const d = recon.data!;
  const awaitingPayment = d.awaiting_payment.orders.filter(matchesOrderRow);
  const awaitingPayout = d.awaiting_payout.orders.filter(matchesOrderRow);
  const awaitingRefund = d.awaiting_refund.orders.filter(matchesOrderRow);
  const paidOut = d.paid_out.payouts.filter(matchesMoneyRow);
  const refunded = d.refunded.refunds.filter(matchesMoneyRow);

  return (
    <div>
      <PageHeader title="Money" subtitle="Manual-money pilot reconciliation — what's owed in, owed out, and settled." />

      <input
        placeholder="Search every table below by item or member ID…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 16, maxWidth: 360 }}
      />

      <StatGrid>
        <Stat label="Awaiting payment" value={money(d.awaiting_payment.total)} />
        <Stat label="Awaiting payout" value={money(d.awaiting_payout.total)} />
        <Stat label="Paid out" value={money(d.paid_out.total)} />
        <Stat label="Awaiting refund" value={money(d.awaiting_refund.total)} />
        <Stat label="Refunded" value={money(d.refunded.total)} />
      </StatGrid>

      <Card title={`Awaiting payment (${d.awaiting_payment.count})`}>
        {awaitingPayment.length === 0 ? (
          <EmptyState>{search ? 'No matches.' : 'Nothing pending.'}</EmptyState>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Item</th>
                <th>Amount</th>
                <th>Claimed?</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {awaitingPayment.map((o) => (
                <tr key={o.id}>
                  <td>
                    <Link to={`/orders/${o.id}`}>{o.item_description}</Link>
                  </td>
                  <td>{money(o.shopper_total ?? o.total_price)}</td>
                  <td>{o.payment_claimed_at ? 'Yes' : 'No'}</td>
                  <td></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Card title={`Awaiting payout (${d.awaiting_payout.count})`}>
        {awaitingPayout.length === 0 ? (
          <EmptyState>{search ? 'No matches.' : 'Nothing pending.'}</EmptyState>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Item</th>
                <th>Amount</th>
                <th>Traveler's bank account</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {awaitingPayout.map((o) => {
                const hasBankAccount = Boolean(o.bank_name && o.bank_account_number);
                return (
                  <tr key={o.id}>
                    <td>
                      <Link to={`/orders/${o.id}`}>{o.item_description}</Link>
                    </td>
                    <td>{money(o.traveller_payout ?? o.total_price)}</td>
                    <td>
                      {hasBankAccount ? (
                        `${o.bank_name} · ${o.bank_account_number}`
                      ) : (
                        <span className="muted">No bank account on file yet</span>
                      )}
                    </td>
                    <td>
                      <button
                        type="button"
                        className="btn btn-small"
                        disabled={!hasBankAccount}
                        title={hasBankAccount ? undefined : "The traveler needs to add their bank account in the app first"}
                        onClick={() => setPayingOut(o)}
                      >
                        Record payout
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>

      <Card title={`Awaiting refund (${d.awaiting_refund.count})`}>
        {awaitingRefund.length === 0 ? (
          <EmptyState>{search ? 'No matches.' : 'Nothing pending.'}</EmptyState>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Item</th>
                <th>Amount</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {awaitingRefund.map((o) => (
                <tr key={o.id}>
                  <td>
                    <Link to={`/orders/${o.id}`}>{o.item_description}</Link>
                  </td>
                  <td>{money(o.shopper_total ?? o.total_price)}</td>
                  <td>
                    <button type="button" className="btn btn-small" onClick={() => setRefunding(o)}>
                      Record refund
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Card title={`Recent payouts (${d.paid_out.count})`}>
        {paidOut.length === 0 ? (
          <EmptyState>{search ? 'No matches.' : 'None recorded yet.'}</EmptyState>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Item</th>
                <th>Amount</th>
                <th>Method</th>
                <th>Reference</th>
                <th>Paid to</th>
              </tr>
            </thead>
            <tbody>
              {paidOut.map((p) => (
                <tr key={p.id}>
                  <td>
                    <Link to={`/orders/${p.order_id}`}>{p.item_description}</Link>
                  </td>
                  <td>{money(p.amount)}</td>
                  <td>{p.method}</td>
                  <td>{p.reference}</td>
                  <td>
                    {p.bank_name && p.bank_account_number ? (
                      `${p.bank_name} · ${p.bank_account_number}`
                    ) : (
                      <span className="muted">—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Card title={`Recent refunds (${d.refunded.count})`}>
        {refunded.length === 0 ? (
          <EmptyState>{search ? 'No matches.' : 'None recorded yet.'}</EmptyState>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Item</th>
                <th>Amount</th>
                <th>Method</th>
                <th>Reference</th>
              </tr>
            </thead>
            <tbody>
              {refunded.map((r) => (
                <tr key={r.id}>
                  <td>
                    <Link to={`/orders/${r.order_id}`}>{r.item_description}</Link>
                  </td>
                  <td>{money(r.amount)}</td>
                  <td>{r.method}</td>
                  <td>{r.reference}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <MoneyActionDialog
        open={payingOut !== null}
        title="Record payout"
        description="Record that you've sent the traveler their payout out of band. The destination account is the traveler's own — from their Account page — and can't be changed here."
        amount={money(payingOut?.traveller_payout ?? payingOut?.total_price)}
        context={payingOut?.item_description ?? ''}
        destination={
          payingOut?.bank_name && payingOut?.bank_account_number
            ? { label: 'Paying to', value: `${payingOut.bank_name} · ${payingOut.bank_account_number}` }
            : null
        }
        confirmLabel="Record payout"
        onClose={() => setPayingOut(null)}
        onConfirm={async (input) => {
          if (!payingOut) return;
          await payout.mutateAsync({ order_id: payingOut.id, ...input });
        }}
      />

      <MoneyActionDialog
        open={refunding !== null}
        title="Record refund"
        description="Record that you've refunded the shopper out of band."
        amount={money(refunding?.shopper_total ?? refunding?.total_price)}
        context={refunding?.item_description ?? ''}
        confirmLabel="Record refund"
        onClose={() => setRefunding(null)}
        onConfirm={async (input) => {
          if (!refunding) return;
          await refund.mutateAsync({ orderId: refunding.id, ...input });
        }}
      />
    </div>
  );
}
