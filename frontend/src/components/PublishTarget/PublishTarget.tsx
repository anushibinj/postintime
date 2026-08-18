import { Button, Card, Modal, Space, Tooltip, Typography, message } from 'antd';
import { Check, Copy, Download, ExternalLink, Send } from 'lucide-react';
import type { Post, PostTarget } from '../../types';
import { StatusBadge } from '../StatusBadge/StatusBadge';
import { usePublishingMutations } from '../../hooks/usePublishTarget';
import { format } from 'date-fns';
import { useState } from 'react';

interface PublishTargetProps {
  target: PostTarget;
  post: Post;
  channelId: string;
  postId: string;
}

export function PublishTargetPanel({ target, post, channelId, postId }: PublishTargetProps) {
  const [modalOpen, setModalOpen] = useState(false);
  const { publish, markPublished } = usePublishingMutations(channelId, postId);

  const handleCopyCaption = () => {
    navigator.clipboard.writeText(post.caption || '');
    message.success('Caption copied');
  };

  const handleDownload = () => {
    if (post.media?.url) {
      window.open(post.media.url, '_blank');
    }
  };

  const handleOpenDestination = () => {
    if (target.socialAccount.profileUrl) {
      window.open(target.socialAccount.profileUrl, '_blank');
    }
  };

  const handlePublish = async () => {
    await publish.mutateAsync(target.id);
    setModalOpen(true);
  };

  const handleMarkPublished = async () => {
    await markPublished.mutateAsync(target.id);
    setModalOpen(false);
    message.success('Marked as published');
  };

  return (
    <Card
      size="small"
      style={{ marginBottom: 12 }}
      actions={
        target.status === 'pending'
          ? [
              <Tooltip title="Publish" key="publish">
                <span onClick={handlePublish}><Send size={16} /></span>
              </Tooltip>,
            ]
          : undefined
      }
    >
      <Card.Meta
        title={
          <Space>
            <Typography.Text strong>{target.socialAccount.name}</Typography.Text>
            <StatusBadge status={target.status} />
          </Space>
        }
        description={
          target.publishedAt ? (
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              {format(new Date(target.publishedAt), 'MMM d, yyyy h:mm a')}
            </Typography.Text>
          ) : (
            `${target.socialAccount.platform}`
          )
        }
      />

      <Modal
        title={`Publish to ${target.socialAccount.name}`}
        open={modalOpen}
        onCancel={() => setModalOpen(false)}
        footer={[
          <Button key="mark" type="primary" icon={<Check size={14} />} onClick={handleMarkPublished}>
            Mark as Published
          </Button>,
        ]}
      >
        <Typography.Paragraph>
          <Typography.Text strong>Caption</Typography.Text>
          <div style={{ background: '#f5f5f5', padding: 12, borderRadius: 8, marginTop: 8 }}>
            {post.caption}
          </div>
          <Button icon={<Copy size={14} />} onClick={handleCopyCaption} style={{ marginTop: 8 }}>Copy Caption</Button>
        </Typography.Paragraph>

        {post.media?.url && (
          <Typography.Paragraph>
            <Typography.Text strong>Media</Typography.Text>
            <div><img src={post.media.url} alt="" style={{ maxWidth: '100%', marginTop: 8, borderRadius: 8 }} /></div>
            <Button icon={<Download size={14} />} onClick={handleDownload} style={{ marginTop: 8 }}>Download Image</Button>
          </Typography.Paragraph>
        )}

        {target.socialAccount.profileUrl && (
          <Typography.Paragraph>
            <Typography.Text strong>Destination</Typography.Text>
            <div>{target.socialAccount.profileUrl}</div>
            <Button icon={<ExternalLink size={14} />} onClick={handleOpenDestination} style={{ marginTop: 8 }}>Open {target.socialAccount.platform}</Button>
          </Typography.Paragraph>
        )}
      </Modal>
    </Card>
  );
}
