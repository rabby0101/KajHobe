import { describe, it, expect } from 'vitest';
import {
  computeCooldownStatus,
  formatTimeRemaining,
  calculateCooldownProgress,
  COOLDOWN_MS,
  RATE_LIMIT_MS,
  type ShowInterestNotification,
} from './interestCooldown';

const NOW = Date.parse('2026-06-16T12:00:00Z');
const ago = (ms: number) => new Date(NOW - ms).toISOString();

function notif(partial: Partial<ShowInterestNotification>): ShowInterestNotification {
  return { status: 'pending', created_at: ago(10 * 60_000), actioned_at: null, ...partial };
}

describe('computeCooldownStatus', () => {
  it('allows interest with no history', () => {
    const s = computeCooldownStatus([], [], NOW);
    expect(s.canShowInterest).toBe(true);
    expect(s.attemptCount).toBe(0);
  });

  it('blocks when a pending interest already exists', () => {
    const s = computeCooldownStatus([{ status: 'pending' }], [], NOW);
    expect(s.canShowInterest).toBe(false);
    expect(s.isRateLimited).toBe(true);
  });

  it('blocks when an accepted interest exists', () => {
    const s = computeCooldownStatus([{ status: 'accepted' }], [], NOW);
    expect(s.canShowInterest).toBe(false);
  });

  it('permanently blocks after MAX_ATTEMPTS rejections', () => {
    const rejections = [
      notif({ status: 'rejected', created_at: ago(20 * 60_000), actioned_at: ago(19 * 60_000) }),
      notif({ status: 'rejected', created_at: ago(18 * 60_000), actioned_at: ago(17 * 60_000) }),
    ];
    const s = computeCooldownStatus([], rejections, NOW);
    expect(s.isPermanentlyBlocked).toBe(true);
    expect(s.canShowInterest).toBe(false);
    expect(s.attemptCount).toBe(2);
  });

  it('rate-limits a very recent attempt', () => {
    const s = computeCooldownStatus([], [notif({ status: 'pending', created_at: ago(20_000) })], NOW);
    expect(s.isRateLimited).toBe(true);
    expect(s.canShowInterest).toBe(false);
    expect(s.rateLimitRemainingMs).toBeGreaterThan(0);
    expect(s.rateLimitRemainingMs).toBeLessThanOrEqual(RATE_LIMIT_MS);
  });

  it('applies a cooldown after a recent rejection', () => {
    // Created 5 min ago (past rate limit), rejected 30s ago (within cooldown).
    const s = computeCooldownStatus(
      [],
      [notif({ status: 'rejected', created_at: ago(5 * 60_000), actioned_at: ago(30_000) })],
      NOW
    );
    expect(s.isRateLimited).toBe(false);
    expect(s.canShowInterest).toBe(false);
    expect(s.remainingCooldownMs).toBeGreaterThan(0);
    expect(s.nextAttemptTime).toBe(NOW - 30_000 + COOLDOWN_MS);
  });

  it('allows again once the cooldown has elapsed', () => {
    const s = computeCooldownStatus(
      [],
      [notif({ status: 'rejected', created_at: ago(10 * 60_000), actioned_at: ago(3 * 60_000) })],
      NOW
    );
    expect(s.canShowInterest).toBe(true);
    expect(s.attemptCount).toBe(1);
  });
});

describe('formatTimeRemaining', () => {
  it('formats minutes and seconds', () => {
    expect(formatTimeRemaining(90_000)).toBe('1m 30s');
  });
  it('formats seconds only under a minute', () => {
    expect(formatTimeRemaining(45_000)).toBe('45s');
  });
});

describe('calculateCooldownProgress', () => {
  it('is 0 at full remaining and ~1 near done', () => {
    expect(calculateCooldownProgress(COOLDOWN_MS)).toBe(0);
    expect(calculateCooldownProgress(0)).toBe(1);
  });
});
