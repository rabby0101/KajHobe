
import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { useMyDeals } from '@/hooks/useDeals';
import { useMarkDealCompleted } from '@/hooks/useProposalActions';
import { useAuth } from '@/contexts/AuthContext';
import { formatDistanceToNow } from 'date-fns';
import { CheckCircle, Clock, User } from 'lucide-react';

const DealManager = () => {
  const { data: deals = [], isLoading } = useMyDeals();
  const markCompleted = useMarkDealCompleted();
  const { user } = useAuth();

  const activateDeals = deals.filter(deal => deal.status === 'active');

  const handleMarkCompleted = (dealId: string) => {
    markCompleted.mutate(dealId);
  };

  if (isLoading) {
    return (
      <div className="text-center py-8">
        <p className="text-muted-foreground">Loading deals...</p>
      </div>
    );
  }

  if (activateDeals.length === 0) {
    return (
      <div className="text-center py-12">
        <CheckCircle className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-foreground mb-2">No Active Deals</h3>
        <p className="text-muted-foreground">Your active deals will appear here when proposals are accepted.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold">Active Deals</h3>
        <Badge variant="outline">{activateDeals.length} Active</Badge>
      </div>

      <div className="space-y-4">
        {activateDeals.map((deal) => {
          const isClient = user?.id === deal.client_id;
          const otherParty = isClient ? deal.profiles : null;
          
          return (
            <Card key={deal.id}>
              <CardHeader>
                <CardTitle className="flex justify-between items-start">
                  <div>
                    <h4 className="text-lg font-semibold">{deal.jobs?.title}</h4>
                    <div className="flex items-center gap-2 mt-1">
                      <User className="h-4 w-4 text-muted-foreground" />
                      <span className="text-sm text-muted-foreground">
                        {isClient ? 
                          `Provider: ${otherParty?.full_name || 'Unknown'}` : 
                          'You are the provider'
                        }
                      </span>
                    </div>
                  </div>
                  <Badge variant="default">Active</Badge>
                </CardTitle>
              </CardHeader>
              
              <CardContent className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Agreed Amount</p>
                    <p className="text-2xl font-bold text-primary">৳{deal.agreed_amount}</p>
                  </div>
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Started</p>
                    <div className="flex items-center gap-1">
                      <Clock className="h-4 w-4 text-muted-foreground" />
                      <p className="text-sm">
                        {formatDistanceToNow(new Date(deal.created_at), { addSuffix: true })}
                      </p>
                    </div>
                  </div>
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Status</p>
                    <p className="text-sm">Work in progress</p>
                  </div>
                </div>

                {deal.jobs?.description && (
                  <div>
                    <p className="text-sm font-medium text-muted-foreground mb-2">Project Description</p>
                    <p className="text-sm text-muted-foreground">{deal.jobs.description}</p>
                  </div>
                )}

                <div className="flex gap-2 pt-4">
                  <Button 
                    onClick={() => handleMarkCompleted(deal.id)}
                    disabled={markCompleted.isPending}
                    className="flex-1"
                  >
                    <CheckCircle className="h-4 w-4 mr-2" />
                    Mark as Completed
                  </Button>
                  
                  <Button variant="outline" className="flex-1">
                    Contact {isClient ? 'Provider' : 'Client'}
                  </Button>
                </div>

                <div className="text-xs text-muted-foreground pt-2">
                  <p>Deal ID: {deal.id}</p>
                  <p>Role: {isClient ? 'Client' : 'Service Provider'}</p>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
};

export default DealManager;
