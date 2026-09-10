import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminUser, Order } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { orderStatusLabel, orderStatusTone } from '../lib/status';
import { dateTime, money } from '../lib/format';

const PAGE_LIMIT = 100;

export function OrdersListPage() {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const orders = useQuery({
    queryKey: ['orders'],
    queryFn: () => api.get<{ items: Order[] }>(`/orders?limit=${PAGE_LIMIT}`),
  });
  const users = useQuery({ queryKey: ['admin-users'], queryFn: () => api.get<{ users: AdminUser[] }>('/admin/users') });

  const nameById = useMemo(
    () => new Map((users.data?.users ?? []).map((u) => [u.id, u.full_name])),
    [users.data]
  );

  const filtered = useMemo(() => {
    const items = orders.data?.items ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((o) => {
      const shopperName = nameById.get(o.shopper_id) ?? '';
      const travelerName = nameById.get(o.traveler_id) ?? '';
      return (
        o.item_description.toLowerCase().includes(q) ||
        shopperName.toLowerCase().includes(q) ||
        travelerName.toLowerCase().includes(q)
      );
    });
  }, [orders.data, search, nameById]);

  if (orders.isLoading) return <LoadingState />;
  if (orders.isError) return <ErrorState error={orders.error} onRetry={() => orders.refetch()} />;

  const hitLimit = (orders.data?.items.length ?? 0) >= PAGE_LIMIT;

  return (
    <div>
      <PageHeader title="Orders" subtitle="Every order on the platform. Open one to confirm payment, cancel, or record money movement." />

      <input
        placeholder="Search by item, shopper, or traveler…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 16, maxWidth: 320 }}
      />

      {hitLimit && !search && (
        <p className="muted" style={{ marginTop: -8, marginBottom: 16, fontSize: 12.5 }}>
          Showing the most recent {PAGE_LIMIT} orders — search above to find an older one.
        </p>
      )}

      {filtered.length === 0 ? (
        <EmptyState>{search ? 'No orders match your search.' : 'No orders yet.'}</EmptyState>
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
            {filtered.map((o) => (
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
