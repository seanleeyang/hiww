import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReviewsPage } from './ReviewsPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { AdminReview, AdminUser } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

function review(overrides: Partial<AdminReview> = {}): AdminReview {
  return {
    id: 'review-1',
    order_id: 'order-1',
    rating: 5,
    hidden_at: null,
    created_at: new Date().toISOString(),
    reviewer_id: 'reviewer-1',
    reviewer_name: 'Alice Reviewer',
    reviewee_id: 'reviewee-1',
    reviewee_name: 'Bob Reviewee',
    item_description: 'A test item',
    ...overrides,
  };
}

function adminUser(overrides: Partial<AdminUser> = {}): AdminUser {
  return {
    id: 'reviewer-1',
    membership_id: 'H00000001',
    email: 'reviewer@example.com',
    full_name: 'Alice Reviewer',
    user_type: 'shopper',
    role: 'user',
    kyc_status: 'approved',
    risk_status: 'clear',
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function renderPage(reviews: AdminReview[], users: AdminUser[] = [adminUser()]) {
  vi.mocked(api.get).mockImplementation((url: string) =>
    Promise.resolve(url.startsWith('/admin/users') ? { users } : { reviews })
  );
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <ReviewsPage />
      </ToastProvider>
    </QueryClientProvider>
  );
}

describe('ReviewsPage', () => {
  it('filters by visibility', async () => {
    const testUser = userEvent.setup();
    renderPage([
      review({ id: 'a', item_description: 'Visible review', hidden_at: null }),
      review({ id: 'b', item_description: 'Hidden review', hidden_at: new Date().toISOString() }),
    ]);

    expect(await screen.findByText(/Visible review/)).toBeInTheDocument();
    expect(screen.getByText(/Hidden review/)).toBeInTheDocument();

    await testUser.selectOptions(screen.getByDisplayValue('All reviews'), 'hidden');
    expect(screen.getByText(/Hidden review/)).toBeInTheDocument();
    expect(screen.queryByText(/Visible review/)).not.toBeInTheDocument();
  });

  it('finds a review by either party\'s membership ID', async () => {
    const testUser = userEvent.setup();
    renderPage(
      [
        review({ id: 'a', item_description: 'Alice-Bob item', reviewer_id: 'reviewer-1', reviewee_id: 'reviewee-1' }),
        review({ id: 'b', item_description: 'Carol-Dan item', reviewer_id: 'reviewer-2', reviewee_id: 'reviewee-2' }),
      ],
      [
        adminUser({ id: 'reviewer-1', membership_id: 'H00000001' }),
        adminUser({ id: 'reviewee-1', membership_id: 'H00000002' }),
        adminUser({ id: 'reviewer-2', membership_id: 'H00000003' }),
        adminUser({ id: 'reviewee-2', membership_id: 'H00000004' }),
      ]
    );

    await screen.findByText(/Alice-Bob item/);
    await testUser.type(
      screen.getByPlaceholderText('Search by name, item, comment, or member ID…'),
      'H00000004'
    );
    expect(screen.getByText(/Carol-Dan item/)).toBeInTheDocument();
    expect(screen.queryByText(/Alice-Bob item/)).not.toBeInTheDocument();
  });
});
