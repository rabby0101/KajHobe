// Relative-time formatting for presence ("last seen") — parity with the iOS
// AppDateFormatter.presenceTimeAgo helper.

/** Compact relative time, e.g. "just now", "5m ago", "3h ago", "2d ago", or a date. */
export function timeAgo(iso: string | null | undefined, now: number = Date.now()): string {
  if (!iso) return '';
  const then = Date.parse(iso);
  if (Number.isNaN(then)) return '';

  const seconds = Math.max(0, Math.floor((now - then) / 1000));
  if (seconds < 60) return 'just now';

  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;

  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;

  return new Date(then).toLocaleDateString();
}

/** Presence label: "Online" when online, otherwise "last seen <relative>". */
export function presenceLabel(
  isOnline: boolean | null | undefined,
  lastSeenAt: string | null | undefined,
  now: number = Date.now()
): string {
  if (isOnline) return 'Online';
  const ago = timeAgo(lastSeenAt, now);
  return ago ? `last seen ${ago}` : 'Offline';
}
