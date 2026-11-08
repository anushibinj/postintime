import { describe, expect, it, vi, beforeEach } from 'vitest';
import { apiFetch } from './client';
import { BULK_DELETE_LIMIT, bulkDeletePosts } from './posts';

vi.mock('./client', () => ({ apiFetch: vi.fn() }));

const mockedFetch = vi.mocked(apiFetch);

describe('bulkDeletePosts', () => {
  beforeEach(() => {
    mockedFetch.mockReset();
  });

  it('posts the IDs to the channel bulk-delete endpoint and sums the deleted count', async () => {
    mockedFetch.mockResolvedValueOnce({ deletedCount: 2 });

    const result = await bulkDeletePosts('chan-1', ['a', 'b']);

    expect(mockedFetch).toHaveBeenCalledWith('/api/v1/channels/chan-1/posts/bulk-delete', {
      method: 'POST',
      body: JSON.stringify({ postIds: ['a', 'b'] }),
    });
    expect(result).toEqual({ deletedCount: 2 });
  });

  it('splits large selections into requests of at most the backend limit', async () => {
    const ids = Array.from({ length: BULK_DELETE_LIMIT + 5 }, (_, index) => `post-${index}`);
    mockedFetch
      .mockResolvedValueOnce({ deletedCount: BULK_DELETE_LIMIT })
      .mockResolvedValueOnce({ deletedCount: 5 });

    const result = await bulkDeletePosts('chan-1', ids);

    expect(mockedFetch).toHaveBeenCalledTimes(2);
    const firstBody = JSON.parse(mockedFetch.mock.calls[0][1]!.body as string);
    const secondBody = JSON.parse(mockedFetch.mock.calls[1][1]!.body as string);
    expect(firstBody.postIds).toHaveLength(BULK_DELETE_LIMIT);
    expect(secondBody.postIds).toEqual(ids.slice(BULK_DELETE_LIMIT));
    expect(result).toEqual({ deletedCount: BULK_DELETE_LIMIT + 5 });
  });

  it('makes no request for an empty selection', async () => {
    const result = await bulkDeletePosts('chan-1', []);

    expect(mockedFetch).not.toHaveBeenCalled();
    expect(result).toEqual({ deletedCount: 0 });
  });
});
