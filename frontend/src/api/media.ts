import { apiFetch } from './client';
import type { MediaInfo } from '../types';

export async function uploadMedia(file: File): Promise<MediaInfo> {
  const formData = new FormData();
  formData.append('file', file);
  return apiFetch<MediaInfo>('/api/v1/media', {
    method: 'POST',
    body: formData,
  });
}

export async function deleteMedia(mediaId: string): Promise<void> {
  return apiFetch<void>(`/api/v1/media/${mediaId}`, { method: 'DELETE' });
}
