import React, { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Progress } from '@/components/ui/progress';
import { Separator } from '@/components/ui/separator';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/integrations/supabase/client';
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
import { useQuery, useQueryClient } from '@tanstack/react-query';

interface DashboardStats {
  active_deals_count: number;
  completed_deals_count: number;
  total_earnings: number;
  total_spent: number;
  average_rating: number;
  user_type: 'provider' | 'client';
}

interface ActiveDeal {
  id: string;
  job_title: string;
  agreed_amount: number;
  completion_status: string;
  client_name?: string;
  provider_name?: string;
  created_at: string;
  client_completion_requested: boolean;
  provider_completion_requested: boolean;
}

interface CompletionRequest {
  id: string;
  deal_id: string;
  job_title: string;
  requester_type: 'client' | 'provider';
  requester_name: string;
  request_message: string;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
}

const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Dashboard stats query
  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ['dashboard-stats', user?.id],
    queryFn: async () => {
      try {
        if (!user?.id) return null;
        
        console.log('Fetching dashboard stats...');
        
        // Try to get basic stats from different tables
        const [dealsResult, userResult] = await Promise.allSettled([
          supabase
            .from('deals')
            .select('*')
            .or(`client_id.eq.${user.id},provider_id.eq.${user.id}`),
          supabase
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .single()
        ]);
        
        let activeDealsCount = 0;
        let completedDealsCount = 0;
        let totalEarnings = 0;
        let totalSpent = 0;
        let userType = 'client' as const;
        
        if (dealsResult.status === 'fulfilled' && dealsResult.value.data) {
          const deals = dealsResult.value.data;
          activeDealsCount = deals.filter(d => d.status === 'active').length;
          completedDealsCount = deals.filter(d => d.status === 'completed').length;
          
          deals.forEach(deal => {
            if (deal.status === 'completed') {
              if (deal.client_id === user.id) {
                totalSpent += deal.amount || 0;
              } else {
                totalEarnings += deal.amount || 0;
              }
            }
          });
        }
        
        if (userResult.status === 'fulfilled' && userResult.value.data) {
          // Determine user type based on activity
          userType = totalEarnings > 0 ? 'provider' : 'client';
        }
        
        const stats = {
          active_deals_count: activeDealsCount,
          completed_deals_count: completedDealsCount,
          total_earnings: totalEarnings,
          total_spent: totalSpent,
          average_rating: 4.5,
          user_type: userType,
        };
        
        console.log('Dashboard stats:', stats);
        return stats;
      } catch (error) {
        console.error('Dashboard stats error:', error);
        // Return default stats on error
        return {
          active_deals_count: 0,
          completed_deals_count: 0,
          total_earnings: 0,
          total_spent: 0,
          average_rating: 4.5,
          user_type: 'client' as const,
        };
      }
    },
    enabled: !!user?.id,
    retry: 1,
    staleTime: 60000, // 1 minute
    refetchInterval: 60000, // Refetch every 1 minute
    refetchOnWindowFocus: true,
  });

  // Active deals query - simplified
  const { data: activeDeals, isLoading: dealsLoading } = useQuery({
    queryKey: ['active-deals', user?.id],
    queryFn: async () => {
      try {
        // Return empty array for now
        return [] as ActiveDeal[];
      } catch (error) {
        console.error('Active deals error:', error);
        throw error;
      }
    },
    enabled: !!user?.id,
    retry: 1,
    staleTime: 60000, // 1 minute
    refetchInterval: 60000, // Refetch every 1 minute
    refetchOnWindowFocus: true,
  });

  // Completion requests query - simplified
  const { data: completionRequests, isLoading: requestsLoading } = useQuery({
    queryKey: ['completion-requests', user?.id],
    queryFn: async () => {
      try {
        // Return empty array for now
        return [] as CompletionRequest[];
      } catch (error) {
        console.error('Completion requests error:', error);
        throw error;
      }
    },
    enabled: !!user?.id,
    retry: 1,
    staleTime: 30000, // 30 seconds
    refetchInterval: 30000, // Refetch every 30 seconds
    refetchOnWindowFocus: true,
  });

  const handleRefresh = useCallback(async () => {
    setIsRefreshing(true);
    try {
      await queryClient.invalidateQueries({ queryKey: ['dashboard-stats'] });
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

  const handleCompletionRequest = async (dealId: string, approved: boolean, message?: string) => {
    try {
      const { error } = await supabase
        .rpc('respond_to_completion_request', {
          deal_id: dealId,
          approved,
          response_message: message || ''
        });

      if (error) throw error;

      toast({
        title: approved ? "Deal completed!" : "Request rejected",
        description: approved ? "The deal has been marked as completed" : "The completion request has been rejected",
      });

      // Refresh data
      await queryClient.invalidateQueries({ queryKey: ['active-deals'] });
      await queryClient.invalidateQueries({ queryKey: ['completion-requests'] });
      await queryClient.invalidateQueries({ queryKey: ['dashboard-stats'] });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to process completion request",
        variant: "destructive",
      });
    }
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

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Deals</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.active_deals_count || 0}</div>
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
            <div className="text-2xl font-bold">{stats?.completed_deals_count || 0}</div>
            <p className="text-xs text-muted-foreground">
              Successfully finished
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              {stats?.user_type === 'provider' ? 'Total Earned' : 'Total Spent'}
            </CardTitle>
            <DollarSign className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              ${Math.round(stats?.user_type === 'provider' ? stats?.total_earnings || 0 : stats?.total_spent || 0)}
            </div>
            <p className="text-xs text-muted-foreground">
              {stats?.user_type === 'provider' ? 'From completed deals' : 'On completed deals'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Rating</CardTitle>
            <Star className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.average_rating?.toFixed(1) || '4.5'}</div>
            <p className="text-xs text-muted-foreground">
              Average rating
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Main Content */}
      <Tabs defaultValue="deals" className="space-y-4">
        <TabsList>
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
                        <Badge variant="secondary">${deal.agreed_amount}</Badge>
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="text-sm text-muted-foreground">
                          with {deal.client_name || deal.provider_name}
                        </span>
                        <div className="flex items-center space-x-2">
                          <div className={`w-2 h-2 rounded-full ${getStatusColor(deal.completion_status)}`} />
                          <span className="text-sm">{getStatusText(deal.completion_status)}</span>
                        </div>
                      </div>
                      {deal.completion_status === 'in_progress' && (
                        <div className="mt-3">
                          <Button 
                            size="sm" 
                            onClick={() => handleCompletionRequest(deal.id, true)}
                          >
                            Mark as Complete
                          </Button>
                        </div>
                      )}
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
                          onClick={() => handleCompletionRequest(request.deal_id, true)}
                        >
                          <CheckCircle className="h-4 w-4 mr-1" />
                          Approve
                        </Button>
                        <Button 
                          size="sm" 
                          variant="destructive"
                          onClick={() => handleCompletionRequest(request.deal_id, false)}
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