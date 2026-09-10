import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { App } from './App';
import { useAuth } from './auth/AuthContext';

vi.mock('./auth/AuthContext', () => ({
  useAuth: vi.fn(),
}));

function renderApp() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <App />
      </MemoryRouter>
    </QueryClientProvider>
  );
}

describe('App auth gate', () => {
  it('shows the login page for a signed-out visitor', () => {
    vi.mocked(useAuth).mockReturnValue({ me: null, status: 'signed-out', login: vi.fn(), logout: vi.fn(), error: null });
    renderApp();
    expect(screen.getByRole('heading', { name: 'Hiww Admin' })).toBeInTheDocument();
  });

  it('shows a not-an-admin note for a signed-in non-admin', () => {
    vi.mocked(useAuth).mockReturnValue({ me: null, status: 'forbidden', login: vi.fn(), logout: vi.fn(), error: null });
    renderApp();
    expect(screen.getByText(/that account isn't an admin/i)).toBeInTheDocument();
  });

  it('shows the dashboard sidebar for an admin', () => {
    vi.mocked(useAuth).mockReturnValue({
      me: { id: '1', email: 'admin@hiww.app', full_name: 'Admin', role: 'admin' },
      status: 'signed-in',
      login: vi.fn(),
      logout: vi.fn(),
      error: null,
    });
    renderApp();
    expect(screen.getByText('Hiww Admin')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Disputes' })).toBeInTheDocument();
  });
});
