// Mirrors the iOS TrustLevel enum + DashboardAnalytics.trustLevel thresholds.
export type TrustLevel =
  | 'unverified'
  | 'newcomer'
  | 'established'
  | 'experienced'
  | 'expert';

export interface TrustLevelMeta {
  label: string;
  /** Tailwind classes for the badge (bg + text). */
  className: string;
  /** lucide-react icon name used by TrustBadge. */
  icon: 'HelpCircle' | 'User' | 'BadgeCheck' | 'Star' | 'Crown';
}

export const TRUST_LEVEL_META: Record<TrustLevel, TrustLevelMeta> = {
  unverified:  { label: 'Unverified',  className: 'bg-gray-100 text-gray-700',     icon: 'HelpCircle' },
  newcomer:    { label: 'Newcomer',    className: 'bg-blue-100 text-blue-700',     icon: 'User' },
  established: { label: 'Established',  className: 'bg-green-100 text-green-700',   icon: 'BadgeCheck' },
  experienced: { label: 'Experienced', className: 'bg-orange-100 text-orange-700', icon: 'Star' },
  expert:      { label: 'Expert',      className: 'bg-purple-100 text-purple-700', icon: 'Crown' },
};

/** Mirrors iOS DashboardAnalytics.trustLevel(completedJobs:avgRating:). */
export function deriveTrustLevel(completedJobs: number, avgRating: number): TrustLevel {
  if (completedJobs >= 20 && avgRating >= 4.5) return 'expert';
  if (completedJobs >= 10 && avgRating >= 4.0) return 'experienced';
  if (completedJobs >= 5 && avgRating >= 3.5) return 'established';
  if (completedJobs >= 1) return 'newcomer';
  return 'unverified';
}

/** Normalizes a server trust_level string to a known tier (fallback: unverified). */
export function normalizeTrustLevel(raw: string | null | undefined): TrustLevel {
  if (raw && raw in TRUST_LEVEL_META) return raw as TrustLevel;
  return 'unverified';
}
