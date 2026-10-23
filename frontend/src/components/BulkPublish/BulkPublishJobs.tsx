import { Button, Card, Collapse, Popconfirm, Progress, Space, Tag, Typography, message } from 'antd';
import { format } from 'date-fns';
import type { BulkPublishItemStatus, BulkPublishJob, BulkPublishJobStatus } from '../../types';
import { useBulkPublishJobs, useBulkPublishMutations } from '../../hooks/useBulkPublish';

const JOB_STATUS: Record<BulkPublishJobStatus, { color: string; label: string }> = {
  running: { color: 'processing', label: 'Running' },
  completed: { color: 'success', label: 'Completed' },
  cancelled: { color: 'default', label: 'Cancelled' },
};

const ITEM_STATUS: Record<BulkPublishItemStatus, { color: string; label: string }> = {
  pending: { color: 'default', label: 'Pending' },
  published: { color: 'success', label: 'Published' },
  partial: { color: 'warning', label: 'Partly failed' },
  failed: { color: 'error', label: 'Failed' },
  skipped: { color: 'default', label: 'Skipped' },
  cancelled: { color: 'default', label: 'Cancelled' },
};

export function BulkPublishJobs({ channelId }: { channelId: string }) {
  const { data: jobs = [] } = useBulkPublishJobs(channelId);
  const { cancel } = useBulkPublishMutations(channelId);

  if (jobs.length === 0) {
    return null;
  }

  const running = jobs.filter((job) => job.status === 'running');
  const finished = jobs.filter((job) => job.status !== 'running');

  const handleCancel = async (jobId: string) => {
    try {
      await cancel.mutateAsync(jobId);
      message.success('Bulk posting cancelled');
    } catch (error) {
      message.error(error instanceof Error ? error.message : 'Could not cancel bulk posting');
    }
  };

  return (
    <div style={{ marginBottom: 16 }}>
      {running.map((job) => (
        <Card
          key={job.id}
          size="small"
          style={{ marginBottom: 8 }}
          title={<JobTitle job={job} />}
          extra={
            <Popconfirm
              title="Cancel bulk posting?"
              description="Posts that have not gone live yet will not be posted."
              okText="Cancel posting"
              cancelText="Keep going"
              onConfirm={() => handleCancel(job.id)}
            >
              <Button size="small" danger loading={cancel.isPending && cancel.variables === job.id}>
                Cancel
              </Button>
            </Popconfirm>
          }
        >
          <JobBody job={job} />
        </Card>
      ))}
      {finished.length > 0 && (
        <Collapse
          size="small"
          items={[
            {
              key: 'recent',
              label: `Recent bulk posts (${finished.length})`,
              children: finished.map((job) => (
                <div key={job.id} style={{ marginBottom: 12 }}>
                  <JobTitle job={job} />
                  <JobBody job={job} />
                </div>
              )),
            },
          ]}
        />
      )}
    </div>
  );
}

function JobTitle({ job }: { job: BulkPublishJob }) {
  const status = JOB_STATUS[job.status];
  return (
    <Space size={8} wrap>
      <Typography.Text strong>
        Bulk post · {job.totalItems} {job.totalItems === 1 ? 'post' : 'posts'} · every {job.intervalMinutes} min
      </Typography.Text>
      <Tag color={status.color}>{status.label}</Tag>
      <Typography.Text type="secondary" style={{ fontSize: 12 }}>
        Started {format(new Date(job.createdAt), 'MMM d, h:mm a')}
      </Typography.Text>
    </Space>
  );
}

function JobBody({ job }: { job: BulkPublishJob }) {
  const percent = job.totalItems === 0 ? 0 : Math.round((job.processedItems / job.totalItems) * 100);
  return (
    <div>
      <Progress
        percent={percent}
        size="small"
        status={job.status === 'running' ? 'active' : job.failedItems > 0 ? 'exception' : 'normal'}
        format={() => `${job.processedItems}/${job.totalItems}`}
      />
      <Typography.Text type="secondary" style={{ fontSize: 12, display: 'block', marginBottom: 4 }}>
        {job.status === 'running' && job.nextRunAt
          ? `Next post at ${format(new Date(job.nextRunAt), 'h:mm a')}`
          : null}
        {job.failedItems > 0 ? `${job.status === 'running' ? ' · ' : ''}${job.failedItems} failed` : null}
      </Typography.Text>
      <ol style={{ margin: 0, paddingLeft: 20 }}>
        {job.items.map((item) => {
          const status = ITEM_STATUS[item.status];
          return (
            <li key={item.id} style={{ marginBottom: 2 }}>
              <Space size={6} align="start" wrap>
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
      </ol>
    </div>
  );
}

export default BulkPublishJobs;
