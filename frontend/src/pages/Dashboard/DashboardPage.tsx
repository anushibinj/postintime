import { Button, Input, Select, Space, Typography } from 'antd';
import { Plus } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { useChannels } from '../../hooks/useChannels';
import { useChannelContext } from '../../app/providers/ChannelProvider';
import { usePosts } from '../../hooks/usePosts';
import { PostList } from '../../components/PostCard/PostCard';
import type { PostStatus } from '../../types';

export function DashboardPage() {
  const navigate = useNavigate();
  const { data: channels = [] } = useChannels();
  const { selectedChannelId, setSelectedChannelId } = useChannelContext();
  const channelId = selectedChannelId || channels[0]?.id;
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<PostStatus | undefined>();

  useEffect(() => {
    if (!selectedChannelId && channels[0]) {
      setSelectedChannelId(channels[0].id);
    }
  }, [channels, selectedChannelId, setSelectedChannelId]);

  const { data: postsData, isLoading } = usePosts(channelId, { search, status, size: 20 });

  if (channels.length === 0) {
    return (
      <div>
        <Typography.Title level={2}>Welcome to PostInTime</Typography.Title>
        <Typography.Paragraph>Create your first channel to get started.</Typography.Paragraph>
        <Button type="primary" onClick={() => navigate('/channels')}>Create Channel</Button>
      </div>
    );
  }

  return (
    <div>
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
