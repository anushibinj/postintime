import { format, isSameDay } from 'date-fns';
import type { BulkPublishJob } from '../types';

const MINUTE_MS = 60_000;

export function formatRelativeMinutes(targetMs: number, now: number): string {
  const minutes = Math.ceil((targetMs - now) / MINUTE_MS);
  if (minutes <= 0) {
    return 'any moment now';
  }
  if (minutes < 60) {
    return `in ${minutes} min`;
  }
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0 ? `in ${hours} h` : `in ${hours} h ${rest} min`;
}

/** "3:45 PM (in 12 min)", with the date added when it is not today. */
export function formatQueuedAt(targetMs: number, now: number): string {
  const clock = isSameDay(targetMs, now) ? format(targetMs, 'h:mm a') : format(targetMs, 'MMM d, h:mm a');
  return `${clock} (${formatRelativeMinutes(targetMs, now)})`;
}

/** Latest queued slot or latest bulk post that went out; new batches start one interval after it. */
export function queueTail(jobs: BulkPublishJob[]): number | null {
  let tail: number | null = null;
  for (const job of jobs) {
    for (const item of job.items) {
      const at = item.status === 'pending' ? item.scheduledAt : item.processedAt;
      if (at) {
        const ms = Date.parse(at);
        tail = tail === null ? ms : Math.max(tail, ms);
      }
    }
  }
  return tail;
}

/** When the first post of a new batch goes live (mirrors BulkPublishService on the backend). */
export function firstSlot(tail: number | null, intervalMinutes: number, now: number): number {
  const next = tail === null ? now : tail + intervalMinutes * MINUTE_MS;
  return Math.max(now, next);
}
