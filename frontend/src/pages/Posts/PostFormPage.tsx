import { Button, Card, Form, Input, Radio, Typography, message } from 'antd';
import { useNavigate, useParams } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { MediaUploader } from '../../components/MediaUploader/MediaUploader';
import { useCreatePost, usePost, useUpdatePost } from '../../hooks/usePosts';
import type { MediaInfo, PostStatus } from '../../types';

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

  const handleSubmit = async () => {
    try {
      const data = { title, caption, status, mediaId: media?.id };
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

  return (
    <Card>
      <Typography.Title level={3}>{isEdit ? 'Edit Post' : 'Create Post'}</Typography.Title>
      <Form layout="vertical" onFinish={handleSubmit}>
        <Form.Item label="Title" required>
          <Input value={title} onChange={(e) => setTitle(e.target.value)} />
        </Form.Item>
        <Form.Item label="Caption">
          <Input.TextArea rows={4} value={caption} onChange={(e) => setCaption(e.target.value)} />
        </Form.Item>
        <Form.Item label="Image">
          <MediaUploader value={media} onChange={setMedia} />
        </Form.Item>
        <Form.Item label="Status">
          <Radio.Group value={status} onChange={(e) => setStatus(e.target.value)}>
            <Radio value="draft">Draft</Radio>
            <Radio value="ready">Ready</Radio>
          </Radio.Group>
        </Form.Item>
        <Button type="primary" htmlType="submit" loading={createPost.isPending || updatePost.isPending}>
          Save Post
        </Button>
      </Form>
    </Card>
  );
}
