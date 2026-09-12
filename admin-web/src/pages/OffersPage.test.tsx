import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { OffersPage } from './OffersPage';
import { api } from '../api/client';
import type { AdminOffer, AdminUser } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

function offer(overrides: Partial<AdminOffer> = {}): AdminOffer {
  return {
    id: 'offer-1',
    request_id: 'want-1',
    quoted_price: '100.00',
    status: 'pending',
    round: 0,
    created_at: new Date().toISOString(),
    item_description: 'A test item',
    traveler_id: 'traveler-1',
    traveler_name: 'Test Traveler',
    shopper_id: 'shopper-1',
    shopper_name: 'Test Shopper',
    ...overrides,
  };
}

function adminUser(overrides: Partial<AdminUser> = {}): AdminUser {
  return {
    id: 'shopper-1',
    membership_id: 'H00000001',
    email: 'shopper@example.com',
    full_name: 'Test Shopper',
    user_type: 'shopper',
    role: 'user',
    kyc_status: 'approved',
    risk_status: 'clear',
    violation_count: 0,
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function renderPage(offers: AdminOffer[], users: AdminUser[] = [adminUser()]) {
  vi.mocked(api.get).mockImplementation((url: string) =>
    Promise.resolve(url.startsWith('/admin/users') ? { users } : { offers })
  );
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <OffersPage />
    </QueryClientProvider>
  );
}

describe('OffersPage', () => {
  it('filters by status', async () => {
    const testUser = userEvent.setup();
    renderPage([
      offer({ id: 'a', item_description: 'Pending offer', status: 'pending' }),
      offer({ id: 'b', item_description: 'Expired offer', status: 'expired' }),
    ]);

    expect(await screen.findByText('Pending offer')).toBeInTheDocument();
    expect(screen.getByText('Expired offer')).toBeInTheDocument();

    await testUser.selectOptions(screen.getByDisplayValue('All statuses'), 'expired');
    expect(screen.getByText('Expired offer')).toBeInTheDocument();
    expect(screen.queryByText('Pending offer')).not.toBeInTheDocument();
  });

  it('finds an offer by either party\'s membership ID', async () => {
    const testUser = userEvent.setup();
    renderPage(
      [
        offer({ id: 'a', item_description: 'Alice offer', shopper_id: 'shopper-1', traveler_id: 'traveler-1' }),
        offer({ id: 'b', item_description: 'Bob offer', shopper_id: 'shopper-2', traveler_id: 'traveler-2' }),
      ],
      [
        adminUser({ id: 'shopper-1', membership_id: 'H00000001' }),
        adminUser({ id: 'traveler-1', membership_id: 'H00000002' }),
        adminUser({ id: 'shopper-2', membership_id: 'H00000003' }),
        adminUser({ id: 'traveler-2', membership_id: 'H00000004' }),
      ]
    );

    await screen.findByText('Alice offer');
    await testUser.type(
      screen.getByPlaceholderText('Search by item, shopper, traveler, or member ID…'),
      'H00000004'
    );
    expect(screen.getByText('Bob offer')).toBeInTheDocument();
    expect(screen.queryByText('Alice offer')).not.toBeInTheDocument();
  });
});
