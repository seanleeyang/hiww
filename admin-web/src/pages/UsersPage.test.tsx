import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { UsersPage } from './UsersPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { AdminUser } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

function user(overrides: Partial<AdminUser> = {}): AdminUser {
  return {
    id: 'user-1',
    membership_id: 'H00000001',
    email: 'shopper@example.com',
    full_name: 'Test Shopper',
    user_type: 'shopper',
    role: 'user',
    kyc_status: 'pending',
    risk_status: 'clear',
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function renderUsersPage(users: AdminUser[]) {
  vi.mocked(api.get).mockResolvedValue({ users });
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <UsersPage />
      </ToastProvider>
    </QueryClientProvider>
  );
}

describe('UsersPage', () => {
  it('rejects an ID check with a fixed reason — no free text required', async () => {
    const testUser = userEvent.setup();
    renderUsersPage([user()]);

    await testUser.click(await screen.findByRole('button', { name: 'Reject ID' }));

    // A dialog opens instead of the request firing immediately, defaulting
    // to the first fixed reason — no typing needed to submit.
    const dialog = await screen.findByRole('dialog', { name: 'Reject ID check' });
    const confirmButton = screen.getByRole('button', { name: 'Reject' });
    expect(confirmButton).toBeEnabled();
    expect(api.post).not.toHaveBeenCalled();

    await testUser.click(confirmButton);

    expect(api.post).toHaveBeenCalledWith('/admin/users/user-1/kyc-review', {
      status: 'rejected',
      reason_code: 'photo_unclear',
      note: undefined,
    });
    expect(dialog).not.toBeInTheDocument();
  });

  it('requires a typed explanation when the reason is "Other"', async () => {
    const testUser = userEvent.setup();
    renderUsersPage([user()]);

    await testUser.click(await screen.findByRole('button', { name: 'Reject ID' }));
    const dialog = await screen.findByRole('dialog', { name: 'Reject ID check' });
    const confirmButton = screen.getByRole('button', { name: 'Reject' });

    await testUser.selectOptions(within(dialog).getByRole('combobox'), 'other');
    expect(confirmButton).toBeDisabled();

    await testUser.type(within(dialog).getByRole('textbox'), 'Something else entirely');
    expect(confirmButton).toBeEnabled();
    await testUser.click(confirmButton);

    expect(api.post).toHaveBeenCalledWith('/admin/users/user-1/kyc-review', {
      status: 'rejected',
      reason_code: 'other',
      note: 'Something else entirely',
    });
    expect(dialog).not.toBeInTheDocument();
  });

  it('collapses Approve/Reject into a single "Reconsider" step once a decision exists', async () => {
    const testUser = userEvent.setup();
    renderUsersPage([user({ kyc_status: 'approved' })]);

    // Already decided — neither action button is just sitting there
    // clickable; only the deliberate "Reconsider" step is available.
    expect(await screen.findByRole('button', { name: 'Reconsider' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Approve ID' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Reject ID' })).not.toBeInTheDocument();

    await testUser.click(screen.getByRole('button', { name: 'Reconsider' }));

    // Only the flip action makes sense for an already-approved user.
    expect(screen.getByRole('button', { name: 'Reject ID' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Approve ID' })).not.toBeInTheDocument();
    expect(api.post).not.toHaveBeenCalled();

    // Backing out again collapses it back to "Reconsider" with no request sent.
    await testUser.click(screen.getByRole('button', { name: 'Cancel' }));
    expect(screen.getByRole('button', { name: 'Reconsider' })).toBeInTheDocument();
    expect(api.post).not.toHaveBeenCalled();
  });

  it('shows both actions unprompted while an ID check is still pending', async () => {
    renderUsersPage([user({ kyc_status: 'pending' })]);

    expect(await screen.findByRole('button', { name: 'Approve ID' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Reject ID' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Reconsider' })).not.toBeInTheDocument();
  });

  it('filters the table by name, email, or member ID', async () => {
    const testUser = userEvent.setup();
    renderUsersPage([
      user({ id: 'a', full_name: 'Alice Traveler', email: 'alice@example.com', membership_id: 'H00000001' }),
      user({ id: 'b', full_name: 'Bob Shopper', email: 'bob@example.com', membership_id: 'H00000002' }),
    ]);

    expect(await screen.findByText('Alice Traveler')).toBeInTheDocument();
    expect(screen.getByText('Bob Shopper')).toBeInTheDocument();

    await testUser.type(screen.getByPlaceholderText('Search by name, email, or member ID…'), 'alice');
    expect(screen.getByText('Alice Traveler')).toBeInTheDocument();
    expect(screen.queryByText('Bob Shopper')).not.toBeInTheDocument();
  });

  it('finds a user by their membership ID alone', async () => {
    const testUser = userEvent.setup();
    renderUsersPage([
      user({ id: 'a', full_name: 'Alice Traveler', email: 'alice@example.com', membership_id: 'H00000001' }),
      user({ id: 'b', full_name: 'Bob Shopper', email: 'bob@example.com', membership_id: 'H00000002' }),
    ]);

    await screen.findByText('Alice Traveler');
    await testUser.type(screen.getByPlaceholderText('Search by name, email, or member ID…'), 'H00000002');
    expect(screen.getByText('Bob Shopper')).toBeInTheDocument();
    expect(screen.queryByText('Alice Traveler')).not.toBeInTheDocument();
  });
});
