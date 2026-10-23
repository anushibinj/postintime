import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BulkPublishJobs } from './BulkPublishJobs';
import type { BulkPublishJob } from '../../types';

const job: BulkPublishJob = {
  id: 'job',
  channelId: 'channel',
  intervalMinutes: 5,
  status: 'running',
  totalItems: 2,
  processedItems: 0,
  failedItems: 0,
  socialAccountIds: ['account'],
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
  items: ['First queued', 'Second queued'].map((title, position) => ({
    id: `item-${position}`,
    postId: `post-${position}`,
    postTitle: title,
    position,
    status: 'pending',
    scheduledAt: new Date(Date.now() + (position + 1) * 5 * 60_000).toISOString(),
  })),
};

vi.mock('../../hooks/useBulkPublish', () => ({
  useBulkPublishJobs: () => ({ data: [job] }),
  useBulkPublishMutations: () => ({
    cancel: { isPending: false, mutateAsync: vi.fn() },
    cancelItem: { isPending: false, mutateAsync: vi.fn() },
  }),
}));

describe('BulkPublishJobs', () => {
  it('keeps the queue collapsed until it is opened', () => {
    render(
      <QueryClientProvider client={new QueryClient()}>
        <BulkPublishJobs channelId="channel" />
      </QueryClientProvider>,
    );

    expect(screen.getByText('Bulk posting queue')).toBeInTheDocument();
    expect(screen.getByText('2 posts')).toBeInTheDocument();
    expect(screen.queryByText('First queued')).not.toBeInTheDocument();

    fireEvent.click(screen.getByText('Bulk posting queue'));
    expect(screen.getByText('First queued')).toBeInTheDocument();
    expect(screen.getByText('Second queued')).toBeInTheDocument();
  });
});
