import { describe, expect, it } from 'vitest';
import { withFooter } from './footerText';

describe('withFooter', () => {
  it('appends the footer after a blank line', () => {
    expect(withFooter('Hello', 'Follow me\non X')).toBe('Hello\n\nFollow me\non X');
  });

  it('leaves the caption alone without a footer', () => {
    expect(withFooter('Hello', '')).toBe('Hello');
    expect(withFooter(undefined, undefined)).toBe('');
  });

  it('uses only the footer when the caption is blank', () => {
    expect(withFooter('  ', 'Footer')).toBe('Footer');
  });
});
