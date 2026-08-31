import { describe, it, expect } from 'vitest';
import { parsePageParam, parseSizeParam } from './postListParams';

describe('postListParams', () => {
  it('defaults invalid page values to zero', () => {
    expect(parsePageParam(null)).toBe(0);
    expect(parsePageParam('-1')).toBe(0);
    expect(parsePageParam('abc')).toBe(0);
    expect(parsePageParam('2')).toBe(2);
  });

  it('defaults invalid size values to the fallback', () => {
    expect(parseSizeParam(null)).toBe(20);
    expect(parseSizeParam('0')).toBe(20);
    expect(parseSizeParam('101')).toBe(20);
    expect(parseSizeParam('10')).toBe(10);
  });
});
