import { Button, Card, Checkbox, Col, Modal, Row, Segmented, Space, Typography, message } from 'antd';
import { ArrowLeft, Edit, ImageOff, Trash2 } from 'lucide-react';
import { useNavigate, useParams } from 'react-router-dom';
import { lazy, Suspense, useState } from 'react';
import { usePost, useDeletePost } from '../../hooks/usePosts';
import { useTargets, usePublishingMutations } from '../../hooks/usePublishTarget';
import { useSocialAccounts } from '../../hooks/useSocialAccounts';
import { PageLoader } from '../../components/PageLoader/PageLoader';

const PublishTargetPanel = lazy(() => import('../../components/PublishTarget/PublishTarget'));

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
  const caption = post.caption || '';

  const handleAddTargets = async () => {
    if (selectedAccounts.length === 0) return;
    await createTargets.mutateAsync(selectedAccounts);
    setTargetModalOpen(false);
    setSelectedAccounts([]);
    message.success('Targets added');
  };

  const goBack = () => navigate(`/channels/${channelId}`);

  return (
    <div>
      <Button
        type="text"
        icon={<ArrowLeft size={16} />}
        onClick={goBack}
        style={{ paddingLeft: 0, marginBottom: 8 }}
      >
        Back to Posts
      </Button>
      <Space style={{ width: '100%', justifyContent: 'space-between', marginBottom: 24 }} align="start">
        <div>
          <Typography.Title level={3} style={{ margin: 0 }}>View post</Typography.Title>
          <Typography.Text type="secondary">Review the image, caption, and publishing status.</Typography.Text>
        </div>
        <Space>
          <Button icon={<Edit size={16} />} onClick={() => navigate(`/channels/${channelId}/posts/${postId}/edit`)}>
            Edit
          </Button>
          <Button danger icon={<Trash2 size={16} />} onClick={() => {
            Modal.confirm({
              title: 'Delete post?',
              onOk: async () => {
                await deletePost.mutateAsync(postId!);
                navigate(`/channels/${channelId}`);
              },
            });
          }}>Delete</Button>
        </Space>
      </Space>

      <Row gutter={[24, 24]}>
        <Col xs={24} lg={10}>
          <Card title="Image" styles={{ body: { minHeight: 280 } }}>
            {post.media?.url ? (
              <img
                src={post.media.url}
                alt={post.title}
                style={{
                  width: '100%',
                  maxHeight: 420,
                  objectFit: 'contain',
                  background: '#fafafa',
                  borderRadius: 12,
                  border: '1px solid #f0f0f0',
                  display: 'block',
                }}
              />
            ) : (
              <div
                style={{
                  minHeight: 220,
                  border: '1px dashed #d9d9d9',
                  borderRadius: 12,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#8c8c8c',
                  gap: 8,
                }}
              >
                <ImageOff size={40} />
                <Typography.Text type="secondary">No image</Typography.Text>
              </div>
            )}
          </Card>
        </Col>
        <Col xs={24} lg={14}>
          <Card>
            <Typography.Text type="secondary">Title</Typography.Text>
            <Typography.Title level={3} style={{ marginTop: 8, marginBottom: 24, fontSize: 20, fontWeight: 600 }}>
              {post.title}
            </Typography.Title>

            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <Typography.Text type="secondary">Caption</Typography.Text>
              <Typography.Text type="secondary">{caption.length} characters</Typography.Text>
            </div>
            <Typography.Paragraph
              style={{
                marginBottom: 24,
                fontSize: 15,
                minHeight: 160,
                whiteSpace: 'pre-wrap',
              }}
            >
              {caption || 'No caption'}
            </Typography.Paragraph>

            <Typography.Text type="secondary">Status</Typography.Text>
            <div style={{ marginTop: 8 }}>
              <Segmented
                value={post.status}
                options={[
                  { label: 'Draft', value: 'draft' },
                  { label: 'Ready', value: 'ready' },
                ]}
                style={{ pointerEvents: 'none' }}
              />
              <Typography.Paragraph type="secondary" style={{ marginTop: 8, marginBottom: 0 }}>
                {post.status === 'draft'
                  ? 'Keep working on this post. Drafts are not treated as ready to publish.'
                  : 'This post is ready. You can add publishing targets and mark them published.'}
              </Typography.Paragraph>
            </div>
          </Card>
        </Col>
      </Row>

      <Card
        title="Publishing"
        style={{ marginTop: 24 }}
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
          <Suspense fallback={<PageLoader />}>
            {targets.map((target) => (
              <PublishTargetPanel
                key={target.id}
                target={target}
                post={post}
                channelId={channelId!}
                postId={postId!}
              />
            ))}
          </Suspense>
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

export default PostDetailPage;
