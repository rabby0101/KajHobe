
import React, { useState } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { MapPin, Clock, DollarSign, User } from 'lucide-react';
import { useJobs } from '@/hooks/useJobs';
import { useAuth } from '@/contexts/AuthContext';
import { toast } from '@/hooks/use-toast';
import Header from '@/components/Header';
import JobCard from '@/components/JobCard';
import ChatDialog from '@/components/chat/ChatDialog';
import { useGetOrCreateConversation } from '@/hooks/useChat';
import { supabase } from '@/integrations/supabase/client';

const BrowseJobs = () => {
  const { data: jobs, isLoading, error } = useJobs();
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

  // Filter jobs to only show active/open ones, excluding completed and closed jobs
  const activeJobs = jobs?.filter(job => 
    job.status === 'open' || job.status === 'active'
  ) || [];

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

  if (error) {
    return (
      <div className="min-h-screen bg-background">
        <Header />
        <div className="container mx-auto px-4 py-8">
          <div className="text-center text-red-500">Error loading jobs</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-foreground mb-4">Browse Jobs</h1>
          <p className="text-xl text-muted-foreground">Find opportunities to showcase your skills</p>
          <p className="text-sm text-muted-foreground mt-2">
            Showing {activeJobs.length} active job{activeJobs.length !== 1 ? 's' : ''}
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {activeJobs.map((job) => (
            <JobCard 
              key={job.id} 
              job={job} 
              onOpenChat={handleOpenChat}
            />
          ))}
        </div>

        {activeJobs.length === 0 && (
          <div className="text-center py-12">
            <h3 className="text-xl font-semibold text-foreground mb-2">No active jobs available</h3>
            <p className="text-muted-foreground">Check back later for new opportunities!</p>
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

export default BrowseJobs;
