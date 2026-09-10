import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { TripsPage } from './TripsPage';
import { api } from '../api/client';
import { ToastProvider } from '../components/Toast';
import type { Trip } from '../api/types';

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

function renderTripsPage(trips: Trip[]) {
  vi.mocked(api.get).mockResolvedValue({ trips });
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
