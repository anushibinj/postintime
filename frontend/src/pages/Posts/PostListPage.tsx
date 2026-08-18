import { Button, Input, Select, Space, Typography } from 'antd';
import { ArrowLeft, Plus } from 'lucide-react';
import { useNavigate, useParams } from 'react-router-dom';
import { useState } from 'react';
import { usePosts } from '../../hooks/usePosts';
import { PostList } from '../../components/PostCard/PostCard';
import type { PostStatus } from '../../types';

export function PostListPage() {
  const { channelId } = useParams();
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<PostStatus | undefined>();
  const { data: postsData, isLoading } = usePosts(channelId, { search, status, size: 20 });

  return (
    <div>
      <Button
        type="text"
        icon={<ArrowLeft size={16} />}
        onClick={() => navigate('/channels')}
        style={{ paddingLeft: 0, marginBottom: 8 }}
      >
        Back to Channels
      </Button>
      <Space style={{ width: '100%', justifyContent: 'space-between', marginBottom: 24 }}>
        <Typography.Title level={2} style={{ margin: 0 }}>Posts</Typography.Title>
        <Button type="primary" icon={<Plus size={16} />} onClick={() => navigate(`/channels/${channelId}/posts/new`)}>
          New Post
        </Button>
      </Space>

      <Space style={{ marginBottom: 16 }}>
        <Input.Search placeholder="Search posts..." onSearch={setSearch} style={{ width: 300 }} allowClear />
        <Select
          placeholder="Status"
          allowClear
          style={{ width: 120 }}
          onChange={(v) => setStatus(v)}
          options={[
            { value: 'draft', label: 'Draft' },
            { value: 'ready', label: 'Ready' },
          ]}
        />
      </Space>

      {isLoading ? <Typography.Text>Loading...</Typography.Text> : (
        <PostList posts={postsData?.items || []} channelId={channelId!} />
      )}
    </div>
  );
}
