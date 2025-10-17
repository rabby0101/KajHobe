
import React from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import Header from '@/components/Header';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Button } from '@/components/ui/button';
import { Trash2 } from 'lucide-react';
import ProposalManager from '@/components/ProposalManager';
import DealManager from '@/components/DealManager';
import { useJobProposals } from '@/hooks/useProposals';
import { useMyDeals } from '@/hooks/useDeals';
import { useDeleteJob } from '@/hooks/useJobActions';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog';

const MyJobs = () => {
  const { user } = useAuth();
  const { data: deals = [] } = useMyDeals();

  const { data: myJobs, isLoading } = useQuery({
    queryKey: ['my-jobs'],
    queryFn: async () => {
      if (!user) return [];
      
      const { data, error } = await supabase
        .from('jobs')
        .select('*')
        .eq('client_id', user.id)
        .order('created_at', { ascending: false });
      
      if (error) throw error;
      return data;
    },
    enabled: !!user
  });

  if (!user) {
    return (
      <div className="min-h-screen bg-background">
        <Header />
        <div className="container mx-auto px-4 py-8">
          <div className="text-center">Please sign in to view your jobs.</div>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background">
        <Header />
        <div className="container mx-auto px-4 py-8">
          <div className="text-center">Loading your jobs...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold text-foreground mb-8">My Jobs & Deals</h1>
        
        <Tabs defaultValue="active-deals" className="w-full">
          <TabsList className="grid w-full grid-cols-3">
            <TabsTrigger value="active-deals">
              Active Deals ({deals.filter(d => d.status === 'active').length})
            </TabsTrigger>
            <TabsTrigger value="job-proposals">
              Job Proposals ({myJobs?.length || 0})
            </TabsTrigger>
            <TabsTrigger value="completed-deals">
              Completed ({deals.filter(d => d.status === 'completed').length})
            </TabsTrigger>
          </TabsList>
          
          <TabsContent value="active-deals" className="mt-6">
            <DealManager />
          </TabsContent>
          
          <TabsContent value="job-proposals" className="mt-6">
            {myJobs?.length === 0 ? (
              <div className="text-center py-12">
                <h3 className="text-xl font-semibold text-foreground mb-2">No jobs posted yet</h3>
                <p className="text-muted-foreground">Start by posting your first job!</p>
              </div>
            ) : (
              <div className="space-y-6">
                {myJobs?.map((job) => (
                  <JobWithProposals key={job.id} job={job} />
                ))}
              </div>
            )}
          </TabsContent>
          
          <TabsContent value="completed-deals" className="mt-6">
            <div className="space-y-4">
              {deals.filter(d => d.status === 'completed').map((deal) => (
                <Card key={deal.id}>
                  <CardHeader>
                    <CardTitle className="flex justify-between items-center">
                      <span>{deal.jobs?.title}</span>
                      <span className="text-green-600 text-sm">Completed</span>
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-muted-foreground">
                      Final Amount: ৳{deal.agreed_amount}
                    </p>
                    <p className="text-sm text-muted-foreground">
                      Completed: {deal.completed_at && new Date(deal.completed_at).toLocaleDateString()}
                    </p>
                  </CardContent>
                </Card>
              ))}
              {deals.filter(d => d.status === 'completed').length === 0 && (
                <div className="text-center py-8">
                  <p className="text-muted-foreground">No completed deals yet.</p>
                </div>
              )}
            </div>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
};

const JobWithProposals = ({ job }: { job: any }) => {
  const { data: proposals = [] } = useJobProposals(job.id);
  const deleteJob = useDeleteJob();

  const handleDeleteJob = () => {
    deleteJob.mutate(job.id);
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex justify-between items-start">
          <div className="flex-1">
            <div className="flex justify-between items-start">
              <div>
                <h3 className="text-xl font-semibold">{job.title}</h3>
                <p className="text-sm text-muted-foreground mt-1">
                  Budget: ৳{job.budget} • {job.location}
                </p>
              </div>
              <div className="flex items-center gap-2">
                <div className="text-right">
                  <span className="text-sm font-medium">
                    {proposals.length} proposal{proposals.length !== 1 ? 's' : ''}
                  </span>
                </div>
                {job.status === 'open' && (
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button variant="outline" size="sm" className="text-destructive hover:text-destructive">
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>Delete Job</AlertDialogTitle>
                        <AlertDialogDescription>
                          Are you sure you want to delete "{job.title}"? This action cannot be undone and will remove the job from the listings.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancel</AlertDialogCancel>
                        <AlertDialogAction onClick={handleDeleteJob} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
                          Delete Job
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                )}
              </div>
            </div>
          </div>
        </CardTitle>
      </CardHeader>
      
      <CardContent>
        <Tabs defaultValue="proposals" className="w-full">
          <TabsList>
            <TabsTrigger value="proposals">
              Proposals ({proposals.length})
            </TabsTrigger>
            <TabsTrigger value="details">Job Details</TabsTrigger>
          </TabsList>
          
          <TabsContent value="proposals" className="mt-4">
            <ProposalManager 
              proposals={proposals}
              jobTitle={job.title}
              originalBudget={job.budget}
            />
          </TabsContent>
          
          <TabsContent value="details" className="mt-4">
            <div className="space-y-4">
              <div>
                <h4 className="font-semibold">Description</h4>
                <p className="text-muted-foreground">{job.description}</p>
              </div>
              <div>
                <h4 className="font-semibold">Category</h4>
                <p className="text-muted-foreground">{job.category}</p>
              </div>
              <div>
                <h4 className="font-semibold">Status</h4>
                <p className="text-muted-foreground">{job.status}</p>
              </div>
            </div>
          </TabsContent>
        </Tabs>
      </CardContent>
    </Card>
  );
};

export default MyJobs;
