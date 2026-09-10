import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminUser, Order } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { orderStatusLabel, orderStatusTone } from '../lib/status';
import { dateTime, money } from '../lib/format';

export function OrdersListPage() {
  const navigate = useNavigate();
  const orders = useQuery({
    queryKey: ['orders'],
    queryFn: () => api.get<{ items: Order[] }>('/orders?limit=100'),
  });
  const users = useQuery({ queryKey: ['admin-users'], queryFn: () => api.get<{ users: AdminUser[] }>('/admin/users') });

  if (orders.isLoading) return <LoadingState />;
  if (orders.isError) return <ErrorState error={orders.error} onRetry={() => orders.refetch()} />;

  const nameById = new Map((users.data?.users ?? []).map((u) => [u.id, u.full_name]));

  return (
    <div>
      <PageHeader title="Orders" subtitle="Every order on the platform. Open one to confirm payment, cancel, or record money movement." />

      {orders.data!.items.length === 0 ? (
        <EmptyState>No orders yet.</EmptyState>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Item</th>
              <th>Shopper</th>
              <th>Traveler</th>
              <th>Total</th>
              <th>Status</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {orders.data!.items.map((o) => (
              <tr key={o.id} className="clickable" onClick={() => navigate(`/orders/${o.id}`)}>
                <td>{o.item_description}</td>
                <td>{nameById.get(o.shopper_id) ?? o.shopper_id.slice(0, 8)}</td>
                <td>{nameById.get(o.traveler_id) ?? o.traveler_id.slice(0, 8)}</td>
                <td>{money(o.total_price)}</td>
                <td>
                  <StatusPill label={orderStatusLabel(o.status)} tone={orderStatusTone(o.status)} />
                </td>
                <td>{dateTime(o.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
