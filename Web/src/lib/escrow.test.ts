import { describe, it, expect } from 'vitest';
import { isFunded, formatTaka, escrowRoleCopy, isValidBkashNumber } from './escrow';

describe('isFunded', () => {
  it('is true only for held/released/paid_out', () => {
    expect(isFunded('held')).toBe(true);
    expect(isFunded('released')).toBe(true);
    expect(isFunded('paid_out')).toBe(true);
    expect(isFunded('pending')).toBe(false);
    expect(isFunded('refunded')).toBe(false);
    expect(isFunded('failed')).toBe(false);
  });
});

describe('formatTaka', () => {
  it('rounds and adds the taka sign with grouping', () => {
    expect(formatTaka(1500)).toBe('৳1,500');
    expect(formatTaka(999.6)).toBe('৳1,000');
  });
});

describe('escrowRoleCopy', () => {
  it('differs for buyer vs provider on held', () => {
    expect(escrowRoleCopy('held', true)).toMatch(/held safely/i);
    expect(escrowRoleCopy('held', false)).toMatch(/secured in escrow/i);
  });
  it('shares copy on refunded regardless of role', () => {
    expect(escrowRoleCopy('refunded', true)).toBe(escrowRoleCopy('refunded', false));
  });
});

describe('isValidBkashNumber', () => {
  it('accepts 01 + 9 digits', () => {
    expect(isValidBkashNumber('01712345678')).toBe(true);
    expect(isValidBkashNumber(' 01712345678 ')).toBe(true);
  });
  it('rejects wrong length or prefix', () => {
    expect(isValidBkashNumber('1712345678')).toBe(false);
    expect(isValidBkashNumber('0171234567')).toBe(false);
    expect(isValidBkashNumber('02712345678')).toBe(false);
  });
});
