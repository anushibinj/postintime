import { apiFetch } from './client';
import type { PageResponse, Post, PostStatus } from '../types';

export interface PostFilters {
  page?: number;
  size?: number;
  search?: string;
  status?: PostStatus;
  sort?: string;
}

export async function fetchPosts(channelId: string, filters: PostFilters = {}): Promise<PageResponse<Post>> {
  const params = new URLSearchParams();
  if (filters.page !== undefined) params.set('page', String(filters.page));
  if (filters.size !== undefined) params.set('size', String(filters.size));
  if (filters.search) params.set('search', filters.search);
  if (filters.status) params.set('status', filters.status);
  if (filters.sort) params.set('sort', filters.sort);
  const query = params.toString();
  return apiFetch<PageResponse<Post>>(`/api/v1/channels/${channelId}/posts${query ? `?${query}` : ''}`);
}

export async function fetchPost(channelId: string, postId: string): Promise<Post> {
  return apiFetch<Post>(`/api/v1/channels/${channelId}/posts/${postId}`);
}

export async function createPost(channelId: string, data: {
  title: string;
  caption?: string;
  mediaId?: string;
  status: PostStatus;
}): Promise<Post> {
  return apiFetch<Post>(`/api/v1/channels/${channelId}/posts`, {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updatePost(channelId: string, postId: string, data: Partial<{
  title: string;
  caption: string;
  mediaId: string | null;
  status: PostStatus;
}>): Promise<Post> {
  return apiFetch<Post>(`/api/v1/channels/${channelId}/posts/${postId}`, {
    method: 'PATCH',
    body: JSON.stringify(data),
  });
}

export async function deletePost(channelId: string, postId: string): Promise<void> {
  return apiFetch<void>(`/api/v1/channels/${channelId}/posts/${postId}`, { method: 'DELETE' });
}
