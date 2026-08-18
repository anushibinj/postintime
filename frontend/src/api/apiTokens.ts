import { apiFetch } from './client';
import type { ApiToken } from '../types';

export async function fetchApiTokens(): Promise<ApiToken[]> {
  return apiFetch<ApiToken[]>('/api/v1/api-tokens');
}

export async function createApiToken(data: { name: string; expiresAt?: string | null }): Promise<ApiToken> {
  return apiFetch<ApiToken>('/api/v1/api-tokens', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updateApiToken(tokenId: string, data: {
  name?: string;
  expiresAt?: string | null;
  neverExpires?: boolean;
}): Promise<ApiToken> {
  return apiFetch<ApiToken>(`/api/v1/api-tokens/${tokenId}`, {
    method: 'PATCH',
    body: JSON.stringify(data),
  });
}

export async function refreshApiToken(tokenId: string, data?: {
  expiresAt?: string | null;
  neverExpires?: boolean;
}): Promise<ApiToken> {
  return apiFetch<ApiToken>(`/api/v1/api-tokens/${tokenId}/refresh`, {
    method: 'POST',
    body: JSON.stringify(data || {}),
  });
}

export async function deleteApiToken(tokenId: string): Promise<void> {
  return apiFetch<void>(`/api/v1/api-tokens/${tokenId}`, { method: 'DELETE' });
}
