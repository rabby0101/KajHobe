import { describe, it, expect } from 'vitest';
import {
  monthlyMoneyFlow,
  statusBreakdown,
  ratingTrend,
  ratingDistribution,
  nextTrustLevelTarget,
  type AnalyticsDeal,
  type AnalyticsReview,
} from './dashboardAnalytics';

const ME = 'aaaaaaaa-0000-0000-0000-000000000001';
const OTHER = 'bbbbbbbb-0000-0000-0000-000000000002';

function deal(partial: Partial<AnalyticsDeal>): AnalyticsDeal {
  return {
    provider_id: ME,
    client_id: OTHER,
    agreed_amount: 1000,
    status: 'completed',
    completion_status: 'completed',
    created_at: '2026-01-15T10:00:00Z',
    completed_at: '2026-01-20T10:00:00Z',
    ...partial,
  };
}

describe('monthlyMoneyFlow', () => {
  it('counts deals I provided as earnings', () => {
    const result = monthlyMoneyFlow([deal({ provider_id: ME, client_id: OTHER })], ME);
    expect(result).toHaveLength(1);
    expect(result[0].earned).toBe(1000);
    expect(result[0].spent).toBe(0);
  });

  it('counts deals I commissioned as spending', () => {
    const result = monthlyMoneyFlow([deal({ provider_id: OTHER, client_id: ME })], ME);
    expect(result[0].spent).toBe(1000);
    expect(result[0].earned).toBe(0);
  });

  it('ignores non-completed deals', () => {
    const result = monthlyMoneyFlow(
      [deal({ status: 'active', completion_status: null })],
      ME
    );
    expect(result).toHaveLength(0);
  });

  it('buckets by month and sorts chronologically', () => {
    const result = monthlyMoneyFlow(
      [
        deal({ completed_at: '2026-03-01T00:00:00Z', agreed_amount: 500 }),
        deal({ completed_at: '2026-01-01T00:00:00Z', agreed_amount: 200 }),
        deal({ completed_at: '2026-01-15T00:00:00Z', agreed_amount: 300 }),
      ],
      ME
    );
    expect(result.map((p) => p.month)).toEqual(['2026-01', '2026-03']);
    expect(result[0].earned).toBe(500); // 200 + 300 in January
  });

  it('is case-insensitive on user id', () => {
    const result = monthlyMoneyFlow([deal({ provider_id: ME.toUpperCase() })], ME);
    expect(result[0].earned).toBe(1000);
  });
});

describe('statusBreakdown', () => {
  it('prefers completion_status and humanizes the label', () => {
    const result = statusBreakdown([
      deal({ completion_status: 'in_progress', status: 'active' }),
      deal({ completion_status: 'in_progress', status: 'active' }),
      deal({ completion_status: 'completed', status: 'completed' }),
    ]);
    expect(result[0]).toEqual({ status: 'In Progress', count: 2 });
    expect(result.find((s) => s.status === 'Completed')?.count).toBe(1);
  });

  it('falls back to status when completion_status is null', () => {
    const result = statusBreakdown([deal({ completion_status: null, status: 'pending' })]);
    expect(result[0]).toEqual({ status: 'Pending', count: 1 });
  });
});

describe('ratingTrend', () => {
  it('computes a cumulative running average', () => {
    const reviews: AnalyticsReview[] = [
      { rating: 4, created_at: '2026-01-10T00:00:00Z' },
      { rating: 2, created_at: '2026-02-10T00:00:00Z' },
    ];
    const result = ratingTrend(reviews);
    expect(result).toHaveLength(2);
    expect(result[0].runningAverage).toBe(4); // 4/1
    expect(result[1].runningAverage).toBe(3); // (4+2)/2
  });

  it('returns empty for no reviews', () => {
    expect(ratingTrend([])).toEqual([]);
  });
});

describe('ratingDistribution', () => {
  it('counts per star, 5 down to 1', () => {
    const reviews: AnalyticsReview[] = [
      { rating: 5, created_at: '' },
      { rating: 5, created_at: '' },
      { rating: 3, created_at: '' },
    ];
    const result = ratingDistribution(reviews);
    expect(result.map((b) => b.stars)).toEqual([5, 4, 3, 2, 1]);
    expect(result[0].count).toBe(2);
    expect(result[2].count).toBe(1);
  });
});

describe('nextTrustLevelTarget', () => {
  it('points an unverified user to newcomer', () => {
    expect(nextTrustLevelTarget(0, 0)?.next).toBe('newcomer');
  });

  it('points a newcomer to established', () => {
    const t = nextTrustLevelTarget(2, 0);
    expect(t?.next).toBe('established');
    expect(t?.jobsNeeded).toBe(5);
    expect(t?.ratingNeeded).toBe(3.5);
  });

  it('returns null at expert (top tier)', () => {
    expect(nextTrustLevelTarget(30, 4.9)).toBeNull();
  });

  it('progress is the limiting factor of jobs vs rating', () => {
    // newcomer → established needs 5 jobs & 3.5★. 5 jobs (1.0) but rating 1.75/3.5 (0.5).
    const t = nextTrustLevelTarget(5, 1.75);
    expect(t?.progress).toBeCloseTo(0.5, 5);
  });
});
