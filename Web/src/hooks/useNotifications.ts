
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { useEffect } from 'react';

export interface Notification {
  id: string;
  user_id: string;
  title: string;
  message: string;
  type: string;
  read: boolean;
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
        
        console.log('Fetching notifications for user:', user.id);
        
        // Debug: First check if any notifications exist at all
        const { data: allNotifications, error: allError } = await supabase
          .from('notifications')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(10);
        
        console.log('Total notifications in database:', allNotifications?.length || 0);
        if (allNotifications && allNotifications.length > 0) {
          console.log('Sample notification:', allNotifications[0]);
          console.log('User IDs in notifications:', allNotifications.map(n => n.user_id));
        }
        
        // Now fetch for specific user
        const { data, error } = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', { ascending: false })
          .limit(50);
        
        if (error) {
          console.error('Error fetching notifications:', error);
          // Return empty array if table doesn't exist or other error
          return [];
        }
        
        console.log('Notifications fetched for user', user.id, ':', data?.length || 0, 'notifications');
        if (data && data.length > 0) {
          console.log('User notifications:', data);
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
          .eq('user_id', user.id)
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
        .eq('user_id', user.id)
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
        .eq('user_id', user.id)
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
    const channel = supabase
      .channel(`notifications_${user.id}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'notifications', filter: `user_id=eq.${user.id}` },
        () => {
          queryClient.invalidateQueries({ queryKey: ['enhanced-notifications'] });
          queryClient.invalidateQueries({ queryKey: ['pending-notifications-count'] });
        }
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
        .eq('user_id', user.id)
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
 * Accept or decline an interest-request notification. Updates the underlying
 * job_interests row (a DB trigger creates the conversation on acceptance) and
 * marks the notification read.
 */
export const useRespondToInterestNotification = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({
      notificationId,
      interestId,
      accept,
    }: {
      notificationId: string;
      interestId: string;
      accept: boolean;
    }) => {
      const { error: interestErr } = await supabase
        .from('job_interests')
        .update({ status: accept ? 'accepted' : 'rejected', actioned_at: new Date().toISOString() })
        .eq('id', interestId);
      if (interestErr) throw interestErr;

      await supabase
        .from('notifications')
        .update({ read: true, notification_state: 'read', read_at: new Date().toISOString() })
        .eq('id', notificationId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['enhanced-notifications'] });
      queryClient.invalidateQueries({ queryKey: ['notifications'] });
      queryClient.invalidateQueries({ queryKey: ['pending-notifications-count'] });
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
    },
  });
};
