import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

export interface Review {
  id: string;
  job_id: string;
  reviewer_id: string;
  reviewed_id: string;
  rating: number;
  comment: string | null;
  created_at: string;
}

export type ReviewErrorKind = 'alreadyReviewed' | 'jobNotCompleted' | 'unknown';

/** Typed error mirroring iOS PublicProfileNetworking.ReviewError. */
export class ReviewError extends Error {
  kind: ReviewErrorKind;
  constructor(kind: ReviewErrorKind, message: string) {
    super(message);
    this.name = 'ReviewError';
    this.kind = kind;
  }
}

export interface SubmitReviewArgs {
  jobId: string;
  reviewedId: string;
  rating: number;
  comment?: string;
}

/**
 * Submit a 1–5 star review for the counterparty of a completed job.
 * Mirrors iOS submitReview: clamps the rating, trims/null-empties the comment,
 * and maps the DB unique/RLS violations to friendly kinds.
 */
export const useSubmitReview = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  return useMutation({
    mutationFn: async ({ jobId, reviewedId, rating, comment }: SubmitReviewArgs): Promise<Review> => {
      if (!user) throw new ReviewError('unknown', 'You must be signed in to leave a review.');
      const trimmed = comment?.trim();
      const { data, error } = await supabase
        .from('reviews')
        .insert({
          job_id: jobId,
          reviewer_id: user.id,
          reviewed_id: reviewedId,
          rating: Math.min(Math.max(rating, 1), 5),
          comment: trimmed ? trimmed : null,
        })
        .select()
        .single();

      if (error) {
        if (error.code === '23505') throw new ReviewError('alreadyReviewed', "You've already reviewed this job.");
        if (error.code === '42501') throw new ReviewError('jobNotCompleted', 'You can only review a completed job.');
        console.error('Error submitting review:', error);
        throw new ReviewError('unknown', error.message);
      }
      return data as Review;
    },
    onSuccess: (_review, { reviewedId }) => {
      queryClient.invalidateQueries({ queryKey: ['public-profile', reviewedId] });
      queryClient.invalidateQueries({ queryKey: ['user-reviews', reviewedId] });
      queryClient.invalidateQueries({ queryKey: ['has-reviewed'] });
    },
  });
};

/** Whether the current user already reviewed reviewedId for this job. */
export const useHasReviewed = (jobId: string | undefined, reviewedId: string | undefined) => {
  const { user } = useAuth();
  return useQuery({
    queryKey: ['has-reviewed', jobId, reviewedId, user?.id],
    queryFn: async (): Promise<boolean> => {
      if (!user || !jobId || !reviewedId) return false;
      const { data, error } = await supabase
        .from('reviews')
        .select('id')
        .eq('job_id', jobId)
        .eq('reviewer_id', user.id)
        .eq('reviewed_id', reviewedId)
        .limit(1);
      if (error) {
        console.error('Error checking existing review:', error);
        return false;
      }
      return (data?.length ?? 0) > 0;
    },
    enabled: !!user && !!jobId && !!reviewedId,
  });
};

/** All reviews received by a user, newest first. */
export const useUserReviews = (reviewedId: string | undefined) =>
  useQuery({
    queryKey: ['user-reviews', reviewedId],
    queryFn: async (): Promise<Review[]> => {
      if (!reviewedId) return [];
      const { data, error } = await supabase
        .from('reviews')
        .select('*')
        .eq('reviewed_id', reviewedId)
        .order('created_at', { ascending: false });
      if (error) {
        console.error('Error fetching user reviews:', error);
        throw error;
      }
      return (data ?? []) as Review[];
    },
    enabled: !!reviewedId,
    staleTime: 60000,
  });
