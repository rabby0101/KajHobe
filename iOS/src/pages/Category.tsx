import React, { useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { MapPin, Clock, DollarSign, ArrowLeft } from 'lucide-react';
import { useJobs } from '@/hooks/useJobs';
import { useAuth } from '@/contexts/AuthContext';
import { toast } from '@/hooks/use-toast';
import Header from '@/components/Header';
import JobCard from '@/components/JobCard';
import ChatDialog from '@/components/chat/ChatDialog';
import { useGetOrCreateConversation } from '@/hooks/useChat';
import { supabase } from '@/integrations/supabase/client';

// Category mapping to match the ServiceCategories component
const categoryMapping: { [key: string]: string } = {
  'home-repair-maintenance': 'Home Repair & Maintenance',
  'home-services': 'Home Services', 
  'education-tutoring': 'Education & Tutoring',
  'technology-it': 'Technology & IT',
  'automotive': 'Automotive',
  'personal-services': 'Personal Services',
  'construction-renovation': 'Construction & Renovation',
  'food-catering': 'Food & Catering',
  'mobile-electronics': 'Mobile & Electronics',
  'events-entertainment': 'Events & Entertainment'
};

const Category = () => {
  const { category } = useParams<{ category: string }>();
  const { data: jobs, isLoading } = useJobs();
  const { user } = useAuth();
  const [chatDialog, setChatDialog] = useState<{
    open: boolean;
    job: any;
    conversation: any;
  }>({ open: false, job: null, conversation: null });
  const getOrCreateConversation = useGetOrCreateConversation();

  const handleOpenChat = async (job: any) => {
    if (!user) {
      toast({
        title: "Please sign in",
        description: "You need to be logged in to chat",
        variant: "destructive",
      });
      return;
    }

    // Check if user is trying to chat on their own job
    if (job && job.client_id === user.id) {
      toast({
        title: "Cannot Chat",
        description: "You cannot chat on your own job posting",
        variant: "destructive",
      });
      return;
    }

    // Check if user is a service provider
    const { data: profile } = await supabase
      .from('profiles')
      .select('user_type')
      .eq('id', user.id)
      .single();

    if (!profile || (profile.user_type !== 'provider' && profile.user_type !== 'both')) {
      toast({
        title: "Service Provider Required",
        description: "You need to be a service provider to chat about jobs.",
        variant: "destructive",
      });
      return;
    }

    // Get or create conversation
    try {
      const conversation = await getOrCreateConversation.mutateAsync({
        jobId: job.id,
        clientId: job.client_id,
        providerId: user.id
      });

      setChatDialog({
        open: true,
        job,
        conversation
      });
    } catch (error) {
      console.error('Error creating conversation:', error);
      toast({
        title: "Error",
        description: "Failed to start chat. Please try again.",
        variant: "destructive",
      });
    }
  };

  // Use the category mapping to get the correct category name
  const categoryName = category ? categoryMapping[category] || category : '';
  
  const categoryJobs = jobs?.filter(job => 
    job.category === categoryName && job.status === 'open'
  ) || [];

  const displayCategoryName = categoryName.replace(/&/g, 'and');

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background">
        <Header />
        <div className="container mx-auto px-4 py-8">
          <div className="text-center">Loading jobs...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <Button variant="outline" asChild className="mb-4">
            <Link to="/">
              <ArrowLeft className="h-4 w-4 mr-2" />
              Back to Home
            </Link>
          </Button>
          <h1 className="text-3xl font-bold text-foreground mb-4">{displayCategoryName} Jobs</h1>
          <p className="text-xl text-muted-foreground">
            {categoryJobs.length} job{categoryJobs.length !== 1 ? 's' : ''} available
          </p>
        </div>

        {categoryJobs.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {categoryJobs.map((job) => (
              <JobCard 
                key={job.id} 
                job={job} 
                onOpenChat={handleOpenChat}
              />
            ))}
          </div>
        ) : (
          <div className="text-center py-12">
            <h3 className="text-xl font-semibold text-foreground mb-2">
              No jobs in {displayCategoryName}
            </h3>
            <p className="text-muted-foreground mb-4">
              Be the first to post a job in this category!
            </p>
            <Button asChild>
              <Link to="/post-job">Post a Job</Link>
            </Button>
          </div>
        )}

        {chatDialog.open && chatDialog.conversation && (
          <ChatDialog
            open={chatDialog.open}
            onOpenChange={(open) => setChatDialog(prev => ({ ...prev, open }))}
            conversationId={chatDialog.conversation.id}
            jobTitle={chatDialog.job?.title || ''}
            otherParticipant={{
              id: chatDialog.job?.client_id || '',
              name: chatDialog.job?.profiles?.full_name || 'Client'
            }}
          />
        )}
      </div>
    </div>
  );
};

export default Category;
