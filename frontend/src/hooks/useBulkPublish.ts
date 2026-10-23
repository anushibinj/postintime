import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  cancelBulkPublishItem,
  cancelBulkPublishJob,
  createBulkPublishJob,
  fetchBulkPublishJobs,
} from '../api/bulkPublish';

const RUNNING_POLL_MS = 10_000;

export function useBulkPublishJobs(channelId: string | undefined) {
  return useQuery({
    queryKey: ['bulk-publish-jobs', channelId],
    queryFn: () => fetchBulkPublishJobs(channelId!),
    enabled: !!channelId,
    // Keep progress live only while a job is still working through its posts.
    refetchInterval: (query) =>
      query.state.data?.some((job) => job.status === 'running') ? RUNNING_POLL_MS : false,
  });
}

export function useBulkPublishMutations(channelId: string) {
  const queryClient = useQueryClient();
  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['bulk-publish-jobs', channelId] });
    queryClient.invalidateQueries({ queryKey: ['posts', channelId] });
    queryClient.invalidateQueries({ queryKey: ['post', channelId] });
  };

  return {
    create: useMutation({
      mutationFn: ({
        postIds,
        intervalMinutes,
        socialAccountIds,
      }: {
        postIds: string[];
        intervalMinutes: number;
        socialAccountIds: string[];
      }) => createBulkPublishJob(channelId, postIds, intervalMinutes, socialAccountIds),
      onSuccess: invalidate,
    }),
    cancel: useMutation({
      mutationFn: (jobId: string) => cancelBulkPublishJob(channelId, jobId),
      onSuccess: invalidate,
    }),
    cancelItem: useMutation({
      mutationFn: ({ jobId, itemId }: { jobId: string; itemId: string }) =>
        cancelBulkPublishItem(channelId, jobId, itemId),
      onSuccess: invalidate,
    }),
  };
}
