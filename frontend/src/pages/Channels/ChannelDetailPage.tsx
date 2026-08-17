import { Button, Space, Typography } from 'antd';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { fetchChannel } from '../../api/channels';
import { usePosts } from '../../hooks/usePosts';
import { PostList } from '../../components/PostCard/PostCard';
import { Plus } from 'lucide-react';

export function ChannelDetailPage() {
  const { channelId } = useParams();
  const navigate = useNavigate();
  const { data: channel } = useQuery({
    queryKey: ['channel', channelId],
    queryFn: () => fetchChannel(channelId!),
    enabled: !!channelId,
  });
  const { data: postsData } = usePosts(channelId, { size: 5, sort: 'updatedAt,desc' });

  if (!channel) return null;

  return (
    <div>
      <Space style={{ width: '100%', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
        <Typography.Title level={2} style={{ margin: 0 }}>{channel.name}</Typography.Title>
        <Button onClick={() => navigate(`/channels/${channelId}/social-accounts`)}>
          Manage social accounts
        </Button>
      </Space>
      <Typography.Paragraph type="secondary" style={{ marginBottom: 8 }}>
        {channel.description}
      </Typography.Paragraph>
      <Typography.Text type="secondary" style={{ display: 'block', marginBottom: 24 }}>
        {channel.postCount} posts · {channel.socialAccountCount} social accounts
      </Typography.Text>

      <SpaceBetween title="Recent Posts" channelId={channelId!} />
      <PostList posts={postsData?.items || []} channelId={channelId!} />
    </div>
  );
}

function SpaceBetween({ title, channelId }: { title: string; channelId: string }) {
  const navigate = useNavigate();
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
      <Typography.Title level={4} style={{ margin: 0 }}>{title}</Typography.Title>
      <Button type="primary" icon={<Plus size={16} />} onClick={() => navigate(`/channels/${channelId}/posts/new`)}>
        New Post
      </Button>
    </div>
  );
}
