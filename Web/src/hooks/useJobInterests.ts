import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

/**
 * Interest requests for the current user's jobs — parity with mobile.
 *
 * iOS/Android source interactive interest cards from the `job_interests` table
 * (the source of truth), NOT from `notifications`. This hook mirrors Android's
 * `NotificationsRepository.fetchEnrichedJobInterests` batched approach:
 * pending interests → my jobs → provider profiles, in 3 queries (no N+1).
 */

/**
 * Types excluded from the business-notifications feed — must match Android
 * `NotificationsRepository.EXCLUDED_BUSINESS_TYPES` and iOS
 * `fetchBusinessNotifications`: chat lives in Messages, interest requests come
 * from `job_interests`, and the offer types are superseded by `deal_created`,
 * so a single event is never shown twice.
 */
export const EXCLUDED_BUSINESS_TYPES = new Set([
  'message_received',
  'show_interest',
  'interest_request',
  'deal_offer_received',
  'deal_offer_responded',
]);

export interface EnrichedJobInterest {
  id: string;
  job_id: string;
  provider_id: string;
  message: string | null;
  created_at: string;
  job_title: string;
  provider_name: string | null;
  provider_avatar: string | null;
}

export const useEnrichedJobInterests = () => {
  const { user } = useAuth();

  return useQuery({
    queryKey: ['enriched-job-interests', user?.id],
    queryFn: async (): Promise<EnrichedJobInterest[]> => {
      if (!user?.id) return [];

      // 1. All pending interests visible to us (RLS limits to our own jobs'
      //    interests + interests we made as provider; we intersect with our
      //    jobs below, exactly like Android).
      const { data: pending, error: interestsErr } = await supabase
        .from('job_interests')
        .select('id, job_id, provider_id, message, created_at, status')
        .eq('status', 'pending')
        .order('created_at', { ascending: false });
      if (interestsErr) {
        console.error('Error fetching job interests:', interestsErr);
        return [];
      }
      if (!pending || pending.length === 0) return [];

      // 2. Bulk fetch my jobs (client side of the interest).
      const { data: myJobs, error: jobsErr } = await supabase
        .from('jobs')
        .select('id, title')
        .eq('client_id', user.id);
      if (jobsErr) {
        console.error('Error fetching jobs for interests:', jobsErr);
        return [];
      }
      const jobsById = new Map((myJobs ?? []).map((j) => [j.id as string, j]));

      const relevant = pending.filter((i) => jobsById.has(i.job_id as string));
      if (relevant.length === 0) return [];

      // 3. Bulk fetch provider profiles.
      const providerIds = [...new Set(relevant.map((i) => i.provider_id as string))];
      const { data: providers, error: profilesErr } = await supabase
        .from('profiles')
        .select('id, full_name, avatar_url')
        .in('id', providerIds);
      if (profilesErr) {
        console.error('Error fetching provider profiles:', profilesErr);
      }
      const providersById = new Map((providers ?? []).map((p) => [p.id as string, p]));

      return relevant.map((i) => {
        const job = jobsById.get(i.job_id as string);
        const provider = providersById.get(i.provider_id as string);
        return {
          id: i.id as string,
          job_id: i.job_id as string,
          provider_id: i.provider_id as string,
          message: (i.message as string) ?? null,
          created_at: i.created_at as string,
          job_title: (job?.title as string) ?? 'your job',
          provider_name: (provider?.full_name as string) ?? null,
          provider_avatar: (provider?.avatar_url as string) ?? null,
        };
      });
    },
    enabled: !!user?.id,
    staleTime: 10000,
    refetchInterval: 20000,
    refetchOnWindowFocus: true,
  });
};
