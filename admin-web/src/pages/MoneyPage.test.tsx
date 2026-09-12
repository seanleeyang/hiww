import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { MoneyPage } from './MoneyPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { AdminUser, Reconciliation } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

function reconciliation(overrides: Partial<Reconciliation> = {}): Reconciliation {
  return {
    awaiting_payment: {
      count: 1,
      total: '100',
      claimed: 0,
      orders: [
        {
          id: 'order-1',
          item_description: 'Alice item',
          total_price: '100',
          fees: '10',
          shopper_id: 'shopper-1',
          traveler_id: 'traveler-1',
        },
      ],
    },
    awaiting_payout: { count: 0, total: '0', orders: [] },
    paid_out: {
      count: 1,
      total: '100',
      payouts: [
        {
          id: 'payout-1',
          order_id: 'order-2',
          amount: '100',
          method: 'Bank transfer',
          reference: 'REF-BOB-001',
          created_at: new Date().toISOString(),
          item_description: 'Bob item',
        },
      ],
    },
    awaiting_refund: { count: 0, total: '0', orders: [] },
    refunded: { count: 0, total: '0', refunds: [] },
    ...overrides,
  };
}

function adminUser(overrides: Partial<AdminUser> = {}): AdminUser {
  return {
    id: 'shopper-1',
    membership_id: 'H00000001',
    email: 'shopper@example.com',
    full_name: 'Alice Shopper',
    user_type: 'shopper',
    role: 'user',
    kyc_status: 'approved',
    risk_status: 'clear',
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function renderPage(recon: Reconciliation, users: AdminUser[] = [adminUser()]) {
  vi.mocked(api.get).mockImplementation((url: string) =>
    Promise.resolve(url.startsWith('/admin/users') ? { users } : recon)
  );
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <MemoryRouter>
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <MoneyPage />
        </ToastProvider>
      </QueryClientProvider>
    </MemoryRouter>
  );
}

describe('MoneyPage', () => {
  it('filters every table at once by a shopper\'s membership ID', async () => {
    const testUser = userEvent.setup();
    renderPage(reconciliation());

    expect(await screen.findByText('Alice item')).toBeInTheDocument();
    expect(screen.getByText('Bob item')).toBeInTheDocument();

    await testUser.type(
      screen.getByPlaceholderText('Search every table below by item or member ID…'),
      'H00000001'
    );
    expect(screen.getByText('Alice item')).toBeInTheDocument();
    expect(screen.queryByText('Bob item')).not.toBeInTheDocument();
  });

  it('filters a payout row (no party ids) by its reference text', async () => {
    const testUser = userEvent.setup();
    renderPage(reconciliation());

    await screen.findByText('Bob item');
    await testUser.type(
      screen.getByPlaceholderText('Search every table below by item or member ID…'),
      'REF-BOB'
    );
    expect(screen.getByText('Bob item')).toBeInTheDocument();
    expect(screen.queryByText('Alice item')).not.toBeInTheDocument();
  });
});
