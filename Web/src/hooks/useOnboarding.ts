import { useCallback } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

/** Tracks whether the signed-in user has been shown the post-signup welcome step. */
export const useOnboarding = () => {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: ['onboarding-welcomed', user?.id],
    queryFn: async () => {
      if (!user?.id) return null;
      const { data, error } = await supabase
        .from('profiles')
        .select('onboarding_welcomed_at' as any)
        .eq('id', user.id)
        .single();
      if (error) throw error;
      return (data as any)?.onboarding_welcomed_at as string | null;
    },
    enabled: !!user?.id,
  });

  const markWelcomed = useCallback(async () => {
    if (!user?.id) return;
    await supabase
      .from('profiles')
      .update({ onboarding_welcomed_at: new Date().toISOString() } as any)
      .eq('id', user.id);
    queryClient.setQueryData(['onboarding-welcomed', user.id], new Date().toISOString());
    queryClient.invalidateQueries({ queryKey: ['dashboard-data', user.id] });
  }, [user?.id, queryClient]);

  return {
    needsWelcome: !!user?.id && query.data === null,
    markWelcomed,
  };
};
