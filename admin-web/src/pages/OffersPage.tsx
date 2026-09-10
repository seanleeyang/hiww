import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminOffer } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { StatusPill } from '../components/StatusPill';
import { dateTime, money } from '../lib/format';

export function OffersPage() {
  const offers = useQuery({ queryKey: ['admin-offers'], queryFn: () => api.get<{ offers: AdminOffer[] }>('/admin/offers') });

  if (offers.isLoading) return <LoadingState />;
  if (offers.isError) return <ErrorState error={offers.error} onRetry={() => offers.refetch()} />;

  return (
    <div>
      <PageHeader title="Offers" subtitle="The negotiation layer between a want and an order — read-only." />

      {offers.data!.offers.length === 0 ? (
        <EmptyState>No offers yet.</EmptyState>
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
            {offers.data!.offers.map((o) => (
              <tr key={o.id}>
                <td>{o.item_description}</td>
                <td>{o.shopper_name}</td>
                <td>{o.traveler_name}</td>
                <td>{money(o.quoted_price)}</td>
                <td>{o.round}</td>
                <td>
                  <StatusPill
                    label={o.status}
                    tone={o.status === 'accepted' ? 'positive' : o.status === 'rejected' || o.status === 'expired' ? 'negative' : 'neutral'}
                  />
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
