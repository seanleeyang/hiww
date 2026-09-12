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

interface FieldComparison {
  field: string;
  match: FieldMatch;
  extracted: string;
}

/** For each field the AI flagged as mismatched/unclear against the
 * document, what it actually read off the document photo — so the admin
 * can see the discrepancy at a glance instead of having to open the photo
 * and read it themselves to find out what "mismatch" even means. Face has
 * no text to compare (it's a photo match, already shown as a thumbnail),
 * so it's not part of this table. */
function fieldComparisons(item: KycItem): FieldComparison[] {
  const ai = item.ai_analysis;
  if (!ai) return [];
  const ex = ai.extracted ?? {};
  const candidates: Array<{ field: string; match: FieldMatch | undefined; extracted: string }> = [
    {
      field: 'Name',
      match: ai.nameMatch,
      extracted: [ex.firstName, ex.lastName].filter(Boolean).join(' '),
    },
    { field: 'Document number', match: ai.documentIdMatch, extracted: ex.documentId ?? '' },
    { field: 'Address', match: ai.addressMatch, extracted: ex.address ?? '' },
  ];
  return candidates.filter((c): c is FieldComparison => c.match != null && c.match !== 'match');
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
  // A decided item leaves this queue once `admin-reviews` refetches (it only
  // lists pending ones) -- but that refetch is async, so there's a brief
  // window right after a successful decision where the card (and its
  // buttons) would otherwise still be sitting there, clickable, on stale
  // data. Hiding by id the instant the mutation succeeds closes that gap
  // without waiting on the network.
  const [decidedUserIds, setDecidedUserIds] = useState<Set<string>>(new Set());

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
      setDecidedUserIds((prev) => new Set(prev).add(variables.userId));
      qc.invalidateQueries({ queryKey: ['admin-reviews'] });
      toast(variables.status === 'approved' ? 'ID check approved' : 'ID check rejected — the user has been notified why');
    },
    onError: (err) => toast(err instanceof ApiError ? err.message : 'Something went wrong', 'error'),
  });

  if (queue.isLoading) return <LoadingState />;
  if (queue.isError) return <ErrorState error={queue.error} onRetry={() => queue.refetch()} />;

  const items =
    queue.data?.queue.filter((q): q is KycItem => q.type === 'kyc' && !decidedUserIds.has(q.user_id)) ?? [];

  return (
    <div>
      <PageHeader title="ID checks" subtitle="Accounts awaiting identity verification — shown to users as “ID check”." />

      {items.length === 0 ? (
        <EmptyState>Nothing pending.</EmptyState>
      ) : (
        items.map((item) => {
          const submittedName = [item.first_name, item.last_name].filter(Boolean).join(' ');
          const comparisons = fieldComparisons(item);
          const faceIssue = matchLabel('Face', item.ai_analysis?.faceMatch);
          const authenticityIssue =
            item.ai_analysis?.documentAuthenticity === 'suspicious' ? ['Document authenticity: suspicious'] : [];
          // Everything specific the AI check found wrong, for the admin's
          // manual pass to focus on — the field-level mismatches get their
          // own comparison table below (with what the document actually
          // shows), so only Face (a photo match, no text to compare) and
          // the model's own free-form flags land in this generic list.
          const issues = [...(faceIssue ? [faceIssue] : []), ...authenticityIssue, ...(item.ai_analysis?.flags ?? [])];
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
                    {comparisons.length > 0 && (
                      <table style={{ margin: '6px 0' }}>
                        <thead>
                          <tr>
                            <th>Field</th>
                            <th>Result</th>
                            <th>Document shows</th>
                          </tr>
                        </thead>
                        <tbody>
                          {comparisons.map((c) => (
                            <tr key={c.field}>
                              <td>{c.field}</td>
                              <td className="muted">{c.match}</td>
                              <td>{c.extracted || <span className="muted">unclear</span>}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
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
