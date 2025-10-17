
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
          .eq('read', false);
        
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
        .update({ read: true })
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
        .update({ read: true })
        .eq('user_id', user.id)
        .eq('related_proposal_id', conversationId)
        .eq('read', false);
      
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
        .update({ read: true })
        .eq('user_id', user.id)
        .eq('read', false);
      
      if (error) {
        console.error('Error marking all notifications as read:', error);
        throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notifications'] });
    }
  });
};
