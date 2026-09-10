import { createContext, use, useCallback, useEffect, useState, type ReactNode } from 'react';
import { api, ApiError, getToken, setToken, setUnauthorizedHandler } from '../api/client';

interface Me {
  id: string;
  email: string;
  full_name: string;
  role: 'user' | 'admin';
}

interface AuthState {
  me: Me | null;
  status: 'checking' | 'signed-out' | 'signed-in' | 'forbidden';
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  error: string | null;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [me, setMe] = useState<Me | null>(null);
  const [status, setStatus] = useState<AuthState['status']>('checking');
  const [error, setError] = useState<string | null>(null);

  const loadMe = useCallback(async () => {
    if (!getToken()) {
      setStatus('signed-out');
      return;
    }
    try {
      const data = await api.get<Me>('/me');
      if (data.role !== 'admin') {
        setStatus('forbidden');
        setMe(data);
        return;
      }
      setMe(data);
      setStatus('signed-in');
    } catch {
      setToken(null);
      setStatus('signed-out');
    }
  }, []);

  useEffect(() => {
    void loadMe();
  }, [loadMe]);

  // A 401 anywhere in the app means the session died server-side — drop
  // straight back to the login screen instead of leaving the sidebar/shell
  // showing "signed in" while every subsequent action fails confusingly.
  useEffect(() => {
    setUnauthorizedHandler(() => {
      setMe(null);
      setStatus('signed-out');
      setError('Your session expired — sign in again.');
    });
    return () => setUnauthorizedHandler(null);
  }, []);

  const login = useCallback(
    async (email: string, password: string) => {
      setError(null);
      try {
        const data = await api.post<{ token: string }>('/auth/login', { email, password });
        setToken(data.token);
        await loadMe();
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'Sign-in failed');
        throw err;
      }
    },
    [loadMe]
  );

  const logout = useCallback(() => {
    setToken(null);
    setMe(null);
    setStatus('signed-out');
  }, []);

  return (
    <AuthContext value={{ me, status, login, logout, error }}>{children}</AuthContext>
  );
}

export function useAuth(): AuthState {
  const ctx = use(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
