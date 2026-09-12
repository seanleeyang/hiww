import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuditPage } from './AuditPage';
import { api } from '../api/client';
import type { AdminUser, AuditEntry } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

function entry(overrides: Partial<AuditEntry> = {}): AuditEntry {
  return {
    id: 'entry-1',
    actor_id: 'user-1',
    actor_role: 'admin',
    action: 'order.admin_cancel',
    target_type: 'order',
    target_id: 'order-1',
    summary: 'Operator cancelled order order-1',
    metadata: {},
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function adminUser(overrides: Partial<AdminUser> = {}): AdminUser {
  return {
    id: 'user-1',
    membership_id: 'H00000001',
    email: 'admin@example.com',
    full_name: 'Test Admin',
    user_type: 'both',
    role: 'admin',
    kyc_status: 'approved',
    risk_status: 'clear',
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function renderPage(entries: AuditEntry[], users: AdminUser[] = [adminUser()]) {
  const getMock = vi.fn((url: string) => {
    if (url.startsWith('/admin/users')) return Promise.resolve({ users });
    const params = new URLSearchParams(url.split('?')[1] ?? '');
    let filtered = entries;
    const actorId = params.get('actor_id');
    const action = params.get('action');
    if (actorId) filtered = filtered.filter((e) => e.actor_id === actorId);
    if (action) filtered = filtered.filter((e) => e.action === action);
    return Promise.resolve({ items: filtered, limit: 100 });
  });
  vi.mocked(api.get).mockImplementation(getMock as never);
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <AuditPage />
    </QueryClientProvider>
  );
}

describe('AuditPage', () => {
  it('offers a dropdown of known actions instead of free text', async () => {
    const testUser = userEvent.setup();
    renderPage([
      entry({ id: 'a', action: 'order.admin_cancel', summary: 'Cancelled order A' }),
      entry({ id: 'b', action: 'kyc.review', summary: 'Reviewed a KYC submission' }),
    ]);

    expect(await screen.findByText('Cancelled order A')).toBeInTheDocument();
    expect(screen.getByText('Reviewed a KYC submission')).toBeInTheDocument();

    await testUser.selectOptions(screen.getByDisplayValue('All actions'), 'kyc.review');
    expect(await screen.findByText('Reviewed a KYC submission')).toBeInTheDocument();
    expect(screen.queryByText('Cancelled order A')).not.toBeInTheDocument();
  });

  it('resolves a typed membership ID to the matching actor_id filter', async () => {
    const testUser = userEvent.setup();
    renderPage(
      [
        entry({ id: 'a', actor_id: 'user-1', summary: 'Action by admin one' }),
        entry({ id: 'b', actor_id: 'user-2', summary: 'Action by admin two' }),
      ],
      [adminUser({ id: 'user-1', membership_id: 'H00000001' }), adminUser({ id: 'user-2', membership_id: 'H00000002' })]
    );

    expect(await screen.findByText('Action by admin one')).toBeInTheDocument();
    expect(screen.getByText('Action by admin two')).toBeInTheDocument();

    await testUser.type(screen.getByPlaceholderText('Name, email, or member ID'), 'H00000002');
    expect(await screen.findByText('Action by admin two')).toBeInTheDocument();
    expect(screen.queryByText('Action by admin one')).not.toBeInTheDocument();
  });
});
