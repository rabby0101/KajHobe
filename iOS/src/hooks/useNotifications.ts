
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

  // Set up real-time subscription
  useEffect(() => {
    if (!user) return;

    console.log('Setting up notifications realtime subscription...');
    
    const channel = supabase
      .channel('notifications')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        },
        (payload) => {
          console.log('New notification received:', payload);
          queryClient.invalidateQueries({ queryKey: ['notifications'] });
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        },
        (payload) => {
          console.log('Notification updated:', payload);
          queryClient.invalidateQueries({ queryKey: ['notifications'] });
        }
      )
      .subscribe();

    return () => {
      console.log('Cleaning up notifications subscription...');
      supabase.removeChannel(channel);
    };
  }, [user, queryClient]);

  return useQuery({
    queryKey: ['notifications'],
    queryFn: async () => {
      if (!user) return [];
      
      console.log('Fetching notifications...');
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });
      
      if (error) {
        console.error('Error fetching notifications:', error);
        throw error;
      }
      
      console.log('Notifications fetched:', data);
      
      // Group message notifications by conversation
      const groupedNotifications: GroupedNotification[] = [];
      const conversationGroups: { [key: string]: Notification[] } = {};
      
      data.forEach(notification => {
        if (notification.type === 'message_received' && notification.related_proposal_id) {
          const conversationId = notification.related_proposal_id;
          if (!conversationGroups[conversationId]) {
            conversationGroups[conversationId] = [];
          }
          conversationGroups[conversationId].push(notification);
        } else {
          // Non-message notifications are added as-is
          groupedNotifications.push(notification);
        }
      });
      
      // Create grouped notifications for conversations
      Object.entries(conversationGroups).forEach(([conversationId, notifications]) => {
        const unreadCount = notifications.filter(n => !n.read).length;
        const latestNotification = notifications[0]; // Already sorted by created_at desc
        
        if (unreadCount > 0) {
          // Only show if there are unread messages
          groupedNotifications.push({
            ...latestNotification,
            count: unreadCount,
            conversation_id: conversationId,
            title: unreadCount > 1 ? `${unreadCount} New Messages` : 'New Message',
            message: unreadCount > 1 
              ? `You have ${unreadCount} unread messages in this conversation`
              : latestNotification.message,
            latest_message_time: latestNotification.created_at
          });
        } else if (notifications.some(n => n.read)) {
          // Show the latest read notification if all are read
          groupedNotifications.push({
            ...latestNotification,
            conversation_id: conversationId
          });
        }
      });
      
      // Sort by creation time
      return groupedNotifications.sort((a, b) => 
        new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );
    },
    enabled: !!user
  });
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
