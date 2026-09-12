import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { DisputesPage } from './DisputesPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { Dispute, QueueItem } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

type DisputeItem = Extract<QueueItem, { type: 'dispute' }>;

function disputeItem(overrides: Partial<Dispute> = {}): DisputeItem {
  return {
    type: 'dispute',
    id: 'dispute-1',
    order_id: 'order-1',
    initiator_id: 'user-1',
    reason: 'Item never arrived',
    status: 'open',
    resolution: null,
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function renderPage(items: DisputeItem[]) {
  vi.mocked(api.get).mockResolvedValue({ queue: items });
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <MemoryRouter>
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <DisputesPage />
        </ToastProvider>
      </QueryClientProvider>
    </MemoryRouter>
  );
}

describe('DisputesPage', () => {
  it('cancels with a picked common reason — no typing required', async () => {
    const testUser = userEvent.setup();
    vi.mocked(api.post).mockResolvedValue({});
    renderPage([disputeItem()]);

    await testUser.click(await screen.findByRole('button', { name: 'Cancel order & resolve' }));
    const dialog = await screen.findByRole('dialog', { name: 'Cancel order & resolve dispute' });
    const confirmButton = within(dialog).getByRole('button', { name: 'Cancel order' });
    expect(confirmButton).toBeEnabled();

    await testUser.click(confirmButton);

    expect(api.post).toHaveBeenCalledWith('/admin/orders/order-1/cancel', {
      reason: 'Item was never shipped by the traveler',
      dispute_id: 'dispute-1',
    });
  });

  it('requires a typed explanation when the reason is "Other"', async () => {
    const testUser = userEvent.setup();
    vi.mocked(api.post).mockResolvedValue({});
    renderPage([disputeItem()]);

    await testUser.click(await screen.findByRole('button', { name: 'Cancel order & resolve' }));
    const dialog = await screen.findByRole('dialog', { name: 'Cancel order & resolve dispute' });
    const confirmButton = within(dialog).getByRole('button', { name: 'Cancel order' });

    await testUser.selectOptions(within(dialog).getByRole('combobox'), 'other');
    expect(confirmButton).toBeDisabled();

    await testUser.type(within(dialog).getByRole('textbox'), 'A very specific one-off reason');
    expect(confirmButton).toBeEnabled();
    await testUser.click(confirmButton);

    expect(api.post).toHaveBeenCalledWith('/admin/orders/order-1/cancel', {
      reason: 'A very specific one-off reason',
      dispute_id: 'dispute-1',
    });
  });
});
