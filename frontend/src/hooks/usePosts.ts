import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { fetchPosts, fetchPost, createPost, updatePost, deletePost, type PostFilters } from '../api/posts';

export function usePosts(channelId: string | undefined, filters: PostFilters = {}) {
  return useQuery({
    queryKey: ['posts', channelId, filters],
    queryFn: () => fetchPosts(channelId!, filters),
    enabled: !!channelId,
  });
}

export function usePost(channelId: string | undefined, postId: string | undefined) {
  return useQuery({
    queryKey: ['post', channelId, postId],
    queryFn: () => fetchPost(channelId!, postId!),
    enabled: !!channelId && !!postId,
  });
}

export function useCreatePost(channelId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: createPost.bind(null, channelId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['posts', channelId] });
      queryClient.invalidateQueries({ queryKey: ['channels'] });
    },
  });
}

export function useUpdatePost(channelId: string, postId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: Parameters<typeof updatePost>[2]) => updatePost(channelId, postId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['posts', channelId] });
      queryClient.invalidateQueries({ queryKey: ['post', channelId, postId] });
    },
  });
}

export function useDeletePost(channelId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (postId: string) => deletePost(channelId, postId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['posts', channelId] });
      queryClient.invalidateQueries({ queryKey: ['channels'] });
    },
  });
}
