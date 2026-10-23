import { apiFetch } from './client';
import type { BulkPublishJob } from '../types';

function jobsPath(channelId: string) {
  return `/api/v1/channels/${channelId}/bulk-publish-jobs`;
}

export async function fetchBulkPublishJobs(channelId: string): Promise<BulkPublishJob[]> {
  return apiFetch<BulkPublishJob[]>(jobsPath(channelId));
}

export async function createBulkPublishJob(
  channelId: string,
  postIds: string[],
  intervalMinutes: number,
  socialAccountIds: string[],
): Promise<BulkPublishJob> {
  return apiFetch<BulkPublishJob>(jobsPath(channelId), {
    method: 'POST',
    body: JSON.stringify({ postIds, intervalMinutes, socialAccountIds }),
  });
}

export async function cancelBulkPublishItem(channelId: string, jobId: string, itemId: string): Promise<BulkPublishJob> {
  return apiFetch<BulkPublishJob>(`${jobsPath(channelId)}/${jobId}/items/${itemId}/cancel`, { method: 'POST' });
}

export async function cancelBulkPublishJob(channelId: string, jobId: string): Promise<BulkPublishJob> {
  return apiFetch<BulkPublishJob>(`${jobsPath(channelId)}/${jobId}/cancel`, { method: 'POST' });
}
