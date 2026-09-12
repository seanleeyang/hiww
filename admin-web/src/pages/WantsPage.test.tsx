import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WantsPage } from './WantsPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { AdminUser, Want } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

function want(overrides: Partial<Want> = {}): Want {
  return {
    id: 'want-1',
    shopper_id: 'shopper-1',
    item_description: 'A test item',
    source_country: 'US',
    category: 'beauty',
    budget: '100.00',
    status: 'open',
    created_at: new Date().toISOString(),
    shopper_email: 'shopper@example.com',
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

function renderPage(wants: Want[], users: AdminUser[] = [adminUser()]) {
  vi.mocked(api.get).mockImplementation((url: string) =>
    Promise.resolve(url.startsWith('/admin/users') ? { users } : { requests: wants })
  );
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <WantsPage />
      </ToastProvider>
    </QueryClientProvider>
  );
}

describe('WantsPage', () => {
  it('filters by status', async () => {
    const testUser = userEvent.setup();
    renderPage([
      want({ id: 'a', item_description: 'Open item', status: 'open' }),
      want({ id: 'b', item_description: 'Cancelled item', status: 'cancelled' }),
    ]);

    expect(await screen.findByText('Open item')).toBeInTheDocument();
    expect(screen.getByText('Cancelled item')).toBeInTheDocument();

    await testUser.selectOptions(screen.getByDisplayValue('All statuses'), 'cancelled');
    expect(screen.getByText('Cancelled item')).toBeInTheDocument();
    expect(screen.queryByText('Open item')).not.toBeInTheDocument();
  });

  it('finds a want by its shopper\'s membership ID', async () => {
    const testUser = userEvent.setup();
    renderPage(
      [
        want({ id: 'a', item_description: 'Alice item', shopper_id: 'shopper-1' }),
        want({ id: 'b', item_description: 'Bob item', shopper_id: 'shopper-2' }),
      ],
      [adminUser({ id: 'shopper-1', membership_id: 'H00000001' }), adminUser({ id: 'shopper-2', membership_id: 'H00000002' })]
    );

    await screen.findByText('Alice item');
    await testUser.type(screen.getByPlaceholderText('Search by item, shopper, or member ID…'), 'H00000002');
    expect(screen.getByText('Bob item')).toBeInTheDocument();
    expect(screen.queryByText('Alice item')).not.toBeInTheDocument();
  });
});
