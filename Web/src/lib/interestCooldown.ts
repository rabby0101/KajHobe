// Interest-request cooldown logic, ported from iOS InterestCooldownManager.
// Pure functions here are unit-tested; the DB fetch lives in useInterestCooldown.

/** Cooldown after a rejection before the provider may try again (ms). */
export const COOLDOWN_MS = 120_000; // 2 minutes
/** Max rejected attempts before a permanent block. */
export const MAX_ATTEMPTS = 2;
/** Minimum time between attempts (ms). */
export const RATE_LIMIT_MS = 60_000; // 1 minute

export interface InterestRow {
  status: string; // 'pending' | 'accepted' | 'rejected' | ...
}

export interface ShowInterestNotification {
  status: string | null; // 'pending' | 'rejected' | ...
  created_at: string;
  actioned_at: string | null;
}

export interface CooldownStatus {
  canShowInterest: boolean;
  attemptCount: number;
  isPermanentlyBlocked: boolean;
  isRateLimited: boolean;
  /** Remaining cooldown after a rejection, ms (null when not in cooldown). */
  remainingCooldownMs: number | null;
  /** Remaining rate-limit window, ms (null when not rate-limited or unknown). */
  rateLimitRemainingMs: number | null;
  /** Epoch ms when the next attempt becomes available (null if unknown/blocked). */
  nextAttemptTime: number | null;
  statusDescription: string;
}

function parseTs(iso: string | null | undefined): number | null {
  if (!iso) return null;
  const t = Date.parse(iso);
  return Number.isNaN(t) ? null : t;
}

/** mm m ss s / ss s formatting (parity with iOS formatTimeRemaining). */
export function formatTimeRemaining(ms: number): string {
  const total = Math.max(0, Math.ceil(ms / 1000));
  const minutes = Math.floor(total / 60);
  const seconds = total % 60;
  return minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`;
}

/** 0..1 progress through a cooldown window. */
export function calculateCooldownProgress(remainingMs: number): number {
  const progress = 1 - remainingMs / COOLDOWN_MS;
  return Math.max(0, Math.min(1, progress));
}

function status(partial: Partial<CooldownStatus>): CooldownStatus {
  const base: CooldownStatus = {
    canShowInterest: true,
    attemptCount: 0,
    isPermanentlyBlocked: false,
    isRateLimited: false,
    remainingCooldownMs: null,
    rateLimitRemainingMs: null,
    nextAttemptTime: null,
    statusDescription: '',
    ...partial,
  };
  base.statusDescription = describe(base);
  return base;
}

function describe(s: CooldownStatus): string {
  if (s.isPermanentlyBlocked) return "You've reached the maximum attempts for this job";
  if (s.isRateLimited) {
    return s.rateLimitRemainingMs != null
      ? `Please wait ${formatTimeRemaining(s.rateLimitRemainingMs)} before trying again`
      : 'You have already shown interest in this job';
  }
  if (s.remainingCooldownMs != null) {
    return `Please wait ${formatTimeRemaining(s.remainingCooldownMs)} before showing interest again`;
  }
  return 'You can show interest in this job';
}

/**
 * Pure cooldown computation. Mirrors iOS checkCooldownStatus:
 * 1. A pending/accepted interest blocks (treated as "already shown interest").
 * 2. >= MAX_ATTEMPTS rejections → permanent block.
 * 3. Last attempt within RATE_LIMIT_MS → rate limited.
 * 4. Last rejection within COOLDOWN_MS → cooldown active.
 */
export function computeCooldownStatus(
  interests: InterestRow[],
  notifications: ShowInterestNotification[],
  now: number = Date.now()
): CooldownStatus {
  // 1. Existing pending/accepted interest blocks further attempts.
  if (interests.some((i) => i.status === 'pending' || i.status === 'accepted')) {
    return status({ canShowInterest: false, attemptCount: 1, isRateLimited: true });
  }

  // Newest first.
  const sorted = [...notifications].sort(
    (a, b) => (parseTs(b.created_at) ?? 0) - (parseTs(a.created_at) ?? 0)
  );
  const rejected = sorted.filter((n) => n.status === 'rejected');
  const attemptCount = rejected.length;

  // 2. Permanent block.
  if (attemptCount >= MAX_ATTEMPTS) {
    return status({ canShowInterest: false, attemptCount, isPermanentlyBlocked: true });
  }

  // 3. Rate limit on the most recent attempt.
  const last = sorted[0];
  const lastCreated = last ? parseTs(last.created_at) : null;
  if (lastCreated != null && now - lastCreated < RATE_LIMIT_MS) {
    return status({
      canShowInterest: false,
      attemptCount,
      isRateLimited: true,
      rateLimitRemainingMs: RATE_LIMIT_MS - (now - lastCreated),
      // Absolute target so a UI countdown doesn't drift between fetch and render.
      nextAttemptTime: lastCreated + RATE_LIMIT_MS,
    });
  }

  // 4. Cooldown after the most recent rejection.
  const lastRejection = rejected[0];
  const rejectedAt = lastRejection ? parseTs(lastRejection.actioned_at) : null;
  if (rejectedAt != null && now - rejectedAt < COOLDOWN_MS) {
    const remaining = COOLDOWN_MS - (now - rejectedAt);
    return status({
      canShowInterest: false,
      attemptCount,
      remainingCooldownMs: remaining,
      nextAttemptTime: rejectedAt + COOLDOWN_MS,
    });
  }

  // No restrictions.
  return status({ canShowInterest: true, attemptCount });
}
