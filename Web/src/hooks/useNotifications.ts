
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { useEffect } from 'react';

export interface Notification {
  id: string;
  user_id: string | null;
  // Newer addressing columns used by the mobile apps. `to_user_id` is the
  // recipient; legacy rows used `user_id` instead.
  to_user_id: string | null;
  from_user_id: string | null;
  title: string;
  message: string;
  type: string;
  read: boolean;
  notification_state: string | null;
  read_at: string | null;
  status: string | null;
  job_id: string | null;
  offer_data: Record<string, unknown> | null;
  related_job_id: string | null;
  related_proposal_id: string | null;
  created_at: string;
}

export interface GroupedNotification extends Notification {
  count?: number;
  conversation_id?: string;
  latest_message_time?: string;
}

export const useNotifications = () => {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  // Disable real-time subscriptions temporarily to fix multiple subscription issues
  // Auto-refresh functionality will handle updates instead
  // useEffect(() => {
  //   if (!user) return;
  //   console.log('Real-time notifications disabled to prevent subscription issues');
  // }, [user?.id, queryClient]);

  const notificationsQuery = useQuery({
    queryKey: ['notifications'],
    queryFn: async () => {
      try {
        if (!user) return [];
        
        // Notifications are addressed via either the legacy `user_id` column or the
        // newer `to_user_id` column. Mobile (iOS/Android) writes only `to_user_id`,
        // so match BOTH — same as the apps — or web users never see show-interest /
        // deal-offer / completion notifications.
        const { data, error } = await supabase
          .from('notifications')
          .select('*')
          .or(`user_id.eq.${user.id},to_user_id.eq.${user.id}`)
          .order('created_at', { ascending: false })
          .limit(50);
        
        if (error) {
          console.error('Error fetching notifications:', error);
          // Return empty array if table doesn't exist or other error
          return [];
        }
        
        return (data || []) as GroupedNotification[];
      } catch (error) {
        console.error('Error fetching notifications:', error);
        return [];
      }
    },
    enabled: !!user,
    retry: 1,
    staleTime: 0, // No caching for debugging
    cacheTime: 0, // No cache storage
    refetchInterval: 5000, // Refetch every 5 seconds
    refetchOnWindowFocus: true,
    refetchOnMount: true,
  });

  // Get pending count
  const pendingCountQuery = useQuery({
    queryKey: ['pending-notifications-count', user?.id],
    queryFn: async () => {
      try {
        if (!user?.id) return 0;
        
        const { count, error } = await supabase
          .from('notifications')
          .select('*', { count: 'exact', head: true })
          .or(`user_id.eq.${user.id},to_user_id.eq.${user.id}`)
          .eq('notification_state', 'unread');
        
        if (error) {
          console.error('Error fetching pending notifications count:', error);
          // Return 0 if table doesn't exist or other error
          return 0;
        }
        
        return count || 0;
      } catch (error) {
        console.error('Error fetching pending notifications count:', error);
        return 0;
      }
    },
    enabled: !!user?.id,
    retry: 1,
    staleTime: 0, // No caching for debugging
    cacheTime: 0, // No cache storage
    refetchInterval: 5000, // Refetch every 5 seconds
    refetchOnWindowFocus: true,
    refetchOnMount: true,
  });

  return {
    ...notificationsQuery,
    pendingCount: pendingCountQuery.data || 0,
    refetchCount: pendingCountQuery.refetch,
  };
};

export const useMarkNotificationAsRead = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (notificationId: string) => {
      console.log('Marking notification as read:', notificationId);
      
      const { error } = await supabase
        .from('notifications')
        .update({ read: true, notification_state: 'read', read_at: new Date().toISOString() })
        .eq('id', notificationId);

      if (error) {
        console.error('Error marking notification as read:', error);
        throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notifications'] });
    }
  });
};

export const useMarkConversationNotificationsAsRead = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  return useMutation({
    mutationFn: async (conversationId: string) => {
      if (!user) throw new Error('Must be logged in');
      
      console.log('Marking conversation notifications as read:', conversationId);
      
      const { error } = await supabase
        .from('notifications')
        .update({ read: true, notification_state: 'read', read_at: new Date().toISOString() })
        .or(`user_id.eq.${user.id},to_user_id.eq.${user.id}`)
        .eq('related_proposal_id', conversationId)
        .eq('notification_state', 'unread');
      
      if (error) {
        console.error('Error marking conversation notifications as read:', error);
        throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notifications'] });
    }
  });
};

export const useMarkAllNotificationsAsRead = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  return useMutation({
    mutationFn: async () => {
      if (!user) throw new Error('Must be logged in');
      
      console.log('Marking all notifications as read...');
      
      const { error } = await supabase
        .from('notifications')
        .update({ read: true, notification_state: 'read', read_at: new Date().toISOString() })
        .or(`user_id.eq.${user.id},to_user_id.eq.${user.id}`)
        .eq('notification_state', 'unread');

      if (error) {
        console.error('Error marking all notifications as read:', error);
        throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notifications'] });
      queryClient.invalidateQueries({ queryKey: ['enhanced-notifications'] });
      queryClient.invalidateQueries({ queryKey: ['pending-notifications-count'] });
    }
  });
};

// ---------------------------------------------------------------------------
// Enhanced notifications (parity with iOS) — 3-state model (unread/read/archived),
// interactive interest accept/reject, realtime updates.
// ---------------------------------------------------------------------------

export type NotificationState = 'unread' | 'read' | 'archived';

export interface NotificationAction {
  type: string;
  label: string;
  style?: string;
}

export interface NotificationActionData {
  actions?: NotificationAction[];
  job_title?: string;
  interest_id?: string;
  provider_name?: string;
  interest_message?: string;
}

export interface EnhancedNotification {
  id: string;
  title: string | null;
  message: string | null;
  type: string | null;
  notification_state: NotificationState;
  interaction_type: string | null;
  action_data: NotificationActionData | null;
  priority: string | null;
  avatar_url: string | null;
  from_user_id: string | null;
  related_job_id: string | null;
  created_at: string;
}

/** Full enhanced-notification feed for the user, with a realtime subscription. */
export const useEnhancedNotifications = () => {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!user?.id) return;
    const invalidate = () => {
      queryClient.invalidateQueries({ queryKey: ['enhanced-notifications'] });
      queryClient.invalidateQueries({ queryKey: ['pending-notifications-count'] });
      queryClient.invalidateQueries({ queryKey: ['notifications'] });
    };
    // A postgres_changes filter only takes one condition, so subscribe to both
    // addressing columns: legacy `user_id` and mobile `to_user_id`.
    const channel = supabase
      .channel(`notifications_${user.id}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'notifications', filter: `user_id=eq.${user.id}` },
        invalidate
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'notifications', filter: `to_user_id=eq.${user.id}` },
        invalidate
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [user?.id, queryClient]);

  return useQuery({
    queryKey: ['enhanced-notifications', user?.id],
    queryFn: async (): Promise<EnhancedNotification[]> => {
      if (!user?.id) return [];
      const { data, error } = await supabase
        .from('notifications')
        .select(
          'id, title, message, type, notification_state, interaction_type, action_data, priority, avatar_url, from_user_id, related_job_id, created_at'
        )
        // Match both addressing columns (legacy user_id + mobile to_user_id).
        .or(`user_id.eq.${user.id},to_user_id.eq.${user.id}`)
        .order('created_at', { ascending: false })
        .limit(100);
      if (error) {
        console.error('Error fetching enhanced notifications:', error);
        return [];
      }
      return ((data ?? []) as unknown[]).map((row) => {
        const r = row as Record<string, unknown>;
        return {
          id: String(r.id),
          title: (r.title as string) ?? null,
          message: (r.message as string) ?? null,
          type: (r.type as string) ?? null,
          notification_state: (r.notification_state as NotificationState) ?? 'unread',
          interaction_type: (r.interaction_type as string) ?? null,
          action_data: (r.action_data as NotificationActionData) ?? null,
          priority: (r.priority as string) ?? null,
          avatar_url: (r.avatar_url as string) ?? null,
          from_user_id: (r.from_user_id as string) ?? null,
          related_job_id: (r.related_job_id as string) ?? null,
          created_at: String(r.created_at),
        };
      });
    },
    enabled: !!user?.id,
    staleTime: 10000,
    // Fallback polling in case Realtime isn't enabled on the table.
    refetchInterval: 20000,
    refetchOnWindowFocus: true,
  });
};

/** Move a notification between states (read/archived/unread). */
export const useSetNotificationState = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, state }: { id: string; state: NotificationState }) => {
      const now = new Date().toISOString();
      const patch: Record<string, unknown> = {
        notification_state: state,
        read: state !== 'unread',
      };
      if (state === 'read') patch.read_at = now;
      if (state === 'archived') patch.archived_at = now;
      const { error } = await supabase.from('notifications').update(patch).eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['enhanced-notifications'] });
      queryClient.invalidateQueries({ queryKey: ['notifications'] });
      queryClient.invalidateQueries({ queryKey: ['pending-notifications-count'] });
    },
  });
};

/**
 * Accept or decline an interest request — full parity with iOS
 * `respondToInterest` (NotificationsNetworking.swift) and Android
 * `NotificationsRepository.respondToInterest`:
 *
 * 1. Update the `job_interests` row (status + actioned_at). A DB trigger syncs
 *    the outcome onto the provider's `show_interest` notification (cooldown).
 * 2. Update the matching `interest_request` notification's status — this also
 *    arms the DB `handle_interest_acceptance` backstop.
 * 3. On accept: create the conversation client-side (existence check first),
 *    exactly like both mobile apps.
 * 4. Insert an `interest_accepted` / `interest_rejected` notification for the
 *    provider (iOS parity).
 */
export const useRespondToInterestNotification = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();
  return useMutation({
    mutationFn: async ({
      notificationId,
      interestId,
      jobId,
      providerId,
      accept,
    }: {
      /** Set when responding from a notification card; matched by job/provider otherwise. */
      notificationId?: string;
      interestId: string;
      jobId: string;
      providerId: string;
      accept: boolean;
    }): Promise<string | null> => {
      if (!user) throw new Error('Must be signed in');
      const status = accept ? 'accepted' : 'rejected';
      const now = new Date().toISOString();

      // 1. Decide the interest (fires the show_interest sync trigger).
      const { error: interestErr } = await supabase
        .from('job_interests')
        .update({ status, actioned_at: now })
        .eq('id', interestId);
      if (interestErr) throw interestErr;

      // 2. Stamp the interactive interest_request notification (status +
      //    read state). Non-fatal — the interest row is the source of truth.
      const notifPatch = {
        status,
        actioned_at: now,
        read: true,
        notification_state: 'read',
        read_at: now,
      };
      if (notificationId) {
        await supabase.from('notifications').update(notifPatch).eq('id', notificationId);
      } else {
        await supabase
          .from('notifications')
          .update(notifPatch)
          .eq('job_id', jobId)
          .eq('from_user_id', providerId)
          .eq('type', 'interest_request')
          .eq('status', 'pending');
      }

      let conversationId: string | null = null;
      if (accept) {
        // 3. Create the conversation if none exists (mirrors iOS/Android).
        const { data: existing } = await supabase
          .from('conversations')
          .select('id')
          .eq('job_id', jobId)
          .eq('client_id', user.id)
          .eq('provider_id', providerId)
          .limit(1)
          .maybeSingle();
        if (existing?.id) {
          conversationId = existing.id;
        } else {
          const { data: created, error: convErr } = await supabase
            .from('conversations')
            .insert({ job_id: jobId, client_id: user.id, provider_id: providerId, status: 'active' })
            .select('id')
            .single();
          if (convErr) throw convErr;
          conversationId = created.id;
        }
      }

      // 4. Notify the provider of the outcome (iOS parity). Non-fatal.
      const { error: responseErr } = await supabase.from('notifications').insert({
        type: accept ? 'interest_accepted' : 'interest_rejected',
        job_id: jobId,
        from_user_id: user.id,
        to_user_id: providerId,
        status: 'pending',
        message: accept
          ? 'Your interest has been accepted! You can now chat with the client.'
          : 'Thank you for your interest. The client has chosen to proceed with other providers.',
      });
      if (responseErr) console.error('Error creating interest response notification:', responseErr);

      return conversationId;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['enhanced-notifications'] });
      queryClient.invalidateQueries({ queryKey: ['notifications'] });
      queryClient.invalidateQueries({ queryKey: ['pending-notifications-count'] });
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
      queryClient.invalidateQueries({ queryKey: ['enriched-job-interests'] });
    },
  });
};
