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
import { serviceCategories, ServiceCategory, categoryLabel } from "@/lib/categories";
import CategoryCard from "@/components/CategoryCard";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { PhoneticInput } from "@/components/PhoneticInput";
import { Search, RefreshCw, Plus } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { toast } from "@/hooks/use-toast";
import { useLanguage } from "@/contexts/LanguageContext";
import WelcomeModal from "@/components/onboarding/WelcomeModal";
import ProviderVerificationBanner from "@/components/onboarding/ProviderVerificationBanner";

const Index = () => {
  const { user, loading } = useAuth();
  const { language, t } = useLanguage();
  const navigate = useNavigate();
  const { data: jobs = [], isLoading: jobsLoading, refetch } = useJobs();
  const [searchText, setSearchText] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Current user's favourite categories + location (for the home sections).
  const { data: profile } = useQuery({
    queryKey: ['home-profile', user?.id],
    queryFn: async () => {
      if (!user?.id) return null;
      const { data } = await supabase
        .from('profiles')
        .select('favorite_categories, location')
        .eq('id', user.id)
        .maybeSingle();
      return data;
    },
    enabled: !!user?.id,
  });

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

  const openJobs = jobs.filter((job: any) => job.status === 'open');

  // Recently posted: newest open jobs first (≤6) — matches iOS recentJobs.
  const recentJobs = [...openJobs]
    .sort((a: any, b: any) => (b.created_at || '').localeCompare(a.created_at || ''))
    .slice(0, 6);

  // Jobs near you: open jobs in the user's location or Khulna (≤6).
  const userLocation = profile?.location || 'Khulna';
  const jobsNearYou = openJobs
    .filter((job: any) => {
      const loc = (job.location || '').toLowerCase();
      return loc.includes(userLocation.toLowerCase()) || loc.includes('khulna');
    })
    .slice(0, 6);

  // Featured: urgent OR budget ≥ 5000, urgent first then highest budget (≤6).
  const featuredJobs = openJobs
    .filter((job: any) => job.urgent === true || (job.budget ?? 0) >= 5000)
    .sort((a: any, b: any) => {
      if (a.urgent && !b.urgent) return -1;
      if (!a.urgent && b.urgent) return 1;
      return (b.budget ?? 0) - (a.budget ?? 0);
    })
    .slice(0, 6);

  // Show every category (scrollable), matching iOS/Android.
  const displayCategories = serviceCategories;

  // Favourite categories from the profile (fallback: first 4 defaults) — iOS favoriteCategories.
  const favoriteCategoryNames: string[] =
    Array.isArray(profile?.favorite_categories) && profile!.favorite_categories!.length > 0
      ? (profile!.favorite_categories as string[])
      : serviceCategories.slice(0, 4).map((c) => c.name);
  const favoriteCategories = favoriteCategoryNames
    .map((name) => serviceCategories.find((c) => c.name === name))
    .filter((c): c is ServiceCategory => !!c);

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
      {user && <WelcomeModal />}

      {/* Main Content - matching iOS JobsListView */}
      <div className="container mx-auto px-4 py-6 space-y-8">
        {user && <ProviderVerificationBanner variant="compact" />}

        {/* Search Section */}
        <div className="relative">
          <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground z-10" />
          <PhoneticInput
            placeholder={t('home.searchPlaceholder')}
            value={searchText}
            onChange={setSearchText}
            className="pl-10 h-12 bg-muted/50"
          />
        </div>

        {/* Categories Section */}
        <div className="space-y-4">
          <h2 className="text-2xl font-bold">{t('home.serviceCategories')}</h2>

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

        {/* Home sections (matching iOS) or Search Results */}
        {!searchText && !selectedCategory ? (
          <div className="space-y-8">
            {/* Your Favourite Categories */}
            {favoriteCategories.length > 0 && (
              <div className="space-y-4">
                <div>
                  <h2 className="text-2xl font-bold">{t('home.favouriteCategories')}</h2>
                  <p className="text-sm text-muted-foreground">{t('home.favouriteCategoriesDesc')}</p>
                </div>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                  {favoriteCategories.map((category) => (
                    <button
                      key={category.id}
                      onClick={() => setSelectedCategory(category.name)}
                      className="flex flex-col items-center gap-2 rounded-xl bg-muted/50 p-4 transition-colors hover:bg-muted"
                    >
                      <span className="text-2xl">{category.icon}</span>
                      <span className="text-center text-sm font-medium leading-tight line-clamp-2">{categoryLabel(category, language)}</span>
                      <span className="text-xs text-muted-foreground">{getJobCount(category.name)} {t('common.jobsCount')}</span>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Jobs Near You */}
            {jobsNearYou.length > 0 && (
              <JobCarousel
                title={t('home.jobsNearYou')}
                subtitle={t('home.jobsNearYouDesc')}
                jobs={jobsNearYou}
                onViewAll={() => navigate('/jobs')}
                onOpenChat={handleOpenChat}
              />
            )}

            {/* Featured Jobs */}
            {featuredJobs.length > 0 && (
              <JobCarousel
                title={t('home.featuredJobs')}
                subtitle={t('home.featuredJobsDesc')}
                jobs={featuredJobs}
                onViewAll={() => navigate('/jobs')}
                onOpenChat={handleOpenChat}
              />
            )}

            {/* Recently Posted Jobs */}
            <JobCarousel
              title={t('home.recentJobs')}
              subtitle={t('home.recentJobsDesc')}
              jobs={recentJobs}
              onViewAll={() => navigate('/jobs')}
              onOpenChat={handleOpenChat}
            />
          </div>
        ) : (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-2xl font-bold">{t('home.searchResults')}</h2>
              <span className="text-muted-foreground">
                {filteredJobs.length} {t('common.jobsCount')}
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

// Horizontal job carousel used by the home sections (Jobs Near You, Featured, Recent).
interface JobCarouselProps {
  title: string;
  subtitle?: string;
  jobs: any[];
  onViewAll: () => void;
  onOpenChat: (job: any) => void;
}

const JobCarousel: React.FC<JobCarouselProps> = ({ title, subtitle, jobs, onViewAll, onOpenChat }) => {
  const { t } = useLanguage();
  return (
  <div className="space-y-4">
    <div className="flex items-end justify-between">
      <div>
        <h2 className="text-2xl font-bold">{title}</h2>
        {subtitle && <p className="text-sm text-muted-foreground">{subtitle}</p>}
      </div>
      <Button variant="ghost" size="sm" onClick={onViewAll} className="text-primary">
        {t('home.viewAll')}
      </Button>
    </div>
    <div className="flex gap-6 overflow-x-auto pb-2">
      {jobs.map((job: any) => (
        <div key={job.id} className="flex-none w-80">
          <JobCard job={job} onOpenChat={onOpenChat} />
        </div>
      ))}
    </div>
  </div>
  );
};

export default Index;
