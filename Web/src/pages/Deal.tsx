import { useParams } from 'react-router-dom';
import { Briefcase } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import Header from '@/components/Header';
import EscrowSection from '@/components/payments/EscrowSection';
import LeaveReviewButton from '@/components/LeaveReviewButton';
import { useAuth } from '@/contexts/AuthContext';
import { useDealById } from '@/hooks/useDeals';
import { formatTaka } from '@/lib/escrow';

export default function Deal() {
  const { id } = useParams<{ id: string }>();
  const { user } = useAuth();
  const { data: deal, isLoading } = useDealById(id || '');

  const isCompleted = deal?.status === 'completed';
  // Counterparty: clients review the provider; providers review the client.
  const isClient = deal?.client_id === user?.id;
  const counterpartyId = isClient ? deal?.provider_id : deal?.client_id;
  const counterpartyName = (isClient ? deal?.profiles?.full_name : undefined) ?? 'the other party';

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4 py-8">
        {isLoading ? (
          <div className="text-center text-muted-foreground">Loading deal…</div>
        ) : !deal ? (
          <div className="text-center text-muted-foreground">Deal not found.</div>
        ) : (
          <div className="mx-auto max-w-2xl space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <span className="flex items-center gap-2">
                    <Briefcase className="h-5 w-5" />
                    {deal.jobs?.title ?? 'Deal'}
                  </span>
                  <Badge variant={isCompleted ? 'secondary' : 'default'}>{deal.status}</Badge>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="flex items-baseline gap-2">
                  <span className="text-2xl font-bold">{formatTaka(deal.agreed_amount)}</span>
                  <span className="text-xs text-muted-foreground">agreed amount</span>
                </div>
                {deal.completed_at && (
                  <p className="text-sm text-muted-foreground">
                    Completed {new Date(deal.completed_at).toLocaleDateString()}
                  </p>
                )}
              </CardContent>
            </Card>

            <EscrowSection dealId={deal.id} />

            {isCompleted && counterpartyId && (
              <Card>
                <CardHeader>
                  <CardTitle>Rate this deal</CardTitle>
                </CardHeader>
                <CardContent>
                  <LeaveReviewButton
                    jobId={deal.job_id}
                    reviewedUserId={counterpartyId}
                    reviewedUserName={counterpartyName}
                    variant="default"
                    size="default"
                  />
                </CardContent>
              </Card>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
