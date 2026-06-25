import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import {
  monthlyMoneyFlow,
  statusBreakdown,
  ratingTrend,
  ratingDistribution,
  nextTrustLevelTarget,
  type AnalyticsDeal,
  type AnalyticsReview,
  type MonthlyMoneyPoint,
  type StatusSlice,
  type RatingPoint,
  type RatingBar,
  type NextTrustTarget,
} from '@/lib/dashboardAnalytics';
import { deriveTrustLevel, type TrustLevel } from '@/lib/trustLevel';

export interface DashboardData {
  activeDealsCount: number;
  completedDealsCount: number;
  totalEarnings: number;
  totalSpent: number;
  averageRating: number;
  reviewCount: number;
  completedAsProvider: number;
  userType: 'provider' | 'client';
  trustLevel: TrustLevel;
  nextTrust: NextTrustTarget | null;
  moneyFlow: MonthlyMoneyPoint[];
  statusSlices: StatusSlice[];
  ratingTrend: RatingPoint[];
  ratingDistribution: RatingBar[];
}

const isDealCompleted = (d: AnalyticsDeal) =>
  d.completion_status === 'completed' || d.status === 'completed';

/** Real dashboard data + chart aggregations for the signed-in user. */
export const useDashboardData = () => {
  const { user } = useAuth();

  return useQuery({
    queryKey: ['dashboard-data', user?.id],
    queryFn: async (): Promise<DashboardData | null> => {
      if (!user?.id) return null;
      const uid = user.id;

      const [dealsRes, reviewsRes] = await Promise.all([
        supabase
          .from('deals')
          .select('provider_id, client_id, agreed_amount, status, completion_status, created_at, completed_at')
          .or(`client_id.eq.${uid},provider_id.eq.${uid}`),
        supabase.from('reviews').select('rating, created_at').eq('reviewed_id', uid),
      ]);

      if (dealsRes.error) throw dealsRes.error;
      if (reviewsRes.error) throw reviewsRes.error;

      const deals = (dealsRes.data ?? []) as AnalyticsDeal[];
      const reviews = (reviewsRes.data ?? []) as AnalyticsReview[];

      const completed = deals.filter(isDealCompleted);
      const completedAsProvider = completed.filter((d) => d.provider_id === uid).length;
      const totalEarnings = completed
        .filter((d) => d.provider_id === uid)
        .reduce((sum, d) => sum + d.agreed_amount, 0);
      const totalSpent = completed
        .filter((d) => d.client_id === uid)
        .reduce((sum, d) => sum + d.agreed_amount, 0);

      const averageRating =
        reviews.length > 0 ? reviews.reduce((s, r) => s + r.rating, 0) / reviews.length : 0;

      return {
        activeDealsCount: deals.filter((d) => !isDealCompleted(d)).length,
        completedDealsCount: completed.length,
        totalEarnings,
        totalSpent,
        averageRating,
        reviewCount: reviews.length,
        completedAsProvider,
        userType: totalEarnings > 0 ? 'provider' : 'client',
        trustLevel: deriveTrustLevel(completedAsProvider, averageRating),
        nextTrust: nextTrustLevelTarget(completedAsProvider, averageRating),
        moneyFlow: monthlyMoneyFlow(deals, uid),
        statusSlices: statusBreakdown(deals),
        ratingTrend: ratingTrend(reviews),
        ratingDistribution: ratingDistribution(reviews),
      };
    },
    enabled: !!user?.id,
    staleTime: 60000,
    refetchInterval: 60000,
    refetchOnWindowFocus: true,
  });
};
