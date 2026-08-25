import { Empty, Modal, Tooltip, Typography } from 'antd';
import { Check, ImageOff } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import type { Platform, Post, SocialAccount } from '../../types';
import { useSocialAccounts } from '../../hooks/useSocialAccounts';
import { togglePublished } from '../../api/publishing';
import { mediaUrlWithSize } from '../../api/media';

const THUMB_SIZE = 64;
const ICON_SIZE = 36;

const PLATFORM_COLORS: Record<Platform, string> = {
  linkedin: '#0a66c2',
  instagram: '#e4405f',
  whatsapp: '#25d366',
  youtube: '#ff0000',
  x: '#111111',
  facebook: '#1877f2',
  threads: '#111111',
};

export function PostCard({ post, channelId, accounts }: { post: Post; channelId: string; accounts: SocialAccount[] }) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const targets = post.targets || [];
  const enabledAccounts = accounts.filter((account) => account.enabled);

  const toggle = useMutation({
    mutationFn: (socialAccountId: string) => togglePublished(channelId, post.id, socialAccountId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['posts', channelId] });
      queryClient.invalidateQueries({ queryKey: ['post', channelId, post.id] });
      queryClient.invalidateQueries({ queryKey: ['targets', channelId, post.id] });
    },
    onError: (error: Error) => {
      Modal.error({
        title: 'Publish failed',
        content: (
          <Typography.Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
            {error.message || 'Could not update publish status'}
          </Typography.Paragraph>
        ),
      });
    },
  });

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
        alignItems: 'center',
      }}
    >
      <PostThumb url={post.media?.url} title={post.title} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <Typography.Title level={5} style={{ margin: 0 }} ellipsis>
          {post.title}
        </Typography.Title>
        {post.caption && (
          <Typography.Paragraph type="secondary" ellipsis={{ rows: 1 }} style={{ margin: '4px 0 0' }}>
            {post.caption}
          </Typography.Paragraph>
        )}
      </div>
      {enabledAccounts.length > 0 && (
        <div style={{ display: 'flex', gap: 8, flexShrink: 0, alignItems: 'center' }}>
          {enabledAccounts.map((account) => {
            const target = targets.find((item) => item.socialAccountId === account.id);
            const posted = target?.status === 'published';
            return (
              <AccountToggle
                key={account.id}
                account={account}
                posted={posted}
                disabled={toggle.isPending}
                onToggle={() => toggle.mutate(account.id)}
              />
            );
          })}
        </div>
      )}
    </div>
  );
}

function AccountToggle({
  account,
  posted,
  disabled,
  onToggle,
}: {
  account: SocialAccount;
  posted: boolean;
  disabled: boolean;
  onToggle: () => void;
}) {
  const color = PLATFORM_COLORS[account.platform];
  const webhook = account.postingMode === 'webhook';
  const actionLabel = posted
    ? `Unmark ${account.name}`
    : webhook
      ? `Send webhook for ${account.name}`
      : `Mark ${account.name} as posted`;
  return (
    <Tooltip title={`${account.name} · ${webhook ? 'Webhook' : 'Manual'} · ${posted ? 'Posted' : 'Not posted'}`}>
      <button
        type="button"
        aria-label={actionLabel}
        aria-pressed={posted}
        disabled={disabled}
        onClick={(event) => {
          event.stopPropagation();
          onToggle();
        }}
        style={{
          position: 'relative',
          width: ICON_SIZE,
          height: ICON_SIZE,
          borderRadius: 8,
          border: posted ? `1px solid ${color}` : '1px solid #e8e8e8',
          background: posted ? color : '#f5f5f5',
          color: posted ? '#fff' : '#8c8c8c',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: disabled ? 'wait' : 'pointer',
          padding: 0,
        }}
      >
        <PlatformGlyph platform={account.platform} />
        {posted && (
          <span
            style={{
              position: 'absolute',
              right: -4,
              bottom: -4,
              width: 14,
              height: 14,
              borderRadius: '50%',
              background: '#52c41a',
              color: '#fff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: '2px solid #fff',
            }}
          >
            <Check size={8} strokeWidth={3} />
          </span>
        )}
      </button>
    </Tooltip>
  );
}

function PlatformGlyph({ platform }: { platform: Platform }) {
  const labels: Record<Platform, string> = {
    linkedin: 'in',
    instagram: 'IG',
    whatsapp: 'WA',
    youtube: 'YT',
    x: 'X',
    facebook: 'f',
    threads: '@',
  };
  return <span style={{ fontSize: 12, fontWeight: 700, lineHeight: 1 }}>{labels[platform]}</span>;
}

function PostThumb({ url, title }: { url?: string; title: string }) {
  if (url) {
    return (
      <img
        alt={title}
        src={mediaUrlWithSize(url, THUMB_SIZE)}
        width={THUMB_SIZE}
        height={THUMB_SIZE}
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

export function PostList({ posts, channelId }: { posts: Post[]; channelId: string }) {
  const { data: accounts = [] } = useSocialAccounts(channelId);

  if (posts.length === 0) {
    return <Empty description="No posts yet" />;
  }
  return (
    <div>
      {posts.map((post) => (
        <PostCard key={post.id} post={post} channelId={channelId} accounts={accounts} />
      ))}
    </div>
  );
}
