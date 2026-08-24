import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { fetchTargets, createTargets, publishTarget, markPublished, resetTarget, togglePublished as togglePublishedRequest } from '../api/publishing';

export function useTargets(channelId: string | undefined, postId: string | undefined) {
  return useQuery({
    queryKey: ['targets', channelId, postId],
    queryFn: () => fetchTargets(channelId!, postId!),
    enabled: !!channelId && !!postId,
  });
}

export function usePublishingMutations(channelId: string, postId: string) {
  const queryClient = useQueryClient();
  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['targets', channelId, postId] });
    queryClient.invalidateQueries({ queryKey: ['post', channelId, postId] });
    queryClient.invalidateQueries({ queryKey: ['posts', channelId] });
  };

  return {
    createTargets: useMutation({
      mutationFn: (socialAccountIds: string[]) => createTargets(channelId, postId, socialAccountIds),
      onSuccess: invalidate,
    }),
    publish: useMutation({
      mutationFn: (targetId: string) => publishTarget(channelId, postId, targetId),
      onSuccess: invalidate,
    }),
    markPublished: useMutation({
      mutationFn: (targetId: string) => markPublished(channelId, postId, targetId),
      onSuccess: invalidate,
    }),
    reset: useMutation({
      mutationFn: (targetId: string) => resetTarget(channelId, postId, targetId),
      onSuccess: invalidate,
    }),
    togglePublished: useMutation({
      mutationFn: (socialAccountId: string) => togglePublishedRequest(channelId, postId, socialAccountId),
      onSuccess: invalidate,
    }),
  };
}
