import { describe, expect, it } from 'vitest';
import { firstSlot, formatQueuedAt, formatRelativeMinutes, queueTail } from './bulkPublishTime';
import type { BulkPublishItem, BulkPublishJob } from '../types';

const now = new Date(2026, 9, 23, 15, 0, 0).getTime();
const minutes = (value: number) => now + value * 60_000;

function job(items: Partial<BulkPublishItem>[]): BulkPublishJob {
  return {
    id: 'job',
    channelId: 'channel',
    intervalMinutes: 5,
    status: 'running',
    totalItems: items.length,
    processedItems: 0,
    failedItems: 0,
    createdAt: new Date(now).toISOString(),
    updatedAt: new Date(now).toISOString(),
    items: items.map((item, position) => ({
      id: `item-${position}`,
      postId: `post-${position}`,
      postTitle: `Post ${position}`,
      position,
      status: 'pending',
      scheduledAt: new Date(now).toISOString(),
      ...item,
    })),
  };
}

describe('bulk publish time', () => {
  it('describes how long until a post goes live', () => {
    expect(formatRelativeMinutes(minutes(-1), now)).toBe('any moment now');
    expect(formatRelativeMinutes(minutes(12), now)).toBe('in 12 min');
    expect(formatRelativeMinutes(minutes(11.2), now)).toBe('in 12 min');
    expect(formatRelativeMinutes(minutes(60), now)).toBe('in 1 h');
    expect(formatRelativeMinutes(minutes(95), now)).toBe('in 1 h 35 min');
  });

  it('formats the clock time, adding the date when it is not today', () => {
    expect(formatQueuedAt(minutes(45), now)).toBe('3:45 PM (in 45 min)');
    expect(formatQueuedAt(minutes(24 * 60), now)).toBe('Oct 24, 3:00 PM (in 24 h)');
  });

  it('finds the queue tail from queued slots and posts that already went out', () => {
    expect(queueTail([])).toBeNull();
    expect(queueTail([
      job([
        { status: 'published', processedAt: new Date(minutes(-3)).toISOString() },
        { status: 'pending', scheduledAt: new Date(minutes(20)).toISOString() },
        { status: 'cancelled', scheduledAt: new Date(minutes(40)).toISOString() },
      ]),
    ])).toBe(minutes(20));
  });

  it('starts a new batch one interval after the tail, or right away when idle', () => {
    expect(firstSlot(null, 10, now)).toBe(now);
    expect(firstSlot(minutes(-30), 10, now)).toBe(now);
    expect(firstSlot(minutes(-3), 10, now)).toBe(minutes(7));
    expect(firstSlot(minutes(20), 5, now)).toBe(minutes(25));
  });
});
