import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminOffer, AdminUser } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { dateTime, money } from '../lib/format';
import { OFFER_STATUSES, lifecycleTone, offerStatusLabel } from '../lib/status';

export function OffersPage() {
  const offers = useQuery({ queryKey: ['admin-offers'], queryFn: () => api.get<{ offers: AdminOffer[] }>('/admin/offers') });
  const users = useQuery({ queryKey: ['admin-users'], queryFn: () => api.get<{ users: AdminUser[] }>('/admin/users') });
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  const membershipById = useMemo(
    () => new Map((users.data?.users ?? []).map((u) => [u.id, u.membership_id])),
    [users.data]
  );

  const filtered = useMemo(() => {
    let items = offers.data?.offers ?? [];
    if (statusFilter) items = items.filter((o) => o.status === statusFilter);
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter(
      (o) =>
        o.item_description.toLowerCase().includes(q) ||
        o.shopper_name.toLowerCase().includes(q) ||
        o.traveler_name.toLowerCase().includes(q) ||
        (membershipById.get(o.shopper_id) ?? '').toLowerCase().includes(q) ||
        (membershipById.get(o.traveler_id) ?? '').toLowerCase().includes(q)
    );
  }, [offers.data, search, statusFilter, membershipById]);

  if (offers.isLoading) return <LoadingState />;
  if (offers.isError) return <ErrorState error={offers.error} onRetry={() => offers.refetch()} />;

  return (
    <div>
      <PageHeader title="Offers" subtitle="The negotiation layer between a want and an order — read-only." />

      <div style={{ display: 'flex', gap: 12, marginBottom: 16, flexWrap: 'wrap' }}>
        <input
          placeholder="Search by item, shopper, traveler, or member ID…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ maxWidth: 320 }}
        />
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="">All statuses</option>
          {OFFER_STATUSES.map((s) => (
            <option key={s} value={s}>
              {offerStatusLabel(s)}
            </option>
          ))}
        </select>
      </div>

      {filtered.length === 0 ? (
        <EmptyState>{search || statusFilter ? 'No offers match your filters.' : 'No offers yet.'}</EmptyState>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Item</th>
              <th>Shopper</th>
              <th>Traveler</th>
              <th>Price</th>
              <th>Round</th>
              <th>Status</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((o) => (
              <tr key={o.id}>
                <td>{o.item_description}</td>
                <td>{o.shopper_name}</td>
                <td>{o.traveler_name}</td>
                <td>{money(o.quoted_price)}</td>
                <td>{o.round}</td>
                <td>
                  <StatusPill label={offerStatusLabel(o.status)} tone={lifecycleTone(o.status)} />
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
