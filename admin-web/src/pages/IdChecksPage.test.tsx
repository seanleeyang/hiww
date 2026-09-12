import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { IdChecksPage } from './IdChecksPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { QueueItem } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

type KycItem = Extract<QueueItem, { type: 'kyc' }>;

function kycItem(overrides: Partial<KycItem> = {}): KycItem {
  return {
    type: 'kyc',
    id: 'kyc-1',
    status: 'pending',
    user_id: 'user-1',
    email: 'traveler@example.com',
    full_name: 'Test Traveler',
    document_type: 'id_card',
    document_id: '1-2345-67890-12-3',
    first_name: 'Test',
    last_name: 'Traveler',
    address: '99 Sukhumvit Rd',
    document_photo_url: 'https://files.example.com/doc.jpg',
    selfie_photo_url: 'https://files.example.com/selfie.jpg',
    ai_risk: null,
    ai_analysis: null,
    submitted_at: new Date().toISOString(),
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function renderPage(items: KycItem[]) {
  vi.mocked(api.get).mockResolvedValue({ queue: items });
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <IdChecksPage />
      </ToastProvider>
    </QueryClientProvider>
  );
}

describe('IdChecksPage', () => {
  it('renders the document and selfie photos as visible thumbnails, not just links', async () => {
    renderPage([kycItem()]);

    const doc = await screen.findByAltText('Document photo');
    const selfie = await screen.findByAltText('Selfie with document');
    expect(doc.tagName).toBe('IMG');
    expect(doc).toHaveAttribute('src', 'https://files.example.com/doc.jpg');
    expect(selfie).toHaveAttribute('src', 'https://files.example.com/selfie.jpg');
  });

  it('shows a passed preliminary check with no flagged issues when AI risk is low', async () => {
    renderPage([
      kycItem({
        ai_risk: 'low',
        ai_analysis: {
          summary: 'Everything matches.',
          flags: [],
          nameMatch: 'match',
          documentIdMatch: 'match',
          addressMatch: 'match',
          faceMatch: 'match',
          documentAuthenticity: 'plausible',
        },
      }),
    ]);

    expect(await screen.findByText('Preliminary AI check: Passed')).toBeInTheDocument();
    expect(screen.getByText('Everything matches.')).toBeInTheDocument();
  });

  it('lists the specific issues an admin should focus on when the AI check flags a submission', async () => {
    renderPage([
      kycItem({
        ai_risk: 'high',
        ai_analysis: {
          summary: 'Selfie does not look like the same person.',
          flags: ['Face looks different from the document photo'],
          nameMatch: 'match',
          documentIdMatch: 'match',
          addressMatch: 'match',
          faceMatch: 'mismatch',
          documentAuthenticity: 'plausible',
        },
      }),
    ]);

    expect(await screen.findByText('Preliminary AI check: Needs manual review')).toBeInTheDocument();
    expect(screen.getByText('Face: mismatch')).toBeInTheDocument();
    expect(screen.getByText('Face looks different from the document photo')).toBeInTheDocument();
  });

  it('shows what the document actually reads for a mismatched field, not just the verdict', async () => {
    renderPage([
      kycItem({
        first_name: 'Somchai',
        last_name: 'Jaidee',
        ai_risk: 'high',
        ai_analysis: {
          summary: 'Name on the form does not match the document.',
          flags: [],
          extracted: { firstName: 'สมชาย', lastName: 'ใจดี', documentId: null, address: null },
          nameMatch: 'mismatch',
          documentIdMatch: 'match',
          addressMatch: 'match',
          faceMatch: 'match',
          documentAuthenticity: 'plausible',
        },
      }),
    ]);

    // An admin shouldn't have to open the photo and read it themselves to
    // find out what "Name: mismatch" even means.
    expect(await screen.findByText('Name')).toBeInTheDocument();
    expect(screen.getByText('สมชาย ใจดี')).toBeInTheDocument();
    // Face matched, so it stays out of this comparison table (no text to
    // compare for a photo match) and isn't in the generic issues list either.
    expect(screen.queryByText('Face: mismatch')).not.toBeInTheDocument();
  });

  it('rejects with a fixed reason and notifies the user why', async () => {
    const testUser = userEvent.setup();
    renderPage([kycItem()]);

    await testUser.click(await screen.findByRole('button', { name: 'Reject' }));
    const dialog = await screen.findByRole('dialog', { name: 'Reject ID check' });
    await testUser.selectOptions(within(dialog).getByRole('combobox'), 'selfie_mismatch');
    await testUser.click(within(dialog).getByRole('button', { name: 'Reject' }));

    expect(api.post).toHaveBeenCalledWith('/admin/users/user-1/kyc-review', {
      status: 'rejected',
      reason_code: 'selfie_mismatch',
      note: undefined,
    });
  });

  it('hides a card the instant it is approved, without waiting on the list to refetch', async () => {
    const testUser = userEvent.setup();
    vi.mocked(api.post).mockResolvedValue({});
    // The mock keeps returning the same item forever — the query itself
    // never reports it as gone. If it disappears anyway, that's the
    // client-side "hide what I just decided" guard doing its job, not a
    // network refetch.
    renderPage([kycItem()]);

    await testUser.click(await screen.findByRole('button', { name: 'Approve' }));

    await screen.findByText('Nothing pending.');
    expect(screen.queryByText('Test Traveler')).not.toBeInTheDocument();
  });
});
