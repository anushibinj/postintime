import { Alert, Modal, Slider, Space, Tag, Typography } from 'antd';
import { useState } from 'react';
import type { SocialAccount } from '../../types';
import {
  BULK_INTERVAL_DEFAULT,
  BULK_INTERVAL_MAX,
  BULK_INTERVAL_MIN,
  BULK_INTERVAL_STEP,
  intervalMarks,
  normalizeInterval,
} from '../../hooks/bulkPublishInterval';
import { firstSlot, formatQueuedAt } from '../../hooks/bulkPublishTime';
import { useNow } from '../../hooks/useNow';

export interface BulkPublishSelection {
  id: string;
  title: string;
}

interface BulkPublishModalProps {
  open: boolean;
  posts: BulkPublishSelection[];
  accounts: SocialAccount[];
  /** Latest queued slot (or latest bulk post) in this channel; new posts are queued after it. */
  queueTail: number | null;
  /** Posts already waiting in the channel's queue. */
  queuedCount: number;
  submitting: boolean;
  onCancel: () => void;
  onSubmit: (intervalMinutes: number) => void;
}

export function BulkPublishModal({
  open,
  posts,
  accounts,
  queueTail,
  queuedCount,
  submitting,
  onCancel,
  onSubmit,
}: BulkPublishModalProps) {
  const [interval, setIntervalMinutes] = useState(BULK_INTERVAL_DEFAULT);
  const now = useNow();
  const enabled = accounts.filter((account) => account.enabled);
  const webhookAccounts = enabled.filter((account) => account.postingMode === 'webhook');
  const manualAccounts = enabled.filter((account) => account.postingMode === 'manual');
  const first = firstSlot(queueTail, interval, now);
  const last = first + Math.max(0, posts.length - 1) * interval * 60_000;
  const startsNow = first <= now;
  const plural = posts.length === 1 ? 'post' : 'posts';

  return (
    <Modal
      title={`Bulk post ${posts.length} ${plural}`}
      open={open}
      onCancel={onCancel}
      onOk={() => onSubmit(interval)}
      okText="Start bulk posting"
      okButtonProps={{ disabled: webhookAccounts.length === 0 || posts.length === 0 }}
      confirmLoading={submitting}
      afterOpenChange={(visible) => {
        if (!visible) {
          setIntervalMinutes(BULK_INTERVAL_DEFAULT);
        }
      }}
    >
      <Typography.Text strong>Interval between posts</Typography.Text>
      <Slider
        aria-label="Interval between posts in minutes"
        min={BULK_INTERVAL_MIN}
        max={BULK_INTERVAL_MAX}
        step={BULK_INTERVAL_STEP}
        marks={intervalMarks()}
        value={interval}
        onChange={(value) => setIntervalMinutes(normalizeInterval(value))}
        tooltip={{ formatter: (value) => `${value} min` }}
        style={{ margin: '12px 8px 32px' }}
      />
      <Typography.Paragraph type="secondary">
        {queuedCount > 0 &&
          `${queuedCount} ${queuedCount === 1 ? 'post is' : 'posts are'} already queued; these join the end of the queue. `}
        {startsNow
          ? `The ${posts.length > 1 ? 'first post' : 'post'} goes live right away`
          : `The ${posts.length > 1 ? 'first post' : 'post'} goes live at ${formatQueuedAt(first, now)}`}
        {posts.length > 1
          ? `, then one every ${interval} minutes. The last post goes live at ${formatQueuedAt(last, now)}.`
          : '.'}
      </Typography.Paragraph>

      {webhookAccounts.length === 0 ? (
        <Alert
          type="error"
          showIcon
          style={{ marginBottom: 16 }}
          title="No webhook social accounts"
          description="Bulk posting calls each account's webhook. Enable or add a webhook social account for this channel first."
        />
      ) : (
        <div style={{ marginBottom: 16 }}>
          <Typography.Text strong>Posting to</Typography.Text>
          <Space size={[4, 4]} wrap style={{ display: 'flex', marginTop: 8 }}>
            {webhookAccounts.map((account) => (
              <Tag key={account.id}>{account.name}</Tag>
            ))}
          </Space>
          {manualAccounts.length > 0 && (
            <Typography.Paragraph type="secondary" style={{ margin: '8px 0 0', fontSize: 12 }}>
              Manual accounts ({manualAccounts.map((account) => account.name).join(', ')}) are skipped.
            </Typography.Paragraph>
          )}
        </div>
      )}

      <Typography.Text strong>Order</Typography.Text>
      <ol style={{ maxHeight: 200, overflowY: 'auto', margin: '8px 0 16px', paddingLeft: 24 }}>
        {posts.map((post) => (
          <li key={post.id}>
            <Typography.Text ellipsis style={{ maxWidth: '100%' }}>{post.title}</Typography.Text>
          </li>
        ))}
      </ol>

      <Typography.Paragraph type="secondary" style={{ marginBottom: 0, fontSize: 12 }}>
        Accounts are called one after another. If a post fails, the failure is logged and the batch moves on to
        the next post. Posting runs on the server, so you can leave this page.
      </Typography.Paragraph>
    </Modal>
  );
}

export default BulkPublishModal;
