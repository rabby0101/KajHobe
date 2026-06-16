import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import {
  computeCooldownStatus,
  type CooldownStatus,
  type InterestRow,
  type ShowInterestNotification,
} from '@/lib/interestCooldown';

/**
 * Cooldown status for a provider showing interest in a job. Reads job_interests
 * (a pending/accepted interest blocks) and show_interest notifications (rejected
 * count + timestamps), then computes the status via the pure helper.
 */
export const useInterestCooldown = (
  jobId: string | undefined,
  providerId: string | undefined,
  enabled = true
) =>
  useQuery({
    queryKey: ['interest-cooldown', jobId, providerId],
    queryFn: async (): Promise<CooldownStatus> => {
      if (!jobId || !providerId) {
        return computeCooldownStatus([], []);
      }

      const [interestsRes, notifsRes] = await Promise.all([
        supabase
          .from('job_interests')
          .select('status')
          .eq('job_id', jobId)
          .eq('provider_id', providerId),
        supabase
          .from('notifications')
          .select('status, created_at, actioned_at')
          .eq('job_id', jobId)
          .eq('from_user_id', providerId)
          .eq('type', 'show_interest'),
      ]);

      const interests = (interestsRes.data ?? []).map((r) => ({ status: r.status ?? '' })) as InterestRow[];
      const notifications = (notifsRes.data ?? []) as ShowInterestNotification[];
      return computeCooldownStatus(interests, notifications);
    },
    enabled: enabled && !!jobId && !!providerId,
    staleTime: 15000,
  });
