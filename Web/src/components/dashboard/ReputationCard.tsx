import { Star } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import TrustBadge from '@/components/TrustBadge';
import { TRUST_LEVEL_META } from '@/lib/trustLevel';
import type { DashboardData } from '@/hooks/useDashboardData';

/** Trust-level + next-tier progress (parity with iOS DashboardReputationCard). */
export default function ReputationCard({ data }: { data: DashboardData }) {
  const { trustLevel, nextTrust, completedAsProvider, averageRating, reviewCount } = data;

  return (
    <Card>
      <CardHeader><CardTitle>Reputation</CardTitle></CardHeader>
      <CardContent className="space-y-4">
        <div className="flex items-center justify-between">
          <TrustBadge trustLevel={trustLevel} />
          <span className="flex items-center gap-1 text-sm text-muted-foreground">
            <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />
            {reviewCount > 0 ? `${averageRating.toFixed(1)} (${reviewCount})` : 'No ratings'}
          </span>
        </div>

        <div className="grid grid-cols-2 gap-3 text-center">
          <div className="rounded-lg bg-muted/50 p-3">
            <div className="text-xl font-bold">{completedAsProvider}</div>
            <div className="text-xs text-muted-foreground">Jobs completed</div>
          </div>
          <div className="rounded-lg bg-muted/50 p-3">
            <div className="text-xl font-bold">{reviewCount}</div>
            <div className="text-xs text-muted-foreground">Reviews</div>
          </div>
        </div>

        {nextTrust ? (
          <div className="space-y-2">
            <div className="flex items-center justify-between text-sm">
              <span className="text-muted-foreground">Next: {TRUST_LEVEL_META[nextTrust.next].label}</span>
              <span className="font-medium">{Math.round(nextTrust.progress * 100)}%</span>
            </div>
            <Progress value={nextTrust.progress * 100} />
            <p className="text-xs text-muted-foreground">
              Reach {nextTrust.jobsNeeded} completed jobs
              {nextTrust.ratingNeeded > 0 && ` and a ${nextTrust.ratingNeeded.toFixed(1)}★ average`} to level up.
            </p>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">You've reached the top trust tier. 🎉</p>
        )}
      </CardContent>
    </Card>
  );
}
