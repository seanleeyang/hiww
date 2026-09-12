import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { OrdersListPage } from './OrdersListPage';
import { api } from '../api/client';
import type { AdminUser, Order } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

function order(overrides: Partial<Order> = {}): Order {
  return {
    id: 'order-1',
    shopper_id: 'shopper-1',
    traveler_id: 'traveler-1',
    item_description: 'A test item',
    quantity: 1,
    unit_price: '100.00',
    total_price: '100.00',
    fees: '10.00',
    status: 'pending_payment',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
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

function renderPage(orders: Order[], users: AdminUser[]) {
  vi.mocked(api.get).mockImplementation((url: string) =>
    Promise.resolve(url.startsWith('/admin/users') ? { users } : { items: orders })
  );
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <MemoryRouter>
      <QueryClientProvider client={queryClient}>
        <OrdersListPage />
      </QueryClientProvider>
    </MemoryRouter>
  );
}

describe('OrdersListPage', () => {
  it('filters by status', async () => {
    const testUser = userEvent.setup();
    renderPage(
      [
        order({ id: 'a', item_description: 'Pending item', status: 'pending_payment' }),
        order({ id: 'b', item_description: 'Delivered item', status: 'delivered' }),
      ],
      [adminUser()]
    );

    expect(await screen.findByText('Pending item')).toBeInTheDocument();
    expect(screen.getByText('Delivered item')).toBeInTheDocument();

    await testUser.selectOptions(screen.getByDisplayValue('All statuses'), 'delivered');
    expect(screen.getByText('Delivered item')).toBeInTheDocument();
    expect(screen.queryByText('Pending item')).not.toBeInTheDocument();
  });

  it('finds an order by either party\'s membership ID', async () => {
    const testUser = userEvent.setup();
    renderPage(
      [
        order({ id: 'a', item_description: 'Alice order', shopper_id: 'shopper-1', traveler_id: 'traveler-1' }),
        order({ id: 'b', item_description: 'Bob order', shopper_id: 'shopper-2', traveler_id: 'traveler-2' }),
      ],
      [
        adminUser({ id: 'shopper-1', membership_id: 'H00000001' }),
        adminUser({ id: 'traveler-1', membership_id: 'H00000002' }),
        adminUser({ id: 'shopper-2', membership_id: 'H00000003' }),
        adminUser({ id: 'traveler-2', membership_id: 'H00000004' }),
      ]
    );

    await screen.findByText('Alice order');
    await testUser.type(
      screen.getByPlaceholderText('Search by item, shopper, traveler, or member ID…'),
      'H00000004'
    );
    expect(screen.getByText('Bob order')).toBeInTheDocument();
    expect(screen.queryByText('Alice order')).not.toBeInTheDocument();
  });
});
