
import React, { useState, useEffect } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Textarea } from '@/components/ui/textarea';
import { MapPin, Clock, DollarSign, MessageCircle, Heart, X } from 'lucide-react';
import { Job } from '@/hooks/useJobs';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/integrations/supabase/client';
import { toast } from '@/hooks/use-toast';
import { useQueryClient } from '@tanstack/react-query';
import { useInterestCooldown } from '@/hooks/useInterestCooldown';
import CooldownTimer from '@/components/CooldownTimer';
import MediaCarousel from '@/components/MediaCarousel';
import { parseMediaItems } from '@/lib/media';

interface JobCardProps {
  job: Job;
  onOpenChat?: (job: Job) => void;
}

const JobCard: React.FC<JobCardProps> = ({ job, onOpenChat }) => {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [userStatus, setUserStatus] = useState<'none' | 'applied' | 'in_contract' | 'completed'>('none');
  const [interestStatus, setInterestStatus] = useState<'pending' | 'accepted' | 'rejected' | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [userType, setUserType] = useState<string | null>(null);
  const [isServiceProviderFlag, setIsServiceProviderFlag] = useState(false);
  const [showInterestDialog, setShowInterestDialog] = useState(false);
  const [interestMessage, setInterestMessage] = useState('');

  // A user can apply if they are a provider. Matches iOS JobDetailView: the
  // verification flow sets profiles.is_service_provider, but legacy/self-serve
  // accounts only have user_type — accept either signal.
  const isServiceProviderUser =
    isServiceProviderFlag || userType === 'provider' || userType === 'both';
  const { data: cooldown } = useInterestCooldown(
    job.id,
    user?.id,
    isServiceProviderUser && job.client_id !== user?.id
  );
  const refreshCooldown = () =>
    queryClient.invalidateQueries({ queryKey: ['interest-cooldown', job.id, user?.id] });

  // Check user's relationship to this job and get user type
  useEffect(() => {
    const checkUserStatus = async () => {
      if (!user) return;

      // Get user profile to check user type
      const { data: profile } = await supabase
        .from('profiles')
        .select('user_type, is_service_provider')
        .eq('id', user.id)
        .single();

      if (profile) {
        setUserType(profile.user_type);
        setIsServiceProviderFlag(profile.is_service_provider === true);
      }

      // Provider check from the freshly-fetched profile (state above is not yet
      // applied within this same effect run).
      const isProviderNow =
        profile?.is_service_provider === true ||
        profile?.user_type === 'provider' ||
        profile?.user_type === 'both';

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

      // Check interest status like iOS app (gracefully handle if table doesn't exist)
      if (isProviderNow) {
        try {
          const { data: interest, error } = await supabase
            .from('job_interests')
            .select('status')
            .eq('job_id', job.id)
            .eq('provider_id', user.id)
            .single();

          if (!error && interest) {
            setInterestStatus(interest.status as 'pending' | 'accepted' | 'rejected');
          }
        } catch (error) {
          console.log('job_interests table not available, using fallback approach');
          // Continue without interest status - will default to none
        }
      }
    };

    checkUserStatus();
  }, [job.id, user]);

  const handleExpressInterest = () => {
    if (!user) {
      toast({
        title: "Please sign in",
        description: "You need to be logged in to express interest",
        variant: "destructive",
      });
      return;
    }

    // Check if user is a service provider
    if (!isServiceProviderUser) {
      toast({
        title: "Service Provider Required",
        description: "You need to be a service provider to express interest in jobs.",
        variant: "destructive",
      });
      return;
    }

    // Respect the cooldown / attempt cap before opening the dialog.
    if (cooldown && !cooldown.canShowInterest) {
      toast({
        title: cooldown.isPermanentlyBlocked ? 'Maximum attempts reached' : 'Please wait',
        description: cooldown.statusDescription,
        variant: 'destructive',
      });
      return;
    }

    // Open the interest message dialog like iOS
    setShowInterestDialog(true);
  };

  const handleSendInterest = async () => {
    if (!interestMessage.trim()) {
      toast({
        title: "Message Required",
        description: "Please write a message explaining your interest",
        variant: "destructive",
      });
      return;
    }

    setIsLoading(true);

    try {
      console.log('🔔 Showing interest in job', job.id, 'with message:', interestMessage);

      // Try to use the iOS database function first
      const { data, error } = await supabase.rpc('show_interest_in_job', {
        p_job_id: job.id,
        p_message: interestMessage
      });

      if (error) {
        // If function doesn't exist, fall back to manual creation
        if (error.message?.includes('function') && error.message?.includes('does not exist')) {
          console.log('Database function not found, using manual approach');
          await createInterestManually();
        } else {
          throw error;
        }
      } else if (data && (data as { success?: boolean }).success === false) {
        // show_interest_in_job swallows server-side exceptions into a JSON
        // payload, so a null PostgREST `error` does NOT mean success. Surface
        // the real failure instead of falsely reporting "Interest Shown".
        throw new Error((data as { error?: string }).error || 'Failed to express interest');
      } else {
        console.log('✅ Successfully showed interest using database function:', data);
        setInterestStatus('pending');
      }

      setShowInterestDialog(false);
      setInterestMessage('');

      // Force refresh notifications for ALL users (especially the job owner)
      console.log('Force refreshing notifications for all users...');
      await queryClient.invalidateQueries({ queryKey: ['notifications'] });
      await queryClient.invalidateQueries({ queryKey: ['pending-notifications-count'] });
      // Refresh this provider's cooldown so the card reflects the new attempt.
      refreshCooldown();

      // Additional aggressive refresh to ensure job owner sees notification
      setTimeout(() => {
        console.log('Secondary notification refresh...');
        queryClient.refetchQueries({ queryKey: ['notifications'] });
        queryClient.refetchQueries({ queryKey: ['pending-notifications-count'] });
      }, 2000);

      toast({
        title: "Interest Sent",
        description: "The job owner has been notified of your interest",
      });

    } catch (error) {
      console.error('Error expressing interest:', error);
      toast({
        title: "Error",
        description: "Failed to express interest. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const createInterestManually = async () => {
    // Manual fallback - try to create job_interests entry, but don't fail if table doesn't exist
    try {
      const { error: interestError } = await supabase
        .from('job_interests')
        .insert([{
          job_id: job.id,
          provider_id: user!.id,
          message: interestMessage,
          status: 'pending'
        }]);

      if (!interestError) {
        setInterestStatus('pending');
      }
    } catch (error) {
      console.log('job_interests table not available, continuing with notification only');
    }

    // Get user profile for notification
    const { data: profile } = await supabase
      .from('profiles')
      .select('full_name')
      .eq('id', user!.id)
      .single();

    const providerName = profile?.full_name || 'A service provider';

    // Create notification (this should always work)
    console.log('Creating notification for job owner:', job.client_id);
    console.log('Provider name:', providerName);
    console.log('Job title:', job.title);
    console.log('Message:', interestMessage);
    
    const { data: notificationResult, error: notificationError } = await supabase.rpc('create_notification', {
      p_user_id: job.client_id,
      p_title: 'New Interest in Your Job',
      p_message: `${providerName} has expressed interest in your job "${job.title}": ${interestMessage}`,
      p_type: 'proposal_received',
      p_related_job_id: job.id
    });

    if (notificationError) {
      console.error('Error creating notification:', notificationError);
      throw notificationError;
    }

    console.log('Notification created successfully:', notificationResult);
  };


  const handleStartChat = () => {
    if (onOpenChat) {
      onOpenChat(job);
    }
  };

  const isOwnJob = user?.id === job.client_id;
  const isServiceProvider = isServiceProviderUser;

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

        {(() => {
          const media = parseMediaItems(job.media_urls);
          return media.length > 0 ? <MediaCarousel items={media} className="mb-3" height={180} /> : null;
        })()}

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
            {interestStatus === 'rejected' && (
              <div className="space-y-2 py-2">
                <div className="text-center">
                  <Badge variant="destructive" className="text-xs">
                    Interest Rejected
                  </Badge>
                </div>
                {cooldown?.isPermanentlyBlocked ? (
                  <p className="text-center text-xs text-muted-foreground">
                    You've reached the maximum attempts for this job.
                  </p>
                ) : cooldown && !cooldown.canShowInterest && cooldown.nextAttemptTime ? (
                  <CooldownTimer until={cooldown.nextAttemptTime} onComplete={refreshCooldown} />
                ) : (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={handleExpressInterest}
                    disabled={isLoading}
                    className="w-full"
                  >
                    <Heart className="w-4 h-4 mr-1" />
                    Show Interest Again
                  </Button>
                )}
              </div>
            )}
            
            {interestStatus === 'accepted' && (
              <Button 
                onClick={handleStartChat}
                disabled={isLoading}
                className="w-full"
              >
                <MessageCircle className="w-4 h-4 mr-1" />
                Continue Chat
              </Button>
            )}
            
            {interestStatus === 'pending' && (
              <div className="text-center py-2">
                <Badge variant="secondary" className="text-xs bg-green-100 text-green-800">
                  Interest Shown
                </Badge>
              </div>
            )}
            
            {!interestStatus && userStatus === 'none' && (
              <Button 
                variant="outline"
                size="sm"
                onClick={handleExpressInterest}
                disabled={isLoading}
                className="w-full"
              >
                <Heart className="w-4 h-4 mr-1" />
                Show Interest
              </Button>
            )}
            
            {(userStatus === 'applied' || userStatus === 'in_contract') && !interestStatus && (
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

      {/* Interest Message Dialog - like iOS CustomInterestSheet */}
      <Dialog open={showInterestDialog} onOpenChange={setShowInterestDialog}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Heart className="w-5 h-5 text-blue-500" />
              Show Interest
            </DialogTitle>
          </DialogHeader>
          
          <div className="space-y-4">
            <div className="text-center">
              <p className="text-sm text-muted-foreground mb-2">
                Let the client know why you're interested in:
              </p>
              <p className="font-semibold text-sm">"{job.title}"</p>
            </div>
            
            <div className="space-y-2">
              <label className="text-sm font-medium">Your Message</label>
              <Textarea
                value={interestMessage}
                onChange={(e) => setInterestMessage(e.target.value)}
                placeholder="Example: Hi! I have 5 years of experience in web development and I'm excited to help you create a responsive website. I can start immediately and deliver within your timeline."
                className="min-h-[120px] resize-none"
                maxLength={500}
              />
              <p className="text-xs text-muted-foreground">
                {interestMessage.length}/500 characters
              </p>
            </div>
            
            <div className="space-y-2">
              <Button
                onClick={handleSendInterest}
                disabled={!interestMessage.trim() || isLoading}
                className="w-full"
              >
                {isLoading ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin mr-2" />
                    Sending...
                  </>
                ) : (
                  'Send Interest'
                )}
              </Button>
              
              <Button
                variant="outline"
                onClick={() => {
                  setShowInterestDialog(false);
                  setInterestMessage('');
                }}
                disabled={isLoading}
                className="w-full"
              >
                Cancel
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </Card>
  );
};

export default JobCard;
