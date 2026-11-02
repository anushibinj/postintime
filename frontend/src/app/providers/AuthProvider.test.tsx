import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, render, screen } from '@testing-library/react';
import { AuthProvider, useAuth } from './AuthProvider';

const DAY_MS = 24 * 60 * 60 * 1000;

function makeToken(expiresInMs: number): string {
  const payload = {
    sub: 'user-1',
    email: 'a@b.c',
    exp: Math.floor((Date.now() + expiresInMs) / 1000),
  };
  return `h.${btoa(JSON.stringify(payload))}.s`;
}

function Probe() {
  const { isAuthenticated } = useAuth();
  return <div>{isAuthenticated ? 'in' : 'out'}</div>;
}

describe('AuthProvider session lifetime', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    localStorage.clear();
  });

  it('keeps a 30 day session logged in (delay exceeds the 32-bit setTimeout limit)', async () => {
    localStorage.setItem('postintime_token', makeToken(30 * DAY_MS));
    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );
    await act(async () => {
      await vi.advanceTimersByTimeAsync(7 * DAY_MS);
    });
    expect(screen.getByText('in')).toBeTruthy();
  });

  it('logs out once the token really expires', async () => {
    localStorage.setItem('postintime_token', makeToken(30 * DAY_MS));
    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );
    await act(async () => {
      await vi.advanceTimersByTimeAsync(30 * DAY_MS + 1000);
    });
    expect(screen.getByText('out')).toBeTruthy();
  });
});
