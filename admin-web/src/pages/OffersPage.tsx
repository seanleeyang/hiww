import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminOffer } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { dateTime, money } from '../lib/format';
import { lifecycleTone, offerStatusLabel } from '../lib/status';

export function OffersPage() {
  const offers = useQuery({ queryKey: ['admin-offers'], queryFn: () => api.get<{ offers: AdminOffer[] }>('/admin/offers') });
  const [search, setSearch] = useState('');

  const filtered = useMemo(() => {
    const items = offers.data?.offers ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter(
      (o) =>
        o.item_description.toLowerCase().includes(q) ||
        o.shopper_name.toLowerCase().includes(q) ||
        o.traveler_name.toLowerCase().includes(q)
    );
  }, [offers.data, search]);

  if (offers.isLoading) return <LoadingState />;
  if (offers.isError) return <ErrorState error={offers.error} onRetry={() => offers.refetch()} />;

  return (
    <div>
      <PageHeader title="Offers" subtitle="The negotiation layer between a want and an order — read-only." />

      <input
        placeholder="Search by item, shopper, or traveler…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 16, maxWidth: 320 }}
      />

      {filtered.length === 0 ? (
        <EmptyState>{search ? 'No offers match your search.' : 'No offers yet.'}</EmptyState>
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
