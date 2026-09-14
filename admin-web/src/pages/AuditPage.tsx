import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client';
import type { AdminUser, AuditEntry } from '../api/types';
import { EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { dateTime } from '../lib/format';
import { AUDIT_ACTIONS } from '../lib/status';

/** A tappable thumbnail rather than a bare link — same pattern as
 * IdChecksPage's PhotoThumb, so an operator can actually SEE the flagged
 * photo on this page, not just trust a URL will open. */
function PhotoThumb({ url }: { url: string }) {
  return (
    <a href={url} target="_blank" rel="noreferrer" title="Open full-size">
      <img
        src={url}
        alt="Flagged upload"
        style={{
          width: 48,
          height: 48,
          objectFit: 'cover',
          borderRadius: 6,
          border: '1px solid var(--border, #ddd)',
          display: 'block',
        }}
      />
    </a>
  );
}

/** Everything else in `metadata` besides the image (already shown as a
 * thumbnail) — compact enough to sit in a table cell without derailing it. */
function MetadataDetails({ metadata }: { metadata: Record<string, unknown> }) {
  const { image_url: _imageUrl, ...rest } = metadata;
  if (Object.keys(rest).length === 0) return null;
  return (
    <details>
      <summary className="muted" style={{ cursor: 'pointer', fontSize: '0.85em' }}>
        Details
      </summary>
      <pre style={{ fontSize: '0.8em', margin: 0, whiteSpace: 'pre-wrap' }}>
        {JSON.stringify(rest, null, 2)}
      </pre>
    </details>
  );
}

export function AuditPage() {
  const [action, setAction] = useState('');
  const [targetType, setTargetType] = useState('');
  const [targetId, setTargetId] = useState('');
  const [actorQuery, setActorQuery] = useState('');

  const users = useQuery({ queryKey: ['admin-users'], queryFn: () => api.get<{ users: AdminUser[] }>('/admin/users') });

  // The backend filter needs an exact user id — resolve whatever the admin
  // typed (a membership ID, an email, or a name) against the loaded user
  // list rather than asking them to go find and paste a UUID.
  const actorId = useMemo(() => {
    const q = actorQuery.trim().toLowerCase();
    if (!q) return '';
    const match = (users.data?.users ?? []).find(
      (u) => u.membership_id.toLowerCase() === q || u.email.toLowerCase() === q
    );
    if (match) return match.id;
    const partial = (users.data?.users ?? []).find(
      (u) =>
        u.membership_id.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q) ||
        u.full_name.toLowerCase().includes(q)
    );
    return partial?.id ?? '';
  }, [actorQuery, users.data]);

  const params = new URLSearchParams({ limit: '100' });
  if (action) params.set('action', action);
  if (targetType) params.set('target_type', targetType);
  if (targetId) params.set('target_id', targetId);
  if (actorId) params.set('actor_id', actorId);

  const audit = useQuery({
    queryKey: ['admin-audit', action, targetType, targetId, actorId],
    queryFn: () => api.get<{ items: AuditEntry[] }>(`/admin/audit?${params.toString()}`),
  });

  return (
    <div>
      <PageHeader title="Audit log" subtitle="Every admin/system action, append-only." />

      <div className="card" style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
        <label style={{ flex: 1, minWidth: 160 }}>
          Action
          <select value={action} onChange={(e) => setAction(e.target.value)}>
            <option value="">All actions</option>
            {AUDIT_ACTIONS.map((a) => (
              <option key={a} value={a}>
                {a}
              </option>
            ))}
          </select>
        </label>
        <label style={{ flex: 1, minWidth: 160 }}>
          Target type
          <input value={targetType} onChange={(e) => setTargetType(e.target.value)} placeholder="e.g. order" />
        </label>
        <label style={{ flex: 1, minWidth: 160 }}>
          Target id
          <input value={targetId} onChange={(e) => setTargetId(e.target.value)} placeholder="exact id" />
        </label>
        <label style={{ flex: 1, minWidth: 160 }}>
          Actor
          <input
            value={actorQuery}
            onChange={(e) => setActorQuery(e.target.value)}
            placeholder="Name, email, or member ID"
          />
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
              <th></th>
            </tr>
          </thead>
          <tbody>
            {audit.data!.items.map((entry) => {
              const imageUrl =
                typeof entry.metadata?.image_url === 'string' ? entry.metadata.image_url : null;
              return (
                <tr key={entry.id}>
                  <td>{dateTime(entry.created_at)}</td>
                  <td>
                    <code>{entry.action}</code>
                  </td>
                  <td>
                    {entry.target_type} · {entry.target_id.slice(0, 8)}
                  </td>
                  <td>
                    {entry.summary}
                    <MetadataDetails metadata={entry.metadata} />
                  </td>
                  <td>{imageUrl ? <PhotoThumb url={imageUrl} /> : null}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}
