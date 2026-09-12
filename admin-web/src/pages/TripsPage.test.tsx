import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { TripsPage } from './TripsPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { AdminUser, Trip } from '../api/types';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<typeof import('../api/client')>('../api/client');
  return { ...actual, api: { get: vi.fn(), post: vi.fn() } };
});

function trip(overrides: Partial<Trip> = {}): Trip {
  return {
    id: 'trip-1',
    traveler_id: 'traveler-1',
    departure_country: 'JP',
    arrival_country: 'TH',
    status: 'published',
    departure_date: new Date().toISOString(),
    return_date: new Date().toISOString(),
    created_at: new Date().toISOString(),
    traveler_email: 'traveler@example.com',
    traveler_name: 'Test Traveler',
    ...overrides,
  };
}

function adminUser(overrides: Partial<AdminUser> = {}): AdminUser {
  return {
    id: 'traveler-1',
    membership_id: 'H00000001',
    email: 'traveler@example.com',
    full_name: 'Test Traveler',
    user_type: 'traveler',
    role: 'user',
    kyc_status: 'approved',
    risk_status: 'clear',
    violation_count: 0,
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function renderTripsPage(trips: Trip[], users: AdminUser[] = [adminUser()]) {
  vi.mocked(api.get).mockImplementation((url: string) =>
    Promise.resolve(url.startsWith('/admin/users') ? { users } : { trips })
  );
  vi.mocked(api.post).mockResolvedValue({ removed: trips.length });
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <TripsPage />
      </ToastProvider>
    </QueryClientProvider>
  );
}

describe('TripsPage filters', () => {
  it('filters by status', async () => {
    const testUser = userEvent.setup();
    renderTripsPage([
      trip({ id: 'a', status: 'published' }),
      trip({ id: 'b', status: 'cancelled', traveler_name: 'Cancelled Traveler' }),
    ]);

    expect(await screen.findByText('Test Traveler')).toBeInTheDocument();
    expect(screen.getByText('Cancelled Traveler')).toBeInTheDocument();

    await testUser.selectOptions(screen.getByDisplayValue('All statuses'), 'cancelled');
    expect(screen.getByText('Cancelled Traveler')).toBeInTheDocument();
    expect(screen.queryByText('Test Traveler')).not.toBeInTheDocument();
  });

  it('finds a trip by its traveler\'s membership ID', async () => {
    const testUser = userEvent.setup();
    renderTripsPage(
      [
        trip({ id: 'a', traveler_id: 'traveler-1', traveler_name: 'Alice' }),
        trip({ id: 'b', traveler_id: 'traveler-2', traveler_name: 'Bob', traveler_email: 'bob@example.com' }),
      ],
      [adminUser({ id: 'traveler-1', membership_id: 'H00000001' }), adminUser({ id: 'traveler-2', membership_id: 'H00000002' })]
    );

    await screen.findByText('Alice');
    await testUser.type(screen.getByPlaceholderText('Search by route, title, traveler, or member ID…'), 'H00000002');
    expect(screen.getByText('Bob')).toBeInTheDocument();
    expect(screen.queryByText('Alice')).not.toBeInTheDocument();
  });
});

describe('TripsPage bulk cancel', () => {
  it('requires a reason and states the live count before cancelling every trip', async () => {
    const user = userEvent.setup();
    renderTripsPage([trip({ id: 'a' }), trip({ id: 'b' }), trip({ id: 'c', status: 'cancelled' })]);

    await user.click(await screen.findByRole('button', { name: 'Cancel ALL trips' }));

    // Only the 2 live (published/in_progress) trips are counted, not the already-cancelled one.
    const dialog = await screen.findByRole('dialog', { name: 'Cancel every live trip' });
    expect(within(dialog).getByText(/cancels all 2 published or in-progress trips/i)).toBeInTheDocument();

    const confirmButton = within(dialog).getByRole('button', { name: 'Cancel all' });
    expect(confirmButton).toBeDisabled();
    expect(api.post).not.toHaveBeenCalledWith('/admin/trips/remove-all', expect.anything());

    await user.type(within(dialog).getByRole('textbox'), 'Platform-wide spam sweep');
    await user.click(confirmButton);

    expect(api.post).toHaveBeenCalledWith('/admin/trips/remove-all', { reason: 'Platform-wide spam sweep' });
  });
});
