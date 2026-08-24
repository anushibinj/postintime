export type PostStatus = 'draft' | 'ready';
export type TargetStatus = 'pending' | 'publishing' | 'published' | 'failed' | 'skipped';
export type Platform = 'linkedin' | 'instagram' | 'whatsapp' | 'youtube' | 'x' | 'facebook' | 'threads';
export type PostingMode = 'manual' | 'webhook';
export type WebhookAuthType = 'none' | 'basic';

export interface ApiToken {
  id: string;
  name: string;
  tokenPrefix: string;
  token?: string | null;
  expiresAt?: string | null;
  lastUsedAt?: string | null;
  createdAt: string;
}

export interface Channel {
  id: string;
  name: string;
  slug: string;
  description?: string;
  enabled: boolean;
  postCount: number;
  socialAccountCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface MediaInfo {
  id: string;
  url: string;
  contentType: string;
  originalFilename?: string;
  sizeBytes?: number;
  width?: number;
  height?: number;
}

export interface PublicationSummary {
  total: number;
  published: number;
  pending: number;
  failed: number;
}

export interface PostTargetSummary {
  id: string;
  socialAccountId: string;
  platform: Platform;
  name: string;
  status: TargetStatus;
}

export interface Post {
  id: string;
  channelId?: string;
  title: string;
  caption?: string;
  media?: MediaInfo;
  status: PostStatus;
  publicationSummary?: PublicationSummary;
  targets?: PostTargetSummary[];
  createdAt: string;
  updatedAt: string;
}

export interface PageResponse<T> {
  items: T[];
  page: number;
  size: number;
  totalItems: number;
  totalPages: number;
  hasNext: boolean;
  hasPrevious: boolean;
}

export interface SocialAccount {
  id: string;
  platform: Platform;
  name: string;
  profileUrl?: string;
  postingMode: PostingMode;
  enabled: boolean;
  webhookUrl?: string | null;
  webhookAuthType?: WebhookAuthType;
  webhookUsername?: string | null;
  webhookHasPassword?: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface PostTarget {
  id: string;
  socialAccount: {
    id: string;
    platform: Platform;
    name: string;
    profileUrl?: string;
  };
  status: TargetStatus;
  publishingMode: PostingMode;
  publishedAt?: string;
  externalPostId?: string;
  externalUrl?: string;
}

export interface PublishInstructions {
  copyCaption: boolean;
  downloadMedia: boolean;
  destinationUrl?: string;
}

export interface PublishResponse {
  targetId: string;
  status: TargetStatus;
  publishingMode: PostingMode;
  instructions: PublishInstructions;
}
