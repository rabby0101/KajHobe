import React, { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Progress } from '@/components/ui/progress';
import { Separator } from '@/components/ui/separator';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import { 
  TrendingUp, 
  DollarSign, 
  CheckCircle, 
  Clock, 
  AlertCircle,
  User,
  Star,
  MessageSquare,
  BarChart3,
  RefreshCw
} from 'lucide-react';
import { useQueryClient } from '@tanstack/react-query';
import { useDashboardData } from '@/hooks/useDashboardData';
import {
  MoneyFlowChart,
  StatusDonut,
  RatingTrendChart,
  RatingDistributionChart,
} from '@/components/dashboard/AnalyticsCharts';
import ReputationCard from '@/components/dashboard/ReputationCard';
import ProviderVerificationBanner from '@/components/onboarding/ProviderVerificationBanner';
import {
  useActiveDeals,
  usePendingCompletionRequests,
  useRequestCompletion,
  useRespondToCompletion,
  CompletionError,
} from '@/hooks/useCompletionRequests';

const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Real dashboard data + chart aggregations (replaces the old stubbed stats).
  const { data: dash, isLoading: statsLoading } = useDashboardData();

  // Real active deals + pending completion requests (parity with iOS).
  const { data: activeDeals = [], isLoading: dealsLoading } = useActiveDeals();
  const { data: completionRequests = [], isLoading: requestsLoading } = usePendingCompletionRequests();
  const requestCompletion = useRequestCompletion();
  const respondToCompletion = useRespondToCompletion();

  const handleRefresh = useCallback(async () => {
    setIsRefreshing(true);
    try {
      await queryClient.invalidateQueries({ queryKey: ['dashboard-data'] });
      await queryClient.invalidateQueries({ queryKey: ['active-deals'] });
      await queryClient.invalidateQueries({ queryKey: ['completion-requests'] });
      toast({
        title: "Dashboard refreshed",
        description: "Latest data has been loaded",
      });
    } catch (error) {
      toast({
        title: "Refresh failed",
        description: "Could not refresh dashboard data",
        variant: "destructive",
      });
    } finally {
      setIsRefreshing(false);
    }
  }, [queryClient, toast]);

  // Ask the counterparty to approve completion of a deal.
  const handleRequestCompletion = (dealId: string) => {
    requestCompletion.mutate(
      { dealId },
      {
        onSuccess: () =>
          toast({ title: 'Completion requested', description: 'The other party has been asked to approve.' }),
        onError: (e) =>
          toast({
            title: 'Could not request completion',
            description: e instanceof CompletionError ? e.message : 'Please try again.',
            variant: 'destructive',
          }),
      }
    );
  };

  // Approve or reject a completion request from the counterparty.
  const handleRespondToCompletion = (requestId: string, approve: boolean) => {
    respondToCompletion.mutate(
      { requestId, approve },
      {
        onSuccess: () =>
          toast({
            title: approve ? 'Deal completed!' : 'Request rejected',
            description: approve ? 'The deal has been marked as completed.' : 'The completion request was rejected.',
          }),
        onError: (e) =>
          toast({
            title: 'Action failed',
            description: e instanceof CompletionError ? e.message : 'Please try again.',
            variant: 'destructive',
          }),
      }
    );
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return 'bg-green-500';
      case 'in_progress':
        return 'bg-blue-500';
      case 'pending_approval':
        return 'bg-yellow-500';
      default:
        return 'bg-gray-500';
    }
  };

  const getStatusText = (status: string) => {
    return status.replace('_', ' ').split(' ').map(word => 
      word.charAt(0).toUpperCase() + word.slice(1)
    ).join(' ');
  };

  if (statsLoading) {
    return (
      <div className="container mx-auto p-6">
        <div className="flex items-center justify-center h-64">
          <RefreshCw className="h-8 w-8 animate-spin" />
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <BarChart3 className="h-8 w-8 text-blue-600" />
          <h1 className="text-3xl font-bold">Dashboard</h1>
        </div>
        <Button 
          onClick={handleRefresh} 
          disabled={isRefreshing}
          size="sm"
          variant="outline"
        >
          <RefreshCw className={`h-4 w-4 mr-2 ${isRefreshing ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      <ProviderVerificationBanner variant="compact" />

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Deals</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{dash?.activeDealsCount || 0}</div>
            <p className="text-xs text-muted-foreground">
              Currently in progress
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Completed</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{dash?.completedDealsCount || 0}</div>
            <p className="text-xs text-muted-foreground">
              Successfully finished
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              {dash?.userType === 'provider' ? 'Total Earned' : 'Total Spent'}
            </CardTitle>
            <DollarSign className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              ৳{Math.round(dash?.userType === 'provider' ? dash?.totalEarnings || 0 : dash?.totalSpent || 0).toLocaleString()}
            </div>
            <p className="text-xs text-muted-foreground">
              {dash?.userType === 'provider' ? 'From completed deals' : 'On completed deals'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Rating</CardTitle>
            <Star className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {dash && dash.reviewCount > 0 ? dash.averageRating.toFixed(1) : '—'}
            </div>
            <p className="text-xs text-muted-foreground">
              {dash && dash.reviewCount > 0 ? `From ${dash.reviewCount} review${dash.reviewCount > 1 ? 's' : ''}` : 'No ratings yet'}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Main Content */}
      <Tabs defaultValue="analytics" className="space-y-4">
        <TabsList>
          <TabsTrigger value="analytics">Analytics</TabsTrigger>
          <TabsTrigger value="deals">Active Deals</TabsTrigger>
          <TabsTrigger value="requests">
            Pending Requests
            {completionRequests && completionRequests.length > 0 && (
              <Badge variant="destructive" className="ml-2">
                {completionRequests.length}
              </Badge>
            )}
          </TabsTrigger>
        </TabsList>

        <TabsContent value="analytics" className="space-y-4">
          {!dash ? (
            <div className="flex h-32 items-center justify-center">
              <RefreshCw className="h-6 w-6 animate-spin" />
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
                <div className="lg:col-span-1"><ReputationCard data={dash} /></div>
                <div className="lg:col-span-2"><MoneyFlowChart data={dash.moneyFlow} /></div>
              </div>
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                <StatusDonut data={dash.statusSlices} />
                <RatingTrendChart data={dash.ratingTrend} />
                <RatingDistributionChart data={dash.ratingDistribution} />
              </div>
            </>
          )}
        </TabsContent>

        <TabsContent value="deals" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Active Deals</CardTitle>
              <CardDescription>
                Deals currently in progress
              </CardDescription>
            </CardHeader>
            <CardContent>
              {dealsLoading ? (
                <div className="flex items-center justify-center h-32">
                  <RefreshCw className="h-6 w-6 animate-spin" />
                </div>
              ) : activeDeals && activeDeals.length > 0 ? (
                <div className="space-y-4">
                  {activeDeals.map((deal) => (
                    <div key={deal.id} className="border rounded-lg p-4">
                      <div className="flex items-center justify-between mb-2">
                        <h3 className="font-semibold">{deal.job_title}</h3>
                        <Badge variant="secondary">৳{deal.agreed_amount}</Badge>
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="text-sm text-muted-foreground">
                          with {deal.counterpartyName}
                        </span>
                        <div className="flex items-center space-x-2">
                          <div className={`w-2 h-2 rounded-full ${getStatusColor(deal.completion_status || deal.status)}`} />
                          <span className="text-sm">{getStatusText(deal.completion_status || deal.status)}</span>
                        </div>
                      </div>
                      <div className="mt-3 flex items-center gap-2">
                        {deal.iRequestedCompletion ? (
                          <Badge variant="outline">Completion requested</Badge>
                        ) : (
                          <Button
                            size="sm"
                            disabled={requestCompletion.isPending}
                            onClick={() => handleRequestCompletion(deal.id)}
                          >
                            <CheckCircle className="h-4 w-4 mr-1" />
                            Mark as Complete
                          </Button>
                        )}
                        <Button size="sm" variant="outline" asChild>
                          <a href={`/deal/${deal.id}`}>View deal</a>
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  <Clock className="h-8 w-8 mx-auto mb-2" />
                  <p>No active deals</p>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="requests" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Pending Completion Requests</CardTitle>
              <CardDescription>
                Requests awaiting your approval
              </CardDescription>
            </CardHeader>
            <CardContent>
              {requestsLoading ? (
                <div className="flex items-center justify-center h-32">
                  <RefreshCw className="h-6 w-6 animate-spin" />
                </div>
              ) : completionRequests && completionRequests.length > 0 ? (
                <div className="space-y-4">
                  {completionRequests.map((request) => (
                    <div key={request.id} className="border rounded-lg p-4">
                      <div className="flex items-center justify-between mb-2">
                        <h3 className="font-semibold">{request.job_title}</h3>
                        <Badge variant="outline">
                          {request.requester_type.charAt(0).toUpperCase() + request.requester_type.slice(1)} Request
                        </Badge>
                      </div>
                      <p className="text-sm text-muted-foreground mb-2">
                        Requested by: {request.requester_name}
                      </p>
                      {request.request_message && (
                        <p className="text-sm mb-3 p-2 bg-muted rounded">
                          {request.request_message}
                        </p>
                      )}
                      <div className="flex space-x-2">
                        <Button
                          size="sm"
                          disabled={respondToCompletion.isPending}
                          onClick={() => handleRespondToCompletion(request.id, true)}
                        >
                          <CheckCircle className="h-4 w-4 mr-1" />
                          Approve
                        </Button>
                        <Button
                          size="sm"
                          variant="destructive"
                          disabled={respondToCompletion.isPending}
                          onClick={() => handleRespondToCompletion(request.id, false)}
                        >
                          <AlertCircle className="h-4 w-4 mr-1" />
                          Reject
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  <MessageSquare className="h-8 w-8 mx-auto mb-2" />
                  <p>No pending requests</p>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
};

export default Dashboard;