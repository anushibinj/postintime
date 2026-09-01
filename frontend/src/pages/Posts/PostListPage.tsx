import { Button, Input, Select, Space, Typography } from 'antd';
import { ArrowLeft, Plus } from 'lucide-react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { lazy, Suspense, useState } from 'react';
import { usePosts } from '../../hooks/usePosts';
import { parsePageParam, parseSizeParam } from '../../hooks/postListParams';
import { PageLoader } from '../../components/PageLoader/PageLoader';
import type { PostStatus } from '../../types';

const PostList = lazy(() => import('../../components/PostCard/PostCard'));
const PostsPager = lazy(() => import('../../components/PostsPager/PostsPager'));

export function PostListPage() {
  const { channelId } = useParams();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const page = parsePageParam(searchParams.get('page'));
  const size = parseSizeParam(searchParams.get('size'));
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<PostStatus | undefined>();
  const { data: postsData, isLoading } = usePosts(channelId, { page, size, search, status });

  const updatePaging = (nextPage: number, nextSize: number) => {
    setSearchParams({ page: String(nextPage), size: String(nextSize) });
  };

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
        <Input.Search
          placeholder="Search posts..."
          onSearch={(value) => {
            setSearch(value);
            updatePaging(0, size);
          }}
          style={{ width: 300 }}
          allowClear
        />
        <Select
          placeholder="Status"
          allowClear
          style={{ width: 120 }}
          onChange={(v) => {
            setStatus(v);
            updatePaging(0, size);
          }}
          options={[
            { value: 'draft', label: 'Draft' },
            { value: 'ready', label: 'Ready' },
          ]}
        />
      </Space>

      {isLoading ? <Typography.Text>Loading...</Typography.Text> : (
        <Suspense fallback={<PageLoader />}>
          <PostList posts={postsData?.items || []} channelId={channelId!} />
          <PostsPager
            page={postsData?.page ?? page}
            size={postsData?.size ?? size}
            totalItems={postsData?.totalItems ?? 0}
            onChange={updatePaging}
          />
        </Suspense>
      )}
    </div>
  );
}

export default PostListPage;
