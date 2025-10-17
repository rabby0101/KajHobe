
import React, { useState, useEffect } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { MapPin, Clock, DollarSign, MessageCircle, Heart, Check, X } from 'lucide-react';
import { Job } from '@/hooks/useJobs';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/integrations/supabase/client';
import { toast } from '@/hooks/use-toast';

interface JobCardProps {
  job: Job;
  onOpenChat?: (job: Job) => void;
}

const JobCard: React.FC<JobCardProps> = ({ job, onOpenChat }) => {
  const { user } = useAuth();
  const [userStatus, setUserStatus] = useState<'none' | 'applied' | 'in_contract' | 'completed'>('none');
  const [isLoading, setIsLoading] = useState(false);
  const [userType, setUserType] = useState<string | null>(null);

  // Check user's relationship to this job and get user type
  useEffect(() => {
    const checkUserStatus = async () => {
      if (!user) return;

      // Get user profile to check user type
      const { data: profile } = await supabase
        .from('profiles')
        .select('user_type')
        .eq('id', user.id)
        .single();

      if (profile) {
        setUserType(profile.user_type);
      }

      // Check if user has already applied
      const { data: proposal } = await supabase
        .from('proposals')
        .select('status')
        .eq('job_id', job.id)
        .eq('provider_id', user.id)
        .maybeSingle();

      if (proposal) {
        if (proposal.status === 'accepted') {
          setUserStatus('in_contract');
        } else {
          setUserStatus('applied');
        }
        return;
      }

      // Check if there's an active deal
      const { data: deal } = await supabase
        .from('deals')
        .select('status')
        .eq('job_id', job.id)
        .eq('provider_id', user.id)
        .maybeSingle();

      if (deal) {
        if (deal.status === 'completed') {
          setUserStatus('completed');
        } else {
          setUserStatus('in_contract');
        }
      }
    };

    checkUserStatus();
  }, [job.id, user]);

  const handleExpressInterest = async () => {
    if (!user) {
      toast({
        title: "Please sign in",
        description: "You need to be logged in to express interest",
        variant: "destructive",
      });
      return;
    }

    // Check if user is a service provider
    if (userType !== 'provider' && userType !== 'both') {
      toast({
        title: "Service Provider Required",
        description: "You need to be a service provider to express interest in jobs.",
        variant: "destructive",
      });
      return;
    }

    // Simply open the chat window instead of creating a proposal
    if (onOpenChat) {
      onOpenChat(job);
    }
  };

  const handleAcceptBudget = async () => {
    if (!user) return;

    // Check if user is a service provider
    if (userType !== 'provider' && userType !== 'both') {
      toast({
        title: "Service Provider Required",
        description: "You need to be a service provider to accept job budgets.",
        variant: "destructive",
      });
      return;
    }

    setIsLoading(true);
    try {
      // Create a proposal with accepted status
      const { data: proposal, error: proposalError } = await supabase
        .from('proposals')
        .insert({
          job_id: job.id,
          provider_id: user.id,
          amount: job.budget,
          message: "I accept your budget",
          status: 'accepted'
        })
        .select()
        .single();

      if (proposalError) throw proposalError;

      // Create a deal
      const { error: dealError } = await supabase
        .from('deals')
        .insert({
          job_id: job.id,
          client_id: job.client_id,
          provider_id: user.id,
          proposal_id: proposal.id,
          agreed_amount: job.budget,
          status: 'active'
        });

      if (dealError) throw dealError;

      // Update job status
      const { error: jobError } = await supabase
        .from('jobs')
        .update({ status: 'in_progress' })
        .eq('id', job.id);

      if (jobError) throw jobError;

      setUserStatus('in_contract');
      toast({
        title: "Budget Accepted!",
        description: "A deal has been created. You can now start working on this project.",
      });
    } catch (error: any) {
      console.error('Error accepting budget:', error);
      if (error.code === '23505') {
        toast({
          title: "Already Applied",
          description: "You have already applied for this job",
          variant: "destructive",
        });
      } else {
        toast({
          title: "Error",
          description: "Failed to accept budget. Please try again.",
          variant: "destructive",
        });
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleStartChat = () => {
    if (onOpenChat) {
      onOpenChat(job);
    }
  };

  const isOwnJob = user?.id === job.client_id;
  const isServiceProvider = userType === 'provider' || userType === 'both';

  return (
    <Card className="hover-scale cursor-pointer group border border-border hover:shadow-lg transition-all duration-300">
      <CardContent className="p-6">
        <div className="flex justify-between items-start mb-3">
          <Badge variant={job.urgent ? "destructive" : "secondary"} className="text-xs">
            {job.category}
          </Badge>
          <div className="flex gap-2">
            {job.urgent && (
              <Badge variant="destructive" className="text-xs">
                Urgent
              </Badge>
            )}
            {userStatus === 'applied' && (
              <Badge variant="outline" className="text-xs">
                Applied
              </Badge>
            )}
            {userStatus === 'in_contract' && (
              <Badge variant="default" className="text-xs bg-green-100 text-green-800">
                In Contract
              </Badge>
            )}
            {userStatus === 'completed' && (
              <Badge variant="secondary" className="text-xs">
                Completed
              </Badge>
            )}
          </div>
        </div>

        <h3 className="font-semibold text-lg text-foreground mb-3 line-clamp-2 group-hover:text-primary transition-colors">
          {job.title}
        </h3>

        <div className="space-y-2 mb-4">
          <div className="flex items-center text-sm text-muted-foreground">
            <DollarSign className="w-4 h-4 mr-2" />
            <span>৳{job.budget}</span>
          </div>
          <div className="flex items-center text-sm text-muted-foreground">
            <MapPin className="w-4 h-4 mr-2" />
            <span>{job.location}</span>
          </div>
          <div className="flex items-center text-sm text-muted-foreground">
            <Clock className="w-4 h-4 mr-2" />
            <span>{new Date(job.created_at).toLocaleDateString()}</span>
          </div>
        </div>

        {!isOwnJob && job.status === 'open' && isServiceProvider && (
          <div className="space-y-2">
            {userStatus === 'none' && (
              <div className="flex gap-2">
                <Button 
                  variant="outline"
                  size="sm"
                  onClick={handleExpressInterest}
                  disabled={isLoading}
                  className="flex-1"
                >
                  <Heart className="w-4 h-4 mr-1" />
                  Express Interest
                </Button>
                <Button 
                  size="sm"
                  onClick={handleAcceptBudget}
                  disabled={isLoading}
                  className="flex-1"
                >
                  <Check className="w-4 h-4 mr-1" />
                  Accept Budget
                </Button>
              </div>
            )}
            
            {(userStatus === 'applied' || userStatus === 'in_contract') && (
              <Button 
                onClick={handleStartChat}
                disabled={isLoading}
                className="w-full"
              >
                <MessageCircle className="w-4 h-4 mr-1" />
                Chat
              </Button>
            )}
          </div>
        )}

        {!isOwnJob && job.status === 'open' && !isServiceProvider && (
          <div className="text-center py-2">
            <p className="text-sm text-muted-foreground">
              Enable service provider mode in your profile to apply for jobs
            </p>
          </div>
        )}

        {job.status !== 'open' && (
          <div className="text-center py-2">
            <Badge variant="secondary" className="text-xs">
              {job.status === 'in_progress' ? 'In Progress' : 'Closed'}
            </Badge>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default JobCard;
