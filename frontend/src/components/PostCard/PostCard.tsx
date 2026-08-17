import { Empty, Tag, Typography } from 'antd';
import { ImageOff } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import type { Post, PostTargetSummary } from '../../types';
import { StatusBadge } from '../StatusBadge/StatusBadge';

const THUMB_SIZE = 64;

export function PostCard({ post, channelId }: { post: Post; channelId: string }) {
  const navigate = useNavigate();
  const targets = post.targets || [];

  return (
    <div
      onClick={() => navigate(`/channels/${channelId}/posts/${post.id}`)}
      style={{
        display: 'flex',
        gap: 12,
        padding: 12,
        marginBottom: 8,
        border: '1px solid #e8e8e8',
        borderRadius: 8,
        background: '#fff',
        cursor: 'pointer',
        alignItems: 'flex-start',
      }}
    >
      <PostThumb url={post.media?.url} title={post.title} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <Typography.Title level={5} style={{ margin: 0 }} ellipsis>
          {post.title}
        </Typography.Title>
        {post.caption && (
          <Typography.Paragraph type="secondary" ellipsis={{ rows: 1 }} style={{ margin: '4px 0 8px' }}>
            {post.caption}
          </Typography.Paragraph>
        )}
        <TargetStatusRow targets={targets} />
      </div>
    </div>
  );
}

function PostThumb({ url, title }: { url?: string; title: string }) {
  if (url) {
    return (
      <img
        alt={title}
        src={url}
        style={{
          width: THUMB_SIZE,
          height: THUMB_SIZE,
          objectFit: 'cover',
          borderRadius: 8,
          flexShrink: 0,
        }}
      />
    );
  }
  return (
    <div
      style={{
        width: THUMB_SIZE,
        height: THUMB_SIZE,
        borderRadius: 8,
        background: '#f5f5f5',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
        color: '#bfbfbf',
      }}
    >
      <ImageOff size={20} />
    </div>
  );
}

function TargetStatusRow({ targets }: { targets: PostTargetSummary[] }) {
  if (targets.length === 0) {
    return <Typography.Text type="secondary">Not published to any accounts</Typography.Text>;
  }
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, alignItems: 'center' }}>
      {targets.map((target, index) => (
        <span key={`${target.platform}-${target.name}-${index}`} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
          <Tag style={{ margin: 0 }}>{target.name}</Tag>
          <StatusBadge status={target.status} />
        </span>
      ))}
    </div>
  );
}

export function PostList({ posts, channelId }: { posts: Post[]; channelId: string }) {
  if (posts.length === 0) {
    return <Empty description="No posts yet" />;
  }
  return (
    <div>
      {posts.map((post) => (
        <PostCard key={post.id} post={post} channelId={channelId} />
      ))}
    </div>
  );
}
