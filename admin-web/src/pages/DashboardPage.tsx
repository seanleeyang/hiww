import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import type { OpsOverview, QueueItem, Reconciliation } from '../api/types';
import { PageHeader, Stat, StatGrid, LoadingState, ErrorState } from '../components/ui';
import { money } from '../lib/format';

export function DashboardPage() {
  const overview = useQuery({ queryKey: ['ops-overview'], queryFn: () => api.get<OpsOverview>('/ops/overview') });
  const queue = useQuery({ queryKey: ['admin-reviews'], queryFn: () => api.get<{ queue: QueueItem[] }>('/admin/reviews') });
  const recon = useQuery({ queryKey: ['reconciliation'], queryFn: () => api.get<Reconciliation>('/ops/reconciliation') });

  const openDisputes = queue.data?.queue.filter((q) => q.type === 'dispute').length ?? 0;
  const pendingIdChecks = queue.data?.queue.filter((q) => q.type === 'kyc').length ?? 0;
  const flaggedContent = queue.data?.queue.filter((q) => q.type === 'receipt' || q.type === 'message').length ?? 0;

  return (
    <div>
      <PageHeader title="Dashboard" subtitle="What needs attention right now." />

      {overview.isLoading ? (
        <LoadingState />
      ) : overview.isError ? (
        <ErrorState error={overview.error} onRetry={() => overview.refetch()} />
      ) : (
        <StatGrid>
          <Stat label="Users" value={overview.data!.users} />
          <Stat label="Open wants" value={overview.data!.open_requests} />
          <Stat label="Published trips" value={overview.data!.published_trips} />
          <Stat label="Awaiting payment" value={overview.data!.pending_orders} />
        </StatGrid>
      )}

      <StatGrid>
        <Link to="/disputes" className="stat" style={{ textDecoration: 'none', color: 'inherit' }}>
          <div className="stat-value">{openDisputes}</div>
          <div className="stat-label">Open disputes</div>
        </Link>
        <Link to="/id-checks" className="stat" style={{ textDecoration: 'none', color: 'inherit' }}>
          <div className="stat-value">{pendingIdChecks}</div>
          <div className="stat-label">Pending ID checks</div>
        </Link>
        <Link to="/flagged" className="stat" style={{ textDecoration: 'none', color: 'inherit' }}>
          <div className="stat-value">{flaggedContent}</div>
          <div className="stat-label">Flagged content</div>
        </Link>
        {recon.data && (
          <>
            <Link to="/money" className="stat" style={{ textDecoration: 'none', color: 'inherit' }}>
              <div className="stat-value">{money(recon.data.awaiting_payout.total)}</div>
              <div className="stat-label">Awaiting payout</div>
            </Link>
            <Link to="/money" className="stat" style={{ textDecoration: 'none', color: 'inherit' }}>
              <div className="stat-value">{money(recon.data.awaiting_refund.total)}</div>
              <div className="stat-label">Awaiting refund</div>
            </Link>
          </>
        )}
      </StatGrid>
    </div>
  );
}
