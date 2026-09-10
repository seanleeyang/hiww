import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AuditEntry } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { dateTime } from '../lib/format';

export function AuditPage() {
  const [action, setAction] = useState('');
  const [targetType, setTargetType] = useState('');
  const [targetId, setTargetId] = useState('');

  const params = new URLSearchParams({ limit: '100' });
  if (action) params.set('action', action);
  if (targetType) params.set('target_type', targetType);
  if (targetId) params.set('target_id', targetId);

  const audit = useQuery({
    queryKey: ['admin-audit', action, targetType, targetId],
    queryFn: () => api.get<{ items: AuditEntry[] }>(`/admin/audit?${params.toString()}`),
  });

  return (
    <div>
      <PageHeader title="Audit log" subtitle="Every admin/system action, append-only." />

      <div className="card" style={{ display: 'flex', gap: 16 }}>
        <label style={{ flex: 1 }}>
          Action
          <input value={action} onChange={(e) => setAction(e.target.value)} placeholder="e.g. order.admin_cancel" />
        </label>
        <label style={{ flex: 1 }}>
          Target type
          <input value={targetType} onChange={(e) => setTargetType(e.target.value)} placeholder="e.g. order" />
        </label>
        <label style={{ flex: 1 }}>
          Target id
          <input value={targetId} onChange={(e) => setTargetId(e.target.value)} placeholder="exact id" />
        </label>
      </div>

      {audit.isLoading ? (
        <LoadingState />
      ) : audit.isError ? (
        <ErrorState error={audit.error} onRetry={() => audit.refetch()} />
      ) : audit.data!.items.length === 0 ? (
        <EmptyState>No matching entries.</EmptyState>
      ) : (
        <table>
          <thead>
            <tr>
              <th>When</th>
              <th>Action</th>
              <th>Target</th>
              <th>Summary</th>
            </tr>
          </thead>
          <tbody>
            {audit.data!.items.map((entry) => (
              <tr key={entry.id}>
                <td>{dateTime(entry.created_at)}</td>
                <td>
                  <code>{entry.action}</code>
                </td>
                <td>
                  {entry.target_type} · {entry.target_id.slice(0, 8)}
                </td>
                <td>{entry.summary}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
