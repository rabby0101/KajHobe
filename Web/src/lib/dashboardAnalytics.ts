// Pure client-side aggregation for the dashboard charts. Mirrors the iOS
// DashboardAnalytics enum so web and iOS show the same numbers. Deal volumes are
// small (a user's own deals), so aggregating locally beats a server RPC.
import { deriveTrustLevel, type TrustLevel } from '@/lib/trustLevel';

export interface AnalyticsDeal {
  provider_id: string;
  client_id: string;
  agreed_amount: number;
  status: string;
  completion_status: string | null;
  created_at: string;
  completed_at: string | null;
}

export interface AnalyticsReview {
  rating: number;
  created_at: string;
}

/** One month of money flow from the user's perspective. */
export interface MonthlyMoneyPoint {
  /** "YYYY-MM" sort key. */
  month: string;
  /** Short human label, e.g. "Jan 2026". */
  label: string;
  earned: number;
  spent: number;
}

export interface StatusSlice {
  status: string;
  count: number;
}

export interface RatingPoint {
  month: string;
  label: string;
  runningAverage: number;
}

export interface RatingBar {
  stars: number;
  count: number;
}

export interface NextTrustTarget {
  next: TrustLevel;
  jobsNeeded: number;
  ratingNeeded: number;
  /** 0..1 progress toward the next tier. */
  progress: number;
}

// --- Helpers ---------------------------------------------------------------

/** Postgres timestamps arrive with and without fractional seconds; both parse. */
export function parseDate(iso: string | null | undefined): Date | null {
  if (!iso) return null;
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
}

function monthKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function monthLabel(d: Date): string {
  return d.toLocaleDateString(undefined, { month: 'short', year: 'numeric' });
}

function isCompleted(deal: AnalyticsDeal): boolean {
  return deal.completion_status === 'completed' || deal.status === 'completed';
}

function displayStatus(raw: string): string {
  return raw
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

// --- Aggregations ----------------------------------------------------------

/**
 * Money moved per month: deals the user provided count as earnings, deals they
 * commissioned count as spending. Only completed deals count.
 */
export function monthlyMoneyFlow(deals: AnalyticsDeal[], userId: string): MonthlyMoneyPoint[] {
  const uid = userId.toLowerCase();
  const buckets = new Map<string, MonthlyMoneyPoint>();

  for (const deal of deals) {
    if (!isCompleted(deal)) continue;
    const date = parseDate(deal.completed_at ?? deal.created_at);
    if (!date) continue;
    const key = monthKey(date);
    const point = buckets.get(key) ?? { month: key, label: monthLabel(date), earned: 0, spent: 0 };
    if (deal.provider_id.toLowerCase() === uid) point.earned += deal.agreed_amount;
    else if (deal.client_id.toLowerCase() === uid) point.spent += deal.agreed_amount;
    buckets.set(key, point);
  }

  return [...buckets.values()].sort((a, b) => a.month.localeCompare(b.month));
}

/** Deals grouped by lifecycle state, for the status donut. */
export function statusBreakdown(deals: AnalyticsDeal[]): StatusSlice[] {
  const counts = new Map<string, number>();
  for (const deal of deals) {
    const raw = deal.completion_status ?? deal.status;
    const label = displayStatus(raw);
    counts.set(label, (counts.get(label) ?? 0) + 1);
  }
  return [...counts.entries()]
    .map(([status, count]) => ({ status, count }))
    .sort((a, b) => b.count - a.count);
}

/** Cumulative average rating over time (one point per month with reviews). */
export function ratingTrend(reviews: AnalyticsReview[]): RatingPoint[] {
  const dated = reviews
    .map((r) => ({ date: parseDate(r.created_at), rating: r.rating }))
    .filter((x): x is { date: Date; rating: number } => x.date !== null)
    .sort((a, b) => a.date.getTime() - b.date.getTime());
  if (dated.length === 0) return [];

  const points = new Map<string, RatingPoint>();
  let total = 0;
  dated.forEach((item, index) => {
    total += item.rating;
    const key = monthKey(item.date);
    points.set(key, { month: key, label: monthLabel(item.date), runningAverage: total / (index + 1) });
  });
  return [...points.values()].sort((a, b) => a.month.localeCompare(b.month));
}

/** Count of reviews per star value (5…1), for the distribution bars. */
export function ratingDistribution(reviews: AnalyticsReview[]): RatingBar[] {
  return [5, 4, 3, 2, 1].map((stars) => ({
    stars,
    count: reviews.filter((r) => r.rating === stars).length,
  }));
}

/**
 * What stands between the user and the next trust tier, for the progress UI.
 * Returns null at the top tier. Mirrors iOS DashboardAnalytics.nextTrustLevelTarget.
 */
export function nextTrustLevelTarget(completedJobs: number, avgRating: number): NextTrustTarget | null {
  const current = deriveTrustLevel(completedJobs, avgRating);
  let target: { next: TrustLevel; jobs: number; rating: number };
  switch (current) {
    case 'unverified': target = { next: 'newcomer', jobs: 1, rating: 0 }; break;
    case 'newcomer': target = { next: 'established', jobs: 5, rating: 3.5 }; break;
    case 'established': target = { next: 'experienced', jobs: 10, rating: 4.0 }; break;
    case 'experienced': target = { next: 'expert', jobs: 20, rating: 4.5 }; break;
    case 'expert': return null;
  }
  const jobsProgress = Math.min(completedJobs / target.jobs, 1);
  const ratingProgress = target.rating > 0 ? Math.min(avgRating / target.rating, 1) : 1;
  return {
    next: target.next,
    jobsNeeded: target.jobs,
    ratingNeeded: target.rating,
    progress: Math.min(jobsProgress, ratingProgress),
  };
}
