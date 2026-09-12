import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';
import type { QueueItem } from '../api/types';
import { Card, EmptyState, ErrorState, LoadingState, PageHeader } from '../components/ui';
import { KycRejectDialog, type KycRejectReason } from '../components/KycRejectDialog';
import { StatusPill } from '../components/StatusPill';
import { useToast } from '../components/Toast';
import { ApiError } from '../api/client';
import { dateTime } from '../lib/format';

type KycItem = Extract<QueueItem, { type: 'kyc' }>;
type FieldMatch = 'match' | 'mismatch' | 'unclear';

function docTypeLabel(type: NonNullable<KycItem['document_type']>): string {
  switch (type) {
    case 'passport':
      return 'Passport';
    case 'id_card':
      return 'ID card';
  }
}

function matchLabel(field: string, m: FieldMatch | undefined): string | null {
  if (!m || m === 'match') return null;
  return `${field}: ${m}`;
}

/** A tappable thumbnail rather than a bare link — the point is that an admin
 * can actually SEE the photo on this page, not just trust a URL will open. */
function PhotoThumb({ url, label }: { url: string; label: string }) {
  return (
    <a
      href={url}
      target="_blank"
      rel="noreferrer"
      style={{ display: 'block', textAlign: 'center', textDecoration: 'none' }}
      title={`Open full-size: ${label}`}
    >
      <img
        src={url}
        alt={label}
        style={{
          width: 140,
          height: 140,
          objectFit: 'cover',
          borderRadius: 8,
          border: '1px solid var(--border, #ddd)',
          display: 'block',
        }}
      />
      <span className="muted" style={{ fontSize: '0.85em' }}>
        {label}
      </span>
    </a>
  );
}

export function IdChecksPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const queue = useQuery({ queryKey: ['admin-reviews'], queryFn: () => api.get<{ queue: QueueItem[] }>('/admin/reviews') });
  const [rejecting, setRejecting] = useState<KycItem | null>(null);

  const review = useMutation({
    mutationFn: ({
      userId,
      status,
      reason_code,
      note,
    }: {
      userId: string;
      status: 'approved' | 'rejected';
      reason_code?: KycRejectReason;
      note?: string;
    }) => api.post(`/admin/users/${userId}/kyc-review`, { status, reason_code, note }),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: ['admin-reviews'] });
      toast(variables.status === 'approved' ? 'ID check approved' : 'ID check rejected — the user has been notified why');
    },
    onError: (err) => toast(err instanceof ApiError ? err.message : 'Something went wrong', 'error'),
  });

  if (queue.isLoading) return <LoadingState />;
  if (queue.isError) return <ErrorState error={queue.error} onRetry={() => queue.refetch()} />;

  const items = (queue.data?.queue.filter((q): q is KycItem => q.type === 'kyc')) ?? [];

  return (
    <div>
      <PageHeader title="ID checks" subtitle="Accounts awaiting identity verification — shown to users as “ID check”." />

      {items.length === 0 ? (
        <EmptyState>Nothing pending.</EmptyState>
      ) : (
        items.map((item) => {
          const submittedName = [item.first_name, item.last_name].filter(Boolean).join(' ');
          const mismatches = item.ai_analysis
            ? [
                matchLabel('Name', item.ai_analysis.nameMatch),
                matchLabel('Document number', item.ai_analysis.documentIdMatch),
                matchLabel('Address', item.ai_analysis.addressMatch),
                matchLabel('Face', item.ai_analysis.faceMatch),
              ].filter((m): m is string => m !== null)
            : [];
          const authenticityIssue =
            item.ai_analysis?.documentAuthenticity === 'suspicious' ? ['Document authenticity: suspicious'] : [];
          // Everything specific the AI check found wrong, for the admin's
          // manual pass to focus on — structured mismatches first, then the
          // model's own free-form flags (some overlap is fine; this is an
          // internal checklist, not user-facing copy).
          const issues = [...mismatches, ...authenticityIssue, ...(item.ai_analysis?.flags ?? [])];
          const passedPrelim = item.ai_risk === 'low';

          return (
          <Card key={item.id}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
              <div style={{ flex: '1 1 320px' }}>
                <strong>{item.full_name}</strong>
                <p className="muted" style={{ margin: '4px 0' }}>
                  {item.email} · {dateTime(item.created_at)}
                </p>
                {item.document_type && (
                  <p style={{ margin: '4px 0' }}>
                    {docTypeLabel(item.document_type)}
                    {item.document_id ? ` · ${item.document_id}` : ''}
                  </p>
                )}
                {submittedName && submittedName !== item.full_name && (
                  <p className="muted" style={{ margin: '4px 0' }}>
                    Name on form: {submittedName}
                  </p>
                )}
                {item.address && <p className="muted" style={{ margin: '4px 0' }}>Address: {item.address}</p>}

                {item.ai_risk && (
                  <div style={{ margin: '10px 0' }}>
                    <StatusPill
                      label={`Preliminary AI check: ${passedPrelim ? 'Passed' : 'Needs manual review'}`}
                      tone={passedPrelim ? 'positive' : item.ai_risk === 'high' ? 'negative' : 'warning'}
                    />
                    {item.ai_analysis?.summary && (
                      <p style={{ margin: '6px 0' }}>{item.ai_analysis.summary}</p>
                    )}
                    {issues.length > 0 && (
                      <ul style={{ margin: '6px 0', paddingLeft: 20 }}>
                        {issues.map((issue, i) => (
                          <li key={i} className="muted">
                            {issue}
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                )}
                {!item.ai_risk && (
                  <p className="muted" style={{ margin: '10px 0' }}>
                    Preliminary AI check hasn't completed yet — review the documents yourself below.
                  </p>
                )}
              </div>

              <div style={{ display: 'flex', gap: 12, flexShrink: 0 }}>
                {item.document_photo_url && <PhotoThumb url={item.document_photo_url} label="Document photo" />}
                {item.selfie_photo_url && <PhotoThumb url={item.selfie_photo_url} label="Selfie with document" />}
                {!item.document_photo_url && (
                  <p className="muted" style={{ margin: 0, maxWidth: 140 }}>
                    No document photo on file — submitted before this was required.
                  </p>
                )}
              </div>

              <div className="btn-row" style={{ flexShrink: 0 }}>
                <button
                  type="button"
                  className="btn btn-primary"
                  disabled={review.isPending}
                  onClick={() => review.mutate({ userId: item.user_id, status: 'approved' })}
                >
                  Approve
                </button>
                <button type="button" className="btn btn-danger" disabled={review.isPending} onClick={() => setRejecting(item)}>
                  Reject
                </button>
              </div>
            </div>
          </Card>
          );
        })
      )}

      <KycRejectDialog
        open={rejecting !== null}
        onClose={() => setRejecting(null)}
        onConfirm={async ({ reason_code, note }) => {
          if (!rejecting) return;
          await review.mutateAsync({ userId: rejecting.user_id, status: 'rejected', reason_code, note });
        }}
      />
    </div>
  );
}
