import { Card, Col, Row, Statistic, Typography } from 'antd';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { fetchChannel } from '../../api/channels';
import { usePosts } from '../../hooks/usePosts';
import { PostList } from '../../components/PostCard/PostCard';
import { Button } from 'antd';
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
      <Typography.Title level={2}>{channel.name}</Typography.Title>
      <Typography.Paragraph type="secondary">{channel.description}</Typography.Paragraph>

      <Row gutter={16} style={{ marginBottom: 24 }}>
        <Col span={8}>
          <Card><Statistic title="Posts" value={channel.postCount} /></Card>
        </Col>
        <Col span={8}>
          <Card><Statistic title="Social Accounts" value={channel.socialAccountCount} /></Card>
        </Col>
        <Col span={8}>
          <Card>
            <Button onClick={() => navigate(`/channels/${channelId}/social-accounts`)}>Manage Social Accounts</Button>
          </Card>
        </Col>
      </Row>

      <SpaceBetween title="Recent Posts" channelId={channelId!} />
      <PostList posts={postsData?.items || []} channelId={channelId!} />
    </div>
  );
}

function SpaceBetween({ title, channelId }: { title: string; channelId: string }) {
  const navigate = useNavigate();
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
      <Typography.Title level={4}>{title}</Typography.Title>
      <Button type="primary" icon={<Plus size={16} />} onClick={() => navigate(`/channels/${channelId}/posts/new`)}>
        New Post
      </Button>
    </div>
  );
}
