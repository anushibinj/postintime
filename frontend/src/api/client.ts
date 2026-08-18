export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

const TOKEN_KEY = 'postintime_token';
const sessionExpiredListeners = new Set<() => void>();

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

export function getTokenExpiryMs(token: string): number | null {
  try {
    const payload = JSON.parse(atob(token.split('.')[1])) as { exp?: number };
    return typeof payload.exp === 'number' ? payload.exp * 1000 : null;
  } catch {
    return null;
  }
}

export function isTokenExpired(token: string | null = getToken()): boolean {
  if (!token) {
    return true;
  }
  const expiryMs = getTokenExpiryMs(token);
  if (expiryMs == null) {
    return false;
  }
  return Date.now() >= expiryMs;
}

export function onSessionExpired(listener: () => void): () => void {
  sessionExpiredListeners.add(listener);
  return () => sessionExpiredListeners.delete(listener);
}

export function expireSession(): void {
  if (!getToken()) {
    return;
  }
  clearToken();
  sessionExpiredListeners.forEach((listener) => listener());
}

function isAuthRequest(path: string): boolean {
  return path.startsWith('/api/v1/auth/');
}

export async function apiFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
  if (!isAuthRequest(path) && isTokenExpired()) {
    expireSession();
    throw new Error('Session expired');
  }

  const headers = new Headers(options.headers);
  if (!headers.has('Content-Type') && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }
  const token = getToken();
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  const response = await fetch(`${API_BASE_URL}${path}`, { ...options, headers });
  if (!response.ok) {
    if (response.status === 401 && !isAuthRequest(path)) {
      expireSession();
    }
    const error = await response.json().catch(() => ({ message: response.statusText }));
    throw new Error(error.message || 'Request failed');
  }
  if (response.status === 204) {
    return undefined as T;
  }
  return response.json();
}
