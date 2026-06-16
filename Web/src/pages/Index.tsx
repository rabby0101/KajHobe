import React, { useState, useEffect } from 'react';
import Header from "@/components/Header";
import ServiceCategories from "@/components/ServiceCategories";
import RecentJobs from "@/components/RecentJobs";
import HowItWorks from "@/components/HowItWorks";
import FeaturedProviders from "@/components/FeaturedProviders";
import Footer from "@/components/Footer";
import SearchSection from "@/components/SearchSection";
import JobCard from "@/components/JobCard";
import { useAuth } from "@/contexts/AuthContext";
import { useJobs } from "@/hooks/useJobs";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { serviceCategories, ServiceCategory, getColorClasses } from "@/lib/categories";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Search, RefreshCw, Plus } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { toast } from "@/hooks/use-toast";

const Index = () => {
  const { user, loading } = useAuth();
  const navigate = useNavigate();
  const { data: jobs = [], isLoading: jobsLoading, refetch } = useJobs();
  const [searchText, setSearchText] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Filter jobs based on search and category
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

    return matchesSearch && matchesCategory && job.status === 'open';
  });

  // Get recent jobs (first 6 open jobs)
  const recentJobs = jobs.filter((job: any) => job.status === 'open').slice(0, 6);

  // Show every category (scrollable), matching iOS/Android.
  const displayCategories = serviceCategories;

  // Get open-job count for a category.
  const getJobCount = (categoryName: string) => {
    return jobs.filter((job: any) =>
      job.status === 'open' && job.category.toLowerCase().includes(categoryName.toLowerCase())
    ).length;
  };

  const openJobsCount = jobs.filter((job: any) => job.status === 'open').length;

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

  // Handle chat opening (placeholder for now)
  const handleOpenChat = async (job: any) => {
    if (!user) {
      toast({
        title: "Please sign in",
        description: "You need to be logged in to chat",
        variant: "destructive",
      });
      return;
    }
    // This will be implemented later with chat functionality
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background pb-20 md:pb-0">
      <Header />
      
      {/* Main Content - matching iOS JobsListView */}
      <div className="container mx-auto px-4 py-6 space-y-8">
        
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
            {/* "All" resets the filter (parity with the iOS "All" chip). */}
            <CategoryCard
              category={{ id: 'all', name: 'All', bengaliName: 'সব কাজ', icon: '📋', color: 'blue' }}
              jobCount={openJobsCount}
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

        {/* Recent Jobs or Search Results */}
        {!searchText && !selectedCategory ? (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-2xl font-bold">Recently Posted Jobs</h2>
              <Button 
                variant="ghost" 
                size="sm"
                onClick={() => navigate('/jobs')}
                className="text-blue-600"
              >
                View All
              </Button>
            </div>
            
            <div className="flex gap-6 overflow-x-auto pb-2">
              {recentJobs.map((job: any) => (
                <div key={job.id} className="flex-none w-80">
                  <JobCard job={job} onOpenChat={handleOpenChat} />
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-2xl font-bold">Search Results</h2>
              <span className="text-muted-foreground">
                {filteredJobs.length} jobs
              </span>
            </div>
            
            <div className="grid grid-cols-1 gap-6">
              {filteredJobs.map((job: any) => (
                <JobCard key={job.id} job={job} onOpenChat={handleOpenChat} />
              ))}
            </div>
          </div>
        )}

        {/* Loading state */}
        {(jobsLoading || isRefreshing) && (
          <div className="flex items-center justify-center py-8">
            <div className="flex items-center gap-2 px-4 py-2 bg-background rounded-full shadow-lg">
              <RefreshCw className="h-4 w-4 animate-spin text-blue-600" />
              <span className="text-sm text-muted-foreground">
                {isRefreshing ? 'Refreshing...' : 'Loading...'}
              </span>
            </div>
          </div>
        )}

        {/* Empty state */}
        {!jobsLoading && jobs.length === 0 && (
          <div className="text-center py-12">
            <div className="space-y-4">
              <div className="text-6xl">💼</div>
              <h3 className="text-xl font-semibold">No Jobs Available</h3>
              <p className="text-muted-foreground">
                Be the first to post a job or check back later
              </p>
              <Button onClick={() => navigate('/post-job')} className="mt-4">
                <Plus className="h-4 w-4 mr-2" />
                Post Your First Job
              </Button>
            </div>
          </div>
        )}
      </div>

      {/* Keep other sections for non-authenticated users or desktop */}
      {!user && (
        <>
          <HowItWorks />
          <FeaturedProviders />
          <Footer />
        </>
      )}

    </div>
  );
};

// Category Card Component
interface CategoryCardProps {
  category: ServiceCategory;
  jobCount: number;
  isSelected: boolean;
  onClick: () => void;
}

const CategoryCard: React.FC<CategoryCardProps> = ({ 
  category, 
  jobCount, 
  isSelected, 
  onClick 
}) => {
  const colorClasses = getColorClasses(category.color);
  
  return (
    <button
      onClick={onClick}
      className={`
        flex-none p-4 rounded-xl border-2 transition-all duration-200 min-w-[120px] w-[120px] h-[140px]
        ${isSelected 
          ? `${colorClasses.bgLight} ${colorClasses.border}` 
          : 'bg-muted/50 border-transparent hover:bg-muted'
        }
      `}
    >
      <div className="flex flex-col items-center space-y-2 h-full">
        <div className="text-3xl">{category.icon}</div>
        <div className="text-center flex-1">
          <h3 className="font-semibold text-sm leading-tight line-clamp-2">
            {category.name}
          </h3>
          <p className="text-xs text-muted-foreground mt-1 line-clamp-1">
            {category.bengaliName}
          </p>
        </div>
        <Badge 
          variant="secondary" 
          className={`text-xs ${isSelected ? colorClasses.text : ''}`}
        >
          {jobCount} jobs
        </Badge>
      </div>
    </button>
  );
};

export default Index;
