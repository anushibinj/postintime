import { apiFetch } from './client';
import type { PostTarget, PublishResponse } from '../types';

export async function fetchTargets(channelId: string, postId: string): Promise<PostTarget[]> {
  return apiFetch<PostTarget[]>(`/api/v1/channels/${channelId}/posts/${postId}/targets`);
}

export async function createTargets(channelId: string, postId: string, socialAccountIds: string[]): Promise<PostTarget[]> {
  return apiFetch<PostTarget[]>(`/api/v1/channels/${channelId}/posts/${postId}/targets`, {
    method: 'POST',
    body: JSON.stringify({ socialAccountIds }),
  });
}

export async function publishTarget(channelId: string, postId: string, targetId: string): Promise<PublishResponse> {
  return apiFetch<PublishResponse>(`/api/v1/channels/${channelId}/posts/${postId}/targets/${targetId}/publish`, {
    method: 'POST',
  });
}

export async function markPublished(channelId: string, postId: string, targetId: string, externalUrl?: string): Promise<PostTarget> {
  return apiFetch<PostTarget>(`/api/v1/channels/${channelId}/posts/${postId}/targets/${targetId}/mark-published`, {
    method: 'POST',
    body: JSON.stringify({ externalUrl, notes: 'Published manually' }),
  });
}

export async function resetTarget(channelId: string, postId: string, targetId: string): Promise<PostTarget> {
  return apiFetch<PostTarget>(`/api/v1/channels/${channelId}/posts/${postId}/targets/${targetId}/reset`, {
    method: 'POST',
  });
}
