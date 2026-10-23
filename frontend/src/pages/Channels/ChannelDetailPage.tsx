import { Button, Checkbox, Space, Typography, message } from 'antd';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { lazy, Suspense, useState, type ReactNode } from 'react';
import { fetchChannel } from '../../api/channels';
import { usePosts } from '../../hooks/usePosts';
import { useSocialAccounts } from '../../hooks/useSocialAccounts';
import { useBulkPublishMutations } from '../../hooks/useBulkPublish';
import { parsePageParam, parseSizeParam } from '../../hooks/postListParams';
import { PageLoader } from '../../components/PageLoader/PageLoader';
import { ArrowLeft, Plus, Send } from 'lucide-react';
import type { Post } from '../../types';

const PostList = lazy(() => import('../../components/PostCard/PostCard'));
const PostsPager = lazy(() => import('../../components/PostsPager/PostsPager'));
const BulkPublishModal = lazy(() => import('../../components/BulkPublish/BulkPublishModal'));
const BulkPublishJobs = lazy(() => import('../../components/BulkPublish/BulkPublishJobs'));

/** Selected post titles keyed by id; Map insertion order is the bulk posting order. */
type Selection = { channelId?: string; posts: Map<string, string> };

export function ChannelDetailPage() {
  const { channelId } = useParams();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const page = parsePageParam(searchParams.get('page'));
  const size = parseSizeParam(searchParams.get('size'));
  const { data: channel } = useQuery({
    queryKey: ['channel', channelId],
    queryFn: () => fetchChannel(channelId!),
    enabled: !!channelId,
  });
  const { data: postsData, isLoading } = usePosts(channelId, { page, size, sort: 'updatedAt,desc' });
  const { data: accounts = [] } = useSocialAccounts(channelId);
  const { create: createBulkJob } = useBulkPublishMutations(channelId!);
  const [selection, setSelection] = useState<Selection>({ posts: new Map() });
  const [bulkModalOpen, setBulkModalOpen] = useState(false);

  // Selection survives paging but not switching channels.
  const selected = selection.channelId === channelId ? selection.posts : new Map<string, string>();
  const pagePosts = postsData?.items || [];
  const selectedOnPage = pagePosts.filter((post) => selected.has(post.id)).length;

  const updateSelection = (update: (posts: Map<string, string>) => void) => {
    const next = new Map(selected);
    update(next);
    setSelection({ channelId, posts: next });
  };

  const handleSelectPost = (post: Post, checked: boolean) => {
    updateSelection((posts) => {
      if (checked) {
        posts.set(post.id, post.title);
      } else {
        posts.delete(post.id);
      }
    });
  };

  const handleSelectPage = (checked: boolean) => {
    updateSelection((posts) => {
      pagePosts.forEach((post) => (checked ? posts.set(post.id, post.title) : posts.delete(post.id)));
    });
  };

  const handleStartBulk = async (intervalMinutes: number) => {
    try {
      await createBulkJob.mutateAsync({ postIds: [...selected.keys()], intervalMinutes });
      message.success(`Bulk posting started for ${selected.size} ${selected.size === 1 ? 'post' : 'posts'}`);
      setBulkModalOpen(false);
      setSelection({ channelId, posts: new Map() });
    } catch (error) {
      message.error(error instanceof Error ? error.message : 'Could not start bulk posting');
    }
  };

  if (!channel) return null;

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

      <Suspense fallback={null}>
        <BulkPublishJobs channelId={channelId!} />
      </Suspense>

      <SpaceBetween
        title="Posts"
        channelId={channelId!}
        bulkActions={
          pagePosts.length > 0 && (
            <Space size={8} wrap>
              <Checkbox
                checked={selectedOnPage === pagePosts.length}
                indeterminate={selectedOnPage > 0 && selectedOnPage < pagePosts.length}
                onChange={(event) => handleSelectPage(event.target.checked)}
              >
                Select page
              </Checkbox>
              {selected.size > 0 && (
                <>
                  <Typography.Text type="secondary">{selected.size} selected</Typography.Text>
                  <Button size="small" type="link" onClick={() => setSelection({ channelId, posts: new Map() })}>
                    Clear
                  </Button>
                  <Button icon={<Send size={14} />} onClick={() => setBulkModalOpen(true)}>
                    Bulk post
                  </Button>
                </>
              )}
            </Space>
          )
        }
      />
      {isLoading ? (
        <Typography.Text>Loading...</Typography.Text>
      ) : (
        <Suspense fallback={<PageLoader />}>
          <PostList
            posts={pagePosts}
            channelId={channelId!}
            selectedIds={new Set(selected.keys())}
            onSelectChange={handleSelectPost}
          />
          <PostsPager
            page={postsData?.page ?? page}
            size={postsData?.size ?? size}
            totalItems={postsData?.totalItems ?? 0}
            onChange={(nextPage, nextSize) => {
              setSearchParams({ page: String(nextPage), size: String(nextSize) });
            }}
          />
        </Suspense>
      )}
      {bulkModalOpen && (
        <Suspense fallback={null}>
          <BulkPublishModal
            open={bulkModalOpen}
            posts={[...selected].map(([id, title]) => ({ id, title }))}
            accounts={accounts}
            submitting={createBulkJob.isPending}
            onCancel={() => setBulkModalOpen(false)}
            onSubmit={handleStartBulk}
          />
        </Suspense>
      )}
    </div>
  );
}

export default ChannelDetailPage;

function SpaceBetween({ title, channelId, bulkActions }: { title: string; channelId: string; bulkActions?: ReactNode }) {
  const navigate = useNavigate();
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap', marginBottom: 16 }}>
      <Typography.Title level={4} style={{ margin: 0 }}>{title}</Typography.Title>
      <Space size={12} wrap>
        {bulkActions}
        <Button type="primary" icon={<Plus size={16} />} onClick={() => navigate(`/channels/${channelId}/posts/new`)}>
          New Post
        </Button>
      </Space>
    </div>
  );
}
