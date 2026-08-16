import { useQuery } from '@tanstack/react-query';
import { fetchChannels } from '../api/channels';

export function useChannels() {
  return useQuery({
    queryKey: ['channels'],
    queryFn: fetchChannels,
  });
}
