import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { MoneyOrderRow, Reconciliation } from '../api/types';
import { Card, EmptyState, ErrorState, LoadingState, PageHeader, Stat, StatGrid } from '../components/ui';
import { MoneyActionDialog } from '../components/MoneyActionDialog';
import { useToast } from '../components/Toast';
import { money } from '../lib/format';

export function MoneyPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const recon = useQuery({ queryKey: ['reconciliation'], queryFn: () => api.get<Reconciliation>('/ops/reconciliation') });
  const [payingOut, setPayingOut] = useState<MoneyOrderRow | null>(null);
  const [refunding, setRefunding] = useState<MoneyOrderRow | null>(null);

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

  if (recon.isLoading) return <LoadingState />;
  if (recon.isError) return <ErrorState error={recon.error} onRetry={() => recon.refetch()} />;
  const d = recon.data!;

  return (
    <div>
      <PageHeader title="Money" subtitle="Manual-money pilot reconciliation — what's owed in, owed out, and settled." />

      <StatGrid>
        <Stat label="Awaiting payment" value={money(d.awaiting_payment.total)} />
        <Stat label="Awaiting payout" value={money(d.awaiting_payout.total)} />
        <Stat label="Paid out" value={money(d.paid_out.total)} />
        <Stat label="Awaiting refund" value={money(d.awaiting_refund.total)} />
        <Stat label="Refunded" value={money(d.refunded.total)} />
      </StatGrid>

      <Card title={`Awaiting payment (${d.awaiting_payment.count})`}>
        {d.awaiting_payment.orders.length === 0 ? (
          <EmptyState>Nothing pending.</EmptyState>
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
              {d.awaiting_payment.orders.map((o) => (
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
        {d.awaiting_payout.orders.length === 0 ? (
          <EmptyState>Nothing pending.</EmptyState>
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
              {d.awaiting_payout.orders.map((o) => {
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
        {d.awaiting_refund.orders.length === 0 ? (
          <EmptyState>Nothing pending.</EmptyState>
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
              {d.awaiting_refund.orders.map((o) => (
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
        {d.paid_out.payouts.length === 0 ? (
          <EmptyState>None recorded yet.</EmptyState>
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
              {d.paid_out.payouts.map((p) => (
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
        {d.refunded.refunds.length === 0 ? (
          <EmptyState>None recorded yet.</EmptyState>
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
              {d.refunded.refunds.map((r) => (
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
