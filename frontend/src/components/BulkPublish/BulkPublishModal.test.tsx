import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import { BulkPublishModal } from './BulkPublishModal';
import type { SocialAccount } from '../../types';

function account(overrides: Partial<SocialAccount>): SocialAccount {
  return {
    id: 'acc',
    platform: 'linkedin',
    name: 'Account',
    postingMode: 'webhook',
    enabled: true,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
    ...overrides,
  };
}

const posts = [
  { id: 'p1', title: 'First post' },
  { id: 'p2', title: 'Second post' },
  { id: 'p3', title: 'Third post' },
];

describe('BulkPublishModal', () => {
  it('defaults to a 5 minute interval on a 5-30 slider', () => {
    const onSubmit = vi.fn();
    render(
      <BulkPublishModal
        open
        posts={posts}
        accounts={[account({ id: 'a1', name: 'LinkedIn hook' })]}
        queueTail={null}
        queuedCount={0}
        submitting={false}
        onCancel={() => {}}
        onSubmit={onSubmit}
      />,
    );

    const slider = screen.getByRole('slider');
    expect(slider).toHaveAttribute('aria-valuemin', '5');
    expect(slider).toHaveAttribute('aria-valuemax', '30');
    expect(slider).toHaveAttribute('aria-valuenow', '5');
    expect(screen.getByText(/first post goes live right away/)).toBeInTheDocument();
    expect(screen.getByText(/last post goes live at .*\(in 10 min\)/)).toBeInTheDocument();

    fireEvent.keyDown(slider, { key: 'ArrowRight', keyCode: 39 });
    expect(slider).toHaveAttribute('aria-valuenow', '10');
    expect(screen.getByText(/last post goes live at .*\(in 20 min\)/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: /start bulk posting/i }));
    expect(onSubmit).toHaveBeenCalledWith(10);
  });

  it('queues new posts behind the posts already waiting', () => {
    const tail = Date.now() + 20 * 60_000;
    render(
      <BulkPublishModal
        open
        posts={posts}
        accounts={[account({ id: 'a1', name: 'LinkedIn hook' })]}
        queueTail={tail}
        queuedCount={4}
        submitting={false}
        onCancel={() => {}}
        onSubmit={() => {}}
      />,
    );

    expect(screen.getByText(/4 posts are already queued; these join the end of the queue/)).toBeInTheDocument();
    expect(screen.getByText(/first post goes live at .*\(in 25 min\)/)).toBeInTheDocument();
    expect(screen.getByText(/last post goes live at .*\(in 35 min\)/)).toBeInTheDocument();
  });

  it('cannot start without an enabled webhook account', () => {
    render(
      <BulkPublishModal
        open
        posts={posts}
        accounts={[
          account({ id: 'a1', name: 'Manual IG', postingMode: 'manual' }),
          account({ id: 'a2', name: 'Disabled hook', enabled: false }),
        ]}
        queueTail={null}
        queuedCount={0}
        submitting={false}
        onCancel={() => {}}
        onSubmit={() => {}}
      />,
    );

    expect(screen.getByText('No webhook social accounts')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /start bulk posting/i })).toBeDisabled();
  });
});
