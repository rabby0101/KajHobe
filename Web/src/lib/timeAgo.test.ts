import { describe, it, expect } from 'vitest';
import { timeAgo, presenceLabel } from './timeAgo';

const NOW = Date.parse('2026-06-16T12:00:00Z');
const ago = (ms: number) => new Date(NOW - ms).toISOString();

describe('timeAgo', () => {
  it('returns empty for nullish/invalid input', () => {
    expect(timeAgo(null, NOW)).toBe('');
    expect(timeAgo('not-a-date', NOW)).toBe('');
  });
  it('says "just now" under a minute', () => {
    expect(timeAgo(ago(30_000), NOW)).toBe('just now');
  });
  it('formats minutes, hours, and days', () => {
    expect(timeAgo(ago(5 * 60_000), NOW)).toBe('5m ago');
    expect(timeAgo(ago(3 * 3600_000), NOW)).toBe('3h ago');
    expect(timeAgo(ago(2 * 86400_000), NOW)).toBe('2d ago');
  });
  it('falls back to a date beyond a week', () => {
    const result = timeAgo(ago(10 * 86400_000), NOW);
    expect(result).not.toMatch(/ago|just now/);
  });
});

describe('presenceLabel', () => {
  it('shows Online when online', () => {
    expect(presenceLabel(true, null, NOW)).toBe('Online');
  });
  it('shows last seen when offline with a timestamp', () => {
    expect(presenceLabel(false, ago(5 * 60_000), NOW)).toBe('last seen 5m ago');
  });
  it('shows Offline when offline with no timestamp', () => {
    expect(presenceLabel(false, null, NOW)).toBe('Offline');
  });
});
