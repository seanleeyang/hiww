import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import type { OpsOverview, QueueItem, Reconciliation } from '../api/types';
import { PageHeader, Stat, StatGrid, LoadingState, ErrorState } from '../components/ui';
import { money } from '../lib/format';

function StatLink({ to, value, label }: { to: string; value: string | number; label: string }) {
  return (
    <Link to={to} className="stat stat-link">
      <div className="stat-value">{value}</div>
      <div className="stat-label">
        {label}
        <span className="stat-link-arrow">→</span>
      </div>
    </Link>
  );
}

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

      <h3 className="dashboard-section-label">Overview</h3>
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

      <h3 className="dashboard-section-label">Needs attention — tap to open</h3>
      <StatGrid>
        <StatLink to="/disputes" value={openDisputes} label="Open disputes" />
        <StatLink to="/id-checks" value={pendingIdChecks} label="Pending ID checks" />
        <StatLink to="/flagged" value={flaggedContent} label="Flagged content" />
        {recon.data && (
          <>
            <StatLink to="/money" value={money(recon.data.awaiting_payout.total)} label="Awaiting payout" />
            <StatLink to="/money" value={money(recon.data.awaiting_refund.total)} label="Awaiting refund" />
          </>
        )}
      </StatGrid>
    </div>
  );
}
