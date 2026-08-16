import { apiFetch, setToken } from './client';

export interface AuthResponse {
  token: string;
  userId: string;
  email: string;
  displayName: string;
}

export async function register(email: string, password: string, displayName?: string): Promise<AuthResponse> {
  const response = await apiFetch<AuthResponse>('/api/v1/auth/register', {
    method: 'POST',
    body: JSON.stringify({ email, password, displayName }),
  });
  setToken(response.token);
  return response;
}

export async function login(email: string, password: string): Promise<AuthResponse> {
  const response = await apiFetch<AuthResponse>('/api/v1/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  setToken(response.token);
  return response;
}
