import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { api, ApiError } from '../api/client';
import { Card, PageHeader } from '../components/ui';

export function DevToolsPage() {
  const [lastOrderId, setLastOrderId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const createTestOrder = useMutation({
    mutationFn: () => api.post<{ order_id: string }>('/admin/dev/create-test-order'),
    onSuccess: (data) => {
      setError(null);
      setLastOrderId(data.order_id);
    },
    onError: (err) => setError(err instanceof ApiError ? err.message : 'Failed to create a test order'),
  });

  return (
    <div>
      <PageHeader title="Developer tools" subtitle="For local testing and demos — not part of day-to-day operations." />

      <Card title="Create a test order">
        <p className="muted">
          Registers two throwaway users, completes their profile, posts a want and a trip, makes an offer, and
          accepts it — a real order in <code>pending_payment</code>, ready to exercise every admin action against
          (confirm payment, cancel, open a dispute, etc.) from its detail page.
        </p>
        <button type="button" className="btn btn-primary" onClick={() => createTestOrder.mutate()} disabled={createTestOrder.isPending}>
          {createTestOrder.isPending ? 'Creating…' : 'Create a test order'}
        </button>
        {error && <p className="form-error" style={{ marginTop: 10 }}>{error}</p>}
        {lastOrderId && (
          <p style={{ marginTop: 10 }}>
            Created — <Link to={`/orders/${lastOrderId}`}>open order {lastOrderId.slice(0, 8)}</Link>
          </p>
        )}
      </Card>
    </div>
  );
}
