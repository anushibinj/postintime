import { Card, Col, Empty, Row, Tag, Typography } from 'antd';
import { useNavigate } from 'react-router-dom';
import type { Post } from '../../types';
import { format } from 'date-fns';

export function PostCard({ post, channelId }: { post: Post; channelId: string }) {
  const navigate = useNavigate();
  const summary = post.publicationSummary;

  return (
    <Card
      hoverable
      onClick={() => navigate(`/channels/${channelId}/posts/${post.id}`)}
      cover={post.media?.url ? <img alt={post.title} src={post.media.url} style={{ height: 160, objectFit: 'cover' }} /> : undefined}
    >
      <Typography.Title level={5}>{post.title}</Typography.Title>
      <Typography.Paragraph type="secondary" ellipsis={{ rows: 2 }}>
        {post.caption}
      </Typography.Paragraph>
      {summary && summary.total > 0 && (
        <Typography.Text type="secondary">
          {summary.published} / {summary.total} published
        </Typography.Text>
      )}
      <div style={{ marginTop: 8 }}>
        <Tag color={post.status === 'ready' ? 'green' : 'default'}>{post.status}</Tag>
        <Typography.Text type="secondary" style={{ marginLeft: 8, fontSize: 12 }}>
          {format(new Date(post.updatedAt), 'MMM d, yyyy')}
        </Typography.Text>
      </div>
    </Card>
  );
}

export function PostList({ posts, channelId }: { posts: Post[]; channelId: string }) {
  if (posts.length === 0) {
    return <Empty description="No posts yet" />;
  }
  return (
    <Row gutter={[16, 16]}>
      {posts.map((post) => (
        <Col key={post.id} xs={24} sm={12} lg={8}>
          <PostCard post={post} channelId={channelId} />
        </Col>
      ))}
    </Row>
  );
}
