const TOKEN_KEY = 'hiww_admin_token';

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null): void {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

export class ApiError extends Error {
  status: number;
  code?: string;

  constructor(message: string, status: number, code?: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

interface Envelope<T> {
  success: boolean;
  data: T;
  code: string;
  error?: string;
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const token = getToken();
  const res = await fetch(`/api${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  let json: Envelope<T> | undefined;
  try {
    json = (await res.json()) as Envelope<T>;
  } catch {
    // no body (e.g. a raw 5xx) — fall through to the status-based error below
  }

  if (!res.ok) {
    if (res.status === 401) setToken(null);
    throw new ApiError(json?.error ?? `Request failed (${res.status})`, res.status, json?.code);
  }

  return (json as Envelope<T>).data;
}

export const api = {
  get: <T>(path: string): Promise<T> => request<T>('GET', path),
  post: <T>(path: string, body?: unknown): Promise<T> => request<T>('POST', path, body ?? {}),
};
