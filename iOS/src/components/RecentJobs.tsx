import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { useJobs } from '@/hooks/useJobs';
import { useAuth } from '@/contexts/AuthContext';
import { toast } from '@/hooks/use-toast';
import { Link } from 'react-router-dom';
import JobCard from './JobCard';
import ChatDialog from './chat/ChatDialog';
import { useGetOrCreateConversation } from '@/hooks/useChat';
import { supabase } from '@/integrations/supabase/client';

const RecentJobs = () => {
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

  if (isLoading) {
    return (
      <section className="py-16">
        <div className="container mx-auto px-4">
          <div className="text-center">Loading recent jobs...</div>
        </div>
      </section>
    );
  }

  const recentJobs = jobs?.filter(job => job.status === 'open').slice(0, 6) || [];

  return (
    <section className="py-16">
      <div className="container mx-auto px-4">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-12">
          <div>
            <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
              Recent Job Postings
            </h2>
            <p className="text-xl text-muted-foreground">
              Latest opportunities from people in Khulna
            </p>
          </div>
          <Button asChild className="mt-4 md:mt-0">
            <Link to="/jobs">View All Jobs →</Link>
          </Button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {recentJobs.map((job) => (
            <JobCard 
              key={job.id} 
              job={job} 
              onOpenChat={handleOpenChat}
            />
          ))}
        </div>

        {recentJobs.length === 0 && (
          <div className="text-center py-12">
            <h3 className="text-xl font-semibold text-foreground mb-2">No jobs posted yet</h3>
            <p className="text-muted-foreground mb-4">Be the first to post a job and find skilled professionals!</p>
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
    </section>
  );
};

export default RecentJobs;
