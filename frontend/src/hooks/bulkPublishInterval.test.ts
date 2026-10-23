import { describe, expect, it } from 'vitest';
import { intervalMarks, normalizeInterval } from './bulkPublishInterval';

describe('bulk publish interval', () => {
  it('snaps to 5 minute steps between 5 and 30', () => {
    expect(normalizeInterval(5)).toBe(5);
    expect(normalizeInterval(12)).toBe(10);
    expect(normalizeInterval(13)).toBe(15);
    expect(normalizeInterval(0)).toBe(5);
    expect(normalizeInterval(45)).toBe(30);
    expect(normalizeInterval(Number.NaN)).toBe(5);
  });

  it('labels every slider step', () => {
    expect(Object.keys(intervalMarks()).map(Number)).toEqual([5, 10, 15, 20, 25, 30]);
  });
});
