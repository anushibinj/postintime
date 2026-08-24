import { apiFetch } from './client';
import type { Platform, PostingMode, SocialAccount, WebhookAuthType } from '../types';

export async function fetchSocialAccounts(channelId: string): Promise<SocialAccount[]> {
  return apiFetch<SocialAccount[]>(`/api/v1/channels/${channelId}/social-accounts`);
}

export async function createSocialAccount(channelId: string, data: {
  platform: Platform;
  name: string;
  profileUrl?: string;
  postingMode?: PostingMode;
  webhookUrl?: string;
  webhookAuthType?: WebhookAuthType;
  webhookUsername?: string;
  webhookPassword?: string;
}): Promise<SocialAccount> {
  return apiFetch<SocialAccount>(`/api/v1/channels/${channelId}/social-accounts`, {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updateSocialAccount(channelId: string, accountId: string, data: Partial<{
  platform: Platform;
  name: string;
  profileUrl: string;
  postingMode: PostingMode;
  enabled: boolean;
  webhookUrl: string;
  webhookAuthType: WebhookAuthType;
  webhookUsername: string;
  webhookPassword: string;
}>): Promise<SocialAccount> {
  return apiFetch<SocialAccount>(`/api/v1/channels/${channelId}/social-accounts/${accountId}`, {
    method: 'PATCH',
    body: JSON.stringify(data),
  });
}

export async function deleteSocialAccount(channelId: string, accountId: string): Promise<void> {
  return apiFetch<void>(`/api/v1/channels/${channelId}/social-accounts/${accountId}`, { method: 'DELETE' });
}

export async function enableSocialAccount(channelId: string, accountId: string): Promise<SocialAccount> {
  return apiFetch<SocialAccount>(`/api/v1/channels/${channelId}/social-accounts/${accountId}/enable`, { method: 'POST' });
}

export async function disableSocialAccount(channelId: string, accountId: string): Promise<SocialAccount> {
  return apiFetch<SocialAccount>(`/api/v1/channels/${channelId}/social-accounts/${accountId}/disable`, { method: 'POST' });
}
