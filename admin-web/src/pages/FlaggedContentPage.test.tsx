import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { FlaggedContentPage } from './FlaggedContentPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { QueueItem } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

type MessageItem = Extract<QueueItem, { type: 'message' }>;

function messageItem(overrides: Partial<MessageItem> = {}): MessageItem {
  return {
    type: 'message',
    id: 'msg-1',
    order_id: 'order-1',
    sender_id: 'user-1',
    sender_name: 'Test Sender',
    body: 'call me on 0812345678 instead',
    risk: 'medium',
    flags: ['Contains a phone number'],
    summary: null,
    hidden: false,
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function renderPage(items: MessageItem[]) {
  vi.mocked(api.get).mockResolvedValue({ queue: items });
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <MemoryRouter>
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <FlaggedContentPage />
        </ToastProvider>
      </QueryClientProvider>
    </MemoryRouter>
  );
}

describe('FlaggedContentPage', () => {
  it('offers a "Hide from both" action for a flagged message still visible in the chat', async () => {
    const testUser = userEvent.setup();
    vi.mocked(api.post).mockResolvedValue({});
    renderPage([messageItem()]);

    await testUser.click(await screen.findByRole('button', { name: 'Messages (1)' }));
    const hideButton = await screen.findByRole('button', { name: 'Hide from both' });
    await testUser.click(hideButton);

    expect(api.post).toHaveBeenCalledWith('/admin/messages/msg-1/hide');
  });

  it('does not offer "Hide from both" for a message the AI check already hid', async () => {
    const testUser = userEvent.setup();
    renderPage([messageItem({ hidden: true, risk: 'high' })]);

    await testUser.click(await screen.findByRole('button', { name: 'Messages (1)' }));
    expect(await screen.findByText('Hidden from both parties')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Hide from both' })).not.toBeInTheDocument();
  });

  it('clear-flag still works for restoring a message', async () => {
    const testUser = userEvent.setup();
    vi.mocked(api.post).mockResolvedValue({});
    renderPage([messageItem({ hidden: true, risk: 'high' })]);

    await testUser.click(await screen.findByRole('button', { name: 'Messages (1)' }));
    await testUser.click(await screen.findByRole('button', { name: 'Clear flag' }));

    expect(api.post).toHaveBeenCalledWith('/admin/messages/msg-1/clear-flag');
  });
});
