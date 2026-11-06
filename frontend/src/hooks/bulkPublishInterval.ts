// Mirrors BulkPublishService on the backend. 0 posts back to back; the modal still opens on 5.
export const BULK_INTERVAL_MIN = 0;
export const BULK_INTERVAL_MAX = 30;
export const BULK_INTERVAL_STEP = 5;
export const BULK_INTERVAL_DEFAULT = 5;

/** Snaps any value onto the allowed 0..30 minute grid. */
export function normalizeInterval(value: number): number {
  if (!Number.isFinite(value)) {
    return BULK_INTERVAL_DEFAULT;
  }
  const snapped = Math.round(value / BULK_INTERVAL_STEP) * BULK_INTERVAL_STEP;
  return Math.min(BULK_INTERVAL_MAX, Math.max(BULK_INTERVAL_MIN, snapped));
}

export function intervalMarks(): Record<number, string> {
  const marks: Record<number, string> = {};
  for (let value = BULK_INTERVAL_MIN; value <= BULK_INTERVAL_MAX; value += BULK_INTERVAL_STEP) {
    marks[value] = `${value}m`;
  }
  return marks;
}
