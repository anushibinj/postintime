import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { apiFetch, REQUEST_TIMEOUT_MS } from './client';

describe('apiFetch timeout', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    localStorage.setItem('postintime_token', 'opaque-token');
    // A server that never answers; only an abort ends the request.
    vi.stubGlobal('fetch', vi.fn((_url: string, init: RequestInit) => new Promise((_resolve, reject) => {
      init.signal?.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')));
    })));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
    localStorage.clear();
  });

  it('waits 15 minutes before giving up', async () => {
    expect(REQUEST_TIMEOUT_MS).toBe(15 * 60 * 1000);
    let settled = false;
    const request = apiFetch('/api/v1/slow').finally(() => {
      settled = true;
    });
    const outcome = request.catch((error: Error) => error);

    await vi.advanceTimersByTimeAsync(REQUEST_TIMEOUT_MS - 1);
    expect(settled).toBe(false);

    await vi.advanceTimersByTimeAsync(1);
    expect(((await outcome) as Error).message).toBe('The server did not respond within 15 minutes. Please try again.');
  });

  it('still honours a caller abort', async () => {
    const controller = new AbortController();
    const outcome = apiFetch('/api/v1/slow', { signal: controller.signal }).catch((error: Error) => error);

    controller.abort();

    expect(((await outcome) as Error).name).toBe('AbortError');
  });

  it('returns responses that arrive in time', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ok: true }), { status: 200 })));

    await expect(apiFetch('/api/v1/fast')).resolves.toEqual({ ok: true });
  });
});
