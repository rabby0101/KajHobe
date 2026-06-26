
import React, { useState } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { MapPin, Clock, DollarSign, User, Search, RefreshCw } from 'lucide-react';
import { useJobs } from '@/hooks/useJobs';
import { useAuth } from '@/contexts/AuthContext';
import { toast } from '@/hooks/use-toast';
import Header from '@/components/Header';
import JobCard from '@/components/JobCard';
import ChatDialog from '@/components/chat/ChatDialog';
import { useGetOrCreateConversation } from '@/hooks/useChat';
import { supabase } from '@/integrations/supabase/client';
import { serviceCategories } from '@/lib/categories';
import CategoryCard from '@/components/CategoryCard';

const BrowseJobs = () => {
  const { data: jobs = [], isLoading, error, refetch } = useJobs();
  const { user } = useAuth();
  const [chatDialog, setChatDialog] = useState<{
    open: boolean;
    job: any;
    conversation: any;
  }>({ open: false, job: null, conversation: null });
  const [searchText, setSearchText] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const getOrCreateConversation = useGetOrCreateConversation();

  // Filter jobs based on search and category - matching iOS logic
  const filteredJobs = jobs.filter((job: any) => {
    let matchesSearch = true;
    let matchesCategory = true;

    // Filter by search text
    if (searchText) {
      matchesSearch = 
        job.title.toLowerCase().includes(searchText.toLowerCase()) ||
        job.description.toLowerCase().includes(searchText.toLowerCase()) ||
        job.category.toLowerCase().includes(searchText.toLowerCase());
    }

    // Filter by category
    if (selectedCategory) {
      matchesCategory = job.category.toLowerCase().includes(selectedCategory.toLowerCase());
    }

    return matchesSearch && matchesCategory && (job.status === 'open' || job.status === 'active');
  });

  // Show every category (scrollable), matching the homepage.
  const displayCategories = serviceCategories;

  // Get job count for a category
  const getJobCount = (categoryName: string) => {
    return jobs.filter((job: any) =>
      job.category.toLowerCase().includes(categoryName.toLowerCase())
    ).length;
  };

  const allJobsCount = jobs.filter((job: any) => job.status === 'open' || job.status === 'active').length;

  // Handle refresh
  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      await refetch();
      toast({
        title: "Jobs refreshed",
        description: "Latest jobs have been loaded",
      });
    } catch (error) {
      toast({
        title: "Refresh failed",
        description: "Could not refresh jobs",
        variant: "destructive",
      });
    } finally {
      setIsRefreshing(false);
    }
  };

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
      .select('user_type, is_service_provider')
      .eq('id', user.id)
      .single();

    const isProvider =
      profile?.is_service_provider === true ||
      profile?.user_type === 'provider' ||
      profile?.user_type === 'both';
    if (!isProvider) {
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
      <div className="min-h-screen bg-background">
        <Header />
        <div className="container mx-auto px-4 py-8">
          <div className="flex items-center justify-center py-12">
            <RefreshCw className="h-8 w-8 animate-spin" />
          </div>
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
    <div className="min-h-screen bg-background pb-20 md:pb-0">
      <Header />
      
      {/* Main Content - matching iOS JobsListView */}
      <div className="container mx-auto px-4 py-6 space-y-8">
        
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold">Browse Jobs</h1>
            <p className="text-muted-foreground">Find opportunities to showcase your skills</p>
          </div>
          <Button 
            onClick={handleRefresh}
            disabled={isRefreshing}
            variant="outline"
            size="sm"
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${isRefreshing ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
        </div>
        
        {/* Search Section */}
        <div className="relative">
          <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search jobs..."
            value={searchText}
            onChange={(e) => setSearchText(e.target.value)}
            className="pl-10 h-12 bg-muted/50"
          />
        </div>

        {/* Categories Section */}
        <div className="space-y-4">
          <h2 className="text-2xl font-bold">Service Categories</h2>

          <div className="flex gap-4 overflow-x-auto pb-2">
            <CategoryCard
              category={{ id: 'all', name: 'All', bengaliName: 'সব কাজ', icon: '📋', color: 'blue' }}
              jobCount={allJobsCount}
              isSelected={selectedCategory === null}
              onClick={() => setSelectedCategory(null)}
            />
            {displayCategories.map((category) => (
              <CategoryCard
                key={category.id}
                category={category}
                jobCount={getJobCount(category.name)}
                isSelected={selectedCategory === category.name}
                onClick={() => setSelectedCategory(
                  selectedCategory === category.name ? null : category.name
                )}
              />
            ))}
          </div>
        </div>

        {/* Jobs Section */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-bold">
              {searchText || selectedCategory ? 'Search Results' : 'All Jobs'}
            </h2>
            <span className="text-muted-foreground">
              {filteredJobs.length} job{filteredJobs.length !== 1 ? 's' : ''}
            </span>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredJobs.map((job) => (
              <JobCard 
                key={job.id} 
                job={job} 
                onOpenChat={handleOpenChat}
              />
            ))}
          </div>
        </div>

        {/* Loading state */}
        {isRefreshing && (
          <div className="flex items-center justify-center py-8">
            <div className="flex items-center gap-2 px-4 py-2 bg-background rounded-full shadow-lg">
              <RefreshCw className="h-4 w-4 animate-spin text-primary" />
              <span className="text-sm text-muted-foreground">Refreshing...</span>
            </div>
          </div>
        )}

        {/* Empty state */}
        {!isLoading && filteredJobs.length === 0 && (
          <div className="text-center py-12">
            <div className="space-y-4">
              <div className="text-6xl">💼</div>
              <h3 className="text-xl font-semibold">No jobs found</h3>
              <p className="text-muted-foreground">
                {searchText || selectedCategory 
                  ? 'Try adjusting your search or category filter'
                  : 'Check back later for new opportunities!'
                }
              </p>
              {(searchText || selectedCategory) && (
                <Button 
                  variant="outline" 
                  onClick={() => {
                    setSearchText('');
                    setSelectedCategory(null);
                  }}
                >
                  Clear Filters
                </Button>
              )}
            </div>
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
