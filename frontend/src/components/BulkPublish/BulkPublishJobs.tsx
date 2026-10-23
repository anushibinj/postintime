import { Button, Card, Collapse, Popconfirm, Space, Tag, Tooltip, Typography, message } from 'antd';
import { X } from 'lucide-react';
import { format } from 'date-fns';
import { useEffect, useRef } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import type { BulkPublishItem, BulkPublishItemStatus, BulkPublishJob } from '../../types';
import { useBulkPublishJobs, useBulkPublishMutations } from '../../hooks/useBulkPublish';
import { useNow } from '../../hooks/useNow';
import { formatQueuedAt } from '../../hooks/bulkPublishTime';

const RECENT_LIMIT = 20;

const ITEM_STATUS: Record<BulkPublishItemStatus, { color: string; label: string }> = {
  pending: { color: 'default', label: 'Queued' },
  publishing: { color: 'processing', label: 'Posting now' },
  published: { color: 'success', label: 'Published' },
  partial: { color: 'warning', label: 'Partly failed' },
  failed: { color: 'error', label: 'Failed' },
  skipped: { color: 'default', label: 'Skipped' },
  cancelled: { color: 'default', label: 'Cancelled' },
};

type QueueEntry = { job: BulkPublishJob; item: BulkPublishItem };

/** The channel's bulk posting queue plus the most recent bulk posts that already went out. */
export function BulkPublishJobs({ channelId }: { channelId: string }) {
  const { data } = useBulkPublishJobs(channelId);
  const { cancel, cancelItem } = useBulkPublishMutations(channelId);
  const queryClient = useQueryClient();
  const now = useNow();
  const jobs = data ?? [];

  // Refresh the post list (published badges, queued labels) whenever the queue publishes a post.
  const progressKey = data?.map((job) => `${job.id}:${job.processedItems}`).join(',');
  const lastProgressKey = useRef<string | undefined>(undefined);
  useEffect(() => {
    if (progressKey === undefined) {
      return;
    }
    if (lastProgressKey.current !== undefined && lastProgressKey.current !== progressKey) {
      queryClient.invalidateQueries({ queryKey: ['posts', channelId] });
    }
    lastProgressKey.current = progressKey;
  }, [progressKey, channelId, queryClient]);

  const entries = jobs.flatMap((job) => job.items.map((item) => ({ job, item })));
  // Waiting posts plus the one being posted right now (its webhooks can take minutes).
  const queue = entries
    .filter(({ item }) => item.status === 'pending' || item.status === 'publishing')
    .sort((a, b) => Date.parse(a.item.scheduledAt) - Date.parse(b.item.scheduledAt));
  const recent = entries
    .filter(({ item }) => item.processedAt && item.status !== 'publishing')
    .sort((a, b) => Date.parse(b.item.processedAt!) - Date.parse(a.item.processedAt!))
    .slice(0, RECENT_LIMIT);

  if (queue.length === 0 && recent.length === 0) {
    return null;
  }

  const handleRemove = async ({ job, item }: QueueEntry) => {
    try {
      await cancelItem.mutateAsync({ jobId: job.id, itemId: item.id });
      message.success(`Removed "${item.postTitle}" from the queue`);
    } catch (error) {
      message.error(error instanceof Error ? error.message : 'Could not remove the post from the queue');
    }
  };

  const handleCancelAll = async () => {
    const running = jobs.filter((job) => job.status === 'running');
    try {
      for (const job of running) {
        await cancel.mutateAsync(job.id);
      }
      message.success('Bulk posting queue cleared');
    } catch (error) {
      message.error(error instanceof Error ? error.message : 'Could not clear the queue');
    }
  };

  return (
    <div style={{ marginBottom: 16 }}>
      {queue.length > 0 && (
        <Card
          size="small"
          style={{ marginBottom: 8 }}
          title={
            <Space size={8}>
              <Typography.Text strong>Bulk posting queue</Typography.Text>
              <Tag color="processing">{queue.length} {queue.length === 1 ? 'post' : 'posts'}</Tag>
            </Space>
          }
          extra={
            <Popconfirm
              title="Cancel all queued posts?"
              description="Posts that have not gone live yet will not be posted."
              okText="Cancel all"
              cancelText="Keep them"
              onConfirm={handleCancelAll}
            >
              <Button size="small" danger loading={cancel.isPending}>
                Cancel all
              </Button>
            </Popconfirm>
          }
        >
          <ol style={{ margin: 0, paddingLeft: 20 }}>
            {queue.map((entry) => (
              <li key={entry.item.id} style={{ marginBottom: 4 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  {entry.item.status === 'publishing' ? (
                    <Tag color="processing" style={{ marginInlineEnd: 0 }}>Posting now</Tag>
                  ) : (
                    <Typography.Text strong style={{ flexShrink: 0 }}>
                      {formatQueuedAt(Date.parse(entry.item.scheduledAt), now)}
                    </Typography.Text>
                  )}
                  <Typography.Text ellipsis style={{ flex: 1, minWidth: 0 }}>
                    {entry.item.postTitle}
                  </Typography.Text>
                  <Typography.Text type="secondary" style={{ fontSize: 12, flexShrink: 0 }}>
                    {entry.job.intervalMinutes} min gap
                  </Typography.Text>
                  <Tooltip title={entry.item.status === 'publishing' ? 'Being posted right now' : 'Remove from queue'}>
                    <Button
                      size="small"
                      type="text"
                      aria-label={`Remove ${entry.item.postTitle} from the queue`}
                      icon={<X size={14} />}
                      disabled={entry.item.status === 'publishing'}
                      loading={cancelItem.isPending && cancelItem.variables?.itemId === entry.item.id}
                      onClick={() => handleRemove(entry)}
                    />
                  </Tooltip>
                </div>
              </li>
            ))}
          </ol>
        </Card>
      )}
      {recent.length > 0 && (
        <Collapse
          size="small"
          items={[
            {
              key: 'recent',
              label: `Recent bulk posts (${recent.length})`,
              children: (
                <ul style={{ margin: 0, paddingLeft: 0, listStyle: 'none' }}>
                  {recent.map(({ item }) => {
                    const status = ITEM_STATUS[item.status];
                    return (
                      <li key={item.id} style={{ marginBottom: 6 }}>
                        <Space size={8} wrap>
                          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
                            {format(Date.parse(item.processedAt!), 'MMM d, h:mm a')}
                          </Typography.Text>
                          <Typography.Text ellipsis style={{ maxWidth: 360 }}>{item.postTitle}</Typography.Text>
                          <Tag color={status.color} style={{ marginInlineEnd: 0 }}>{status.label}</Tag>
                        </Space>
                        {item.errorMessage && (
                          <Typography.Paragraph
                            type={item.status === 'skipped' ? 'secondary' : 'danger'}
                            style={{ margin: 0, fontSize: 12, whiteSpace: 'pre-wrap' }}
                          >
                            {item.errorMessage}
                          </Typography.Paragraph>
                        )}
                      </li>
                    );
                  })}
                </ul>
              ),
            },
          ]}
        />
      )}
    </div>
  );
}

export default BulkPublishJobs;
