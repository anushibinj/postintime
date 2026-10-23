import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { cancelBulkPublishJob, createBulkPublishJob, fetchBulkPublishJobs } from '../api/bulkPublish';

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
  };

  return {
    create: useMutation({
      mutationFn: ({ postIds, intervalMinutes }: { postIds: string[]; intervalMinutes: number }) =>
        createBulkPublishJob(channelId, postIds, intervalMinutes),
      onSuccess: invalidate,
    }),
    cancel: useMutation({
      mutationFn: (jobId: string) => cancelBulkPublishJob(channelId, jobId),
      onSuccess: invalidate,
    }),
  };
}
