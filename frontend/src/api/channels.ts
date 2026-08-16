import { apiFetch } from './client';
import type { Channel } from '../types';

export async function fetchChannels(): Promise<Channel[]> {
  return apiFetch<Channel[]>('/api/v1/channels');
}

export async function fetchChannel(channelId: string): Promise<Channel> {
  return apiFetch<Channel>(`/api/v1/channels/${channelId}`);
}

export async function createChannel(data: { name: string; slug: string; description?: string }): Promise<Channel> {
  return apiFetch<Channel>('/api/v1/channels', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updateChannel(channelId: string, data: Partial<{ name: string; slug: string; description: string; enabled: boolean }>): Promise<Channel> {
  return apiFetch<Channel>(`/api/v1/channels/${channelId}`, {
    method: 'PATCH',
    body: JSON.stringify(data),
  });
}

export async function deleteChannel(channelId: string): Promise<void> {
  return apiFetch<void>(`/api/v1/channels/${channelId}`, { method: 'DELETE' });
}
