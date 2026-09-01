import { Button, Card, Col, Input, Row, Segmented, Space, Typography, message } from 'antd';
import { ArrowLeft } from 'lucide-react';
import { useNavigate, useParams } from 'react-router-dom';
import { lazy, Suspense, useEffect, useState } from 'react';
import { useCreatePost, usePost, useUpdatePost } from '../../hooks/usePosts';
import { PageLoader } from '../../components/PageLoader/PageLoader';
import type { MediaInfo, PostStatus } from '../../types';

const MediaUploader = lazy(() => import('../../components/MediaUploader/MediaUploader'));

export function PostFormPage() {
  const { channelId, postId } = useParams();
  const navigate = useNavigate();
  const isEdit = !!postId;
  const { data: existingPost } = usePost(channelId, postId);
  const createPost = useCreatePost(channelId!);
  const updatePost = useUpdatePost(channelId!, postId!);
  const [title, setTitle] = useState('');
  const [caption, setCaption] = useState('');
  const [status, setStatus] = useState<PostStatus>('draft');
  const [media, setMedia] = useState<MediaInfo | null>(null);

  useEffect(() => {
    if (existingPost) {
      setTitle(existingPost.title);
      setCaption(existingPost.caption || '');
      setStatus(existingPost.status);
      setMedia(existingPost.media || null);
    }
  }, [existingPost]);

  const goBack = () => {
    navigate(`/channels/${channelId}`);
  };

  const handleSubmit = async () => {
    if (!title.trim()) {
      message.warning('Add a title before saving');
      return;
    }
    try {
      const data = { title: title.trim(), caption, status, mediaId: media?.id };
      if (isEdit) {
        await updatePost.mutateAsync(data);
        message.success('Post updated');
        navigate(`/channels/${channelId}/posts/${postId}`);
      } else {
        const post = await createPost.mutateAsync(data);
        message.success('Post created');
        navigate(`/channels/${channelId}/posts/${post.id}`);
      }
    } catch {
      message.error('Failed to save post');
    }
  };

  const saving = createPost.isPending || updatePost.isPending;

  return (
    <div>
      <div
        style={{
          position: 'sticky',
          top: -24,
          zIndex: 20,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 16,
          margin: '-24px -24px 24px',
          padding: '12px 24px',
          background: '#fff',
          borderBottom: '1px solid #f0f0f0',
        }}
      >
        <Space>
          <Button type="text" icon={<ArrowLeft size={16} />} onClick={goBack}>
            Back to Posts
          </Button>
          <Typography.Title level={4} style={{ margin: 0 }}>
            {isEdit ? 'Edit post' : 'New post'}
          </Typography.Title>
        </Space>
        <Space>
          <Button onClick={goBack}>Cancel</Button>
          <Button type="primary" onClick={handleSubmit} loading={saving} disabled={!title.trim()}>
            {isEdit ? 'Save changes' : 'Create post'}
          </Button>
        </Space>
      </div>

      <Typography.Paragraph type="secondary" style={{ marginBottom: 24 }}>
        {isEdit ? 'Update the image, caption, and status.' : 'Add media and write the caption you will publish.'}
      </Typography.Paragraph>

      <Row gutter={[24, 24]}>
        <Col xs={24} lg={10}>
          <Card title="Image" styles={{ body: { minHeight: 280 } }}>
            <Suspense fallback={<PageLoader />}>
              <MediaUploader value={media} onChange={setMedia} />
            </Suspense>
          </Card>
        </Col>
        <Col xs={24} lg={14}>
          <Card>
            <Typography.Text type="secondary">Title</Typography.Text>
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="What is this post about?"
              size="large"
              maxLength={200}
              style={{ marginTop: 8, marginBottom: 24, fontSize: 20, fontWeight: 600 }}
            />

            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <Typography.Text type="secondary">Caption</Typography.Text>
              <Typography.Text type="secondary">{caption.length} characters</Typography.Text>
            </div>
            <Input.TextArea
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
              placeholder="Write the caption you will copy to social accounts..."
              autoSize={{ minRows: 8, maxRows: 16 }}
              style={{ marginBottom: 24, fontSize: 15 }}
            />

            <Typography.Text type="secondary">Status</Typography.Text>
            <div style={{ marginTop: 8 }}>
              <Segmented
                value={status}
                onChange={(value) => setStatus(value as PostStatus)}
                options={[
                  { label: 'Draft', value: 'draft' },
                  { label: 'Ready', value: 'ready' },
                ]}
              />
              <Typography.Paragraph type="secondary" style={{ marginTop: 8, marginBottom: 0 }}>
                {status === 'draft'
                  ? 'Keep working on this post. Drafts are not treated as ready to publish.'
                  : 'This post is ready. You can add publishing targets and mark them published.'}
              </Typography.Paragraph>
            </div>
          </Card>
        </Col>
      </Row>
    </div>
  );
}

export default PostFormPage;
