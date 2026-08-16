import { Button, Card, Checkbox, Modal, Space, Typography, message } from 'antd';
import { Edit, Trash2 } from 'lucide-react';
import { useNavigate, useParams } from 'react-router-dom';
import { useState } from 'react';
import { usePost, useDeletePost } from '../../hooks/usePosts';
import { useTargets, usePublishingMutations } from '../../hooks/usePublishTarget';
import { useSocialAccounts } from '../../hooks/useSocialAccounts';
import { PublishTargetPanel } from '../../components/PublishTarget/PublishTarget';

export function PostDetailPage() {
  const { channelId, postId } = useParams();
  const navigate = useNavigate();
  const { data: post } = usePost(channelId, postId);
  const { data: targets = [] } = useTargets(channelId, postId);
  const { data: accounts = [] } = useSocialAccounts(channelId);
  const deletePost = useDeletePost(channelId!);
  const { createTargets } = usePublishingMutations(channelId!, postId!);
  const [targetModalOpen, setTargetModalOpen] = useState(false);
  const [selectedAccounts, setSelectedAccounts] = useState<string[]>([]);

  if (!post) return null;

  const summary = post.publicationSummary;
  const enabledAccounts = accounts.filter((a) => a.enabled);
  const untargetedAccounts = enabledAccounts.filter(
    (a) => !targets.some((t) => t.socialAccount.id === a.id)
  );

  const handleAddTargets = async () => {
    if (selectedAccounts.length === 0) return;
    await createTargets.mutateAsync(selectedAccounts);
    setTargetModalOpen(false);
    setSelectedAccounts([]);
    message.success('Targets added');
  };

  return (
    <div>
      <Space style={{ width: '100%', justifyContent: 'space-between', marginBottom: 16 }}>
        <Typography.Title level={2} style={{ margin: 0 }}>{post.title}</Typography.Title>
        <Space>
          <Button icon={<Edit size={16} />} onClick={() => navigate(`/channels/${channelId}/posts/${postId}/edit`)}>Edit</Button>
          <Button danger icon={<Trash2 size={16} />} onClick={() => {
            Modal.confirm({
              title: 'Delete post?',
              onOk: async () => {
                await deletePost.mutateAsync(postId!);
                navigate(`/channels/${channelId}/posts`);
              },
            });
          }}>Delete</Button>
        </Space>
      </Space>

      {post.media?.url && (
        <img src={post.media.url} alt={post.title} style={{ maxWidth: '100%', maxHeight: 400, borderRadius: 8, marginBottom: 16 }} />
      )}

      <Card title="Caption" style={{ marginBottom: 16 }}>
        <Typography.Paragraph>{post.caption}</Typography.Paragraph>
      </Card>

      <Card
        title="Publishing"
        extra={
          untargetedAccounts.length > 0 && (
            <Button size="small" onClick={() => setTargetModalOpen(true)}>Add Targets</Button>
          )
        }
      >
        {summary && summary.total > 0 && (
          <Typography.Paragraph type="secondary">
            {summary.published} / {summary.total} published
          </Typography.Paragraph>
        )}
        {targets.length === 0 ? (
          <Typography.Text type="secondary">No publishing targets yet. Add social accounts as targets.</Typography.Text>
        ) : (
          targets.map((target) => (
            <PublishTargetPanel
              key={target.id}
              target={target}
              post={post}
              channelId={channelId!}
              postId={postId!}
            />
          ))
        )}
      </Card>

      <Modal
        title="Add Publishing Targets"
        open={targetModalOpen}
        onCancel={() => setTargetModalOpen(false)}
        onOk={handleAddTargets}
        confirmLoading={createTargets.isPending}
      >
        <Checkbox.Group
          style={{ display: 'flex', flexDirection: 'column', gap: 8 }}
          value={selectedAccounts}
          onChange={(v) => setSelectedAccounts(v as string[])}
          options={untargetedAccounts.map((a) => ({ label: `${a.name} (${a.platform})`, value: a.id }))}
        />
      </Modal>
    </div>
  );
}
