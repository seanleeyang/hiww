import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { OrderDetailPage } from './OrderDetailPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { Order } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

function baseOrder(overrides: Partial<Order>): Order {
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

function renderOrderDetail(order: Order) {
  vi.mocked(api.get).mockImplementation(async (path: string) => {
    if (path.startsWith('/orders/')) return order;
    if (path === '/admin/users') return { users: [] };
    if (path === '/admin/reviews') return { queue: [] };
    throw new Error(`unexpected path ${path}`);
  });

  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <MemoryRouter initialEntries={[`/orders/${order.id}`]}>
          <Routes>
            <Route path="/orders/:id" element={<OrderDetailPage />} />
          </Routes>
        </MemoryRouter>
      </ToastProvider>
    </QueryClientProvider>
  );
}

describe('OrderDetailPage action set', () => {
  it('offers "Confirm payment" and "Cancel order" while pending payment', async () => {
    renderOrderDetail(baseOrder({ status: 'pending_payment' }));

    expect(await screen.findByRole('button', { name: 'Confirm payment' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Cancel order' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Record payout' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Record refund' })).not.toBeInTheDocument();
  });

  it('offers "Record payout" and "Cancel order" once delivered', async () => {
    renderOrderDetail(baseOrder({ status: 'delivered', confirmed_at: new Date().toISOString(), delivered_at: new Date().toISOString() }));

    expect(await screen.findByRole('button', { name: 'Record payout' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Cancel order' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Confirm payment' })).not.toBeInTheDocument();
  });

  it('offers "Record refund" and hides "Cancel order" once cancelled with confirmed payment', async () => {
    renderOrderDetail(
      baseOrder({ status: 'cancelled', confirmed_at: new Date().toISOString(), cancelled_at: new Date().toISOString() })
    );

    expect(await screen.findByRole('button', { name: 'Record refund' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Cancel order' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Confirm payment' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Record payout' })).not.toBeInTheDocument();
  });

  it('hides "Record payout" once a linked dispute is open', async () => {
    const order = baseOrder({ status: 'delivered', confirmed_at: new Date().toISOString(), delivered_at: new Date().toISOString() });
    vi.mocked(api.get).mockImplementation(async (path: string) => {
      if (path.startsWith('/orders/')) return order;
      if (path === '/admin/users') return { users: [] };
      if (path === '/admin/reviews') {
        return { queue: [{ type: 'dispute', id: 'd1', order_id: order.id, initiator_id: 'x', reason: 'issue', status: 'open', created_at: new Date().toISOString() }] };
      }
      throw new Error(`unexpected path ${path}`);
    });

    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <MemoryRouter initialEntries={[`/orders/${order.id}`]}>
            <Routes>
              <Route path="/orders/:id" element={<OrderDetailPage />} />
            </Routes>
          </MemoryRouter>
        </ToastProvider>
      </QueryClientProvider>
    );

    await waitFor(() => expect(screen.getByText(/open dispute/i)).toBeInTheDocument());
    expect(screen.queryByRole('button', { name: 'Record payout' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Cancel order' })).not.toBeInTheDocument();
  });

  it('warns about the specific refund amount when cancelling an order with confirmed payment', async () => {
    const order = baseOrder({
      status: 'confirmed',
      confirmed_at: new Date().toISOString(),
      shopper_total: '150.00',
    });
    renderOrderDetail(order);

    const cancelButton = await screen.findByRole('button', { name: 'Cancel order' });
    cancelButton.click();

    const description = await screen.findByText(/already been confirmed/i);
    expect(description.textContent).toContain('฿150.00');
  });

  it('does not warn about a refund when cancelling an order with no confirmed payment', async () => {
    renderOrderDetail(baseOrder({ status: 'pending_payment' }));

    const cancelButton = await screen.findByRole('button', { name: 'Cancel order' });
    cancelButton.click();

    expect(await screen.findByText(/no refund obligation/i)).toBeInTheDocument();
  });

  it('shows the payout amount inside the "Record payout" dialog', async () => {
    renderOrderDetail(
      baseOrder({
        status: 'delivered',
        confirmed_at: new Date().toISOString(),
        delivered_at: new Date().toISOString(),
        traveller_payout: '85.50',
      })
    );

    const payoutButton = await screen.findByRole('button', { name: 'Record payout' });
    payoutButton.click();

    expect(await screen.findByText('฿85.50')).toBeInTheDocument();
  });
});
