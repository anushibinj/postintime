import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  fetchSocialAccounts,
  createSocialAccount,
  updateSocialAccount,
  deleteSocialAccount,
  enableSocialAccount,
  disableSocialAccount,
} from '../api/socialAccounts';

export function useSocialAccounts(channelId: string | undefined) {
  return useQuery({
    queryKey: ['social-accounts', channelId],
    queryFn: () => fetchSocialAccounts(channelId!),
    enabled: !!channelId,
  });
}

export function useSocialAccountMutations(channelId: string) {
  const queryClient = useQueryClient();
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['social-accounts', channelId] });

  return {
    create: useMutation({ mutationFn: createSocialAccount.bind(null, channelId), onSuccess: invalidate }),
    update: useMutation({
      mutationFn: ({ accountId, data }: { accountId: string; data: Parameters<typeof updateSocialAccount>[2] }) =>
        updateSocialAccount(channelId, accountId, data),
      onSuccess: invalidate,
    }),
    remove: useMutation({ mutationFn: (accountId: string) => deleteSocialAccount(channelId, accountId), onSuccess: invalidate }),
    enable: useMutation({ mutationFn: (accountId: string) => enableSocialAccount(channelId, accountId), onSuccess: invalidate }),
    disable: useMutation({ mutationFn: (accountId: string) => disableSocialAccount(channelId, accountId), onSuccess: invalidate }),
  };
}
