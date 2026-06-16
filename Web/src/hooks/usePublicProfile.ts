import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';

// Shape of a row in the materialized public_profiles table (iOS PublicProfile).
export interface PublicProfile {
  id: string;
  full_name: string | null;
  avatar_url: string | null;
  bio: string | null;
  location: string | null;
  website: string | null;
  is_service_provider: boolean | null;
  completed_jobs: number;
  avg_job_value: number;
  total_earnings: number;
  avg_rating: number;
  review_count: number;
  is_online: boolean | null;
  last_seen_at: string | null;
  average_response_time_minutes: number | null;
  service_categories: string[];
  trust_level: string;
  last_updated: string | null;
}

const COLUMNS =
  'id, full_name, avatar_url, bio, location, website, is_service_provider, ' +
  'completed_jobs, avg_job_value, total_earnings, avg_rating, review_count, ' +
  'is_online, last_seen_at, average_response_time_minutes, service_categories, ' +
  'trust_level, last_updated';

function normalizeRow(row: Record<string, unknown>): PublicProfile {
  const num = (v: unknown) => Number((v as number | null) ?? 0);
  const cats = row.service_categories;
  return {
    id: String(row.id),
    full_name: (row.full_name as string | null) ?? null,
    avatar_url: (row.avatar_url as string | null) ?? null,
    bio: (row.bio as string | null) ?? null,
    location: (row.location as string | null) ?? null,
    website: (row.website as string | null) ?? null,
    is_service_provider: (row.is_service_provider as boolean | null) ?? null,
    completed_jobs: num(row.completed_jobs),
    avg_job_value: num(row.avg_job_value),
    total_earnings: num(row.total_earnings),
    avg_rating: num(row.avg_rating),
    review_count: num(row.review_count),
    is_online: (row.is_online as boolean | null) ?? null,
    last_seen_at: (row.last_seen_at as string | null) ?? null,
    average_response_time_minutes: (row.average_response_time_minutes as number | null) ?? null,
    service_categories: Array.isArray(cats) ? (cats as string[]) : [],
    trust_level: (row.trust_level as string | null) ?? 'unverified',
    last_updated: (row.last_updated as string | null) ?? null,
  };
}

/** One provider's public profile, or null if none exists yet. */
export const usePublicProfile = (providerId: string | undefined) =>
  useQuery({
    queryKey: ['public-profile', providerId],
    queryFn: async (): Promise<PublicProfile | null> => {
      if (!providerId) return null;
      const { data, error } = await supabase
        .from('public_profiles')
        .select(COLUMNS)
        .eq('id', providerId)
        .maybeSingle();
      if (error) {
        console.error('Error fetching public profile:', error);
        throw error;
      }
      return data ? normalizeRow(data as Record<string, unknown>) : null;
    },
    enabled: !!providerId,
    staleTime: 60000,
  });

/** Batch summaries keyed by id, for lists/notifications. */
export const usePublicProfileSummaries = (providerIds: string[]) =>
  useQuery({
    queryKey: ['public-profile-summaries', [...providerIds].sort()],
    queryFn: async (): Promise<Record<string, PublicProfile>> => {
      if (providerIds.length === 0) return {};
      const { data, error } = await supabase
        .from('public_profiles')
        .select(COLUMNS)
        .in('id', providerIds);
      if (error) {
        console.error('Error fetching public profile summaries:', error);
        throw error;
      }
      const map: Record<string, PublicProfile> = {};
      for (const row of (data ?? []) as Record<string, unknown>[]) {
        const profile = normalizeRow(row);
        map[profile.id] = profile;
      }
      return map;
    },
    enabled: providerIds.length > 0,
    staleTime: 60000,
  });
