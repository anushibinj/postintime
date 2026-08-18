import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { createApiToken, deleteApiToken, fetchApiTokens, refreshApiToken, updateApiToken } from '../api/apiTokens';

export function useApiTokens() {
  return useQuery({
    queryKey: ['api-tokens'],
    queryFn: fetchApiTokens,
  });
}

export function useApiTokenMutations() {
  const queryClient = useQueryClient();
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['api-tokens'] });

  return {
    create: useMutation({
      mutationFn: createApiToken,
      onSuccess: invalidate,
    }),
    update: useMutation({
      mutationFn: ({ tokenId, data }: { tokenId: string; data: Parameters<typeof updateApiToken>[1] }) =>
        updateApiToken(tokenId, data),
      onSuccess: invalidate,
    }),
    refresh: useMutation({
      mutationFn: ({ tokenId, data }: { tokenId: string; data?: Parameters<typeof refreshApiToken>[1] }) =>
        refreshApiToken(tokenId, data),
      onSuccess: invalidate,
    }),
    remove: useMutation({
      mutationFn: deleteApiToken,
      onSuccess: invalidate,
    }),
  };
}
