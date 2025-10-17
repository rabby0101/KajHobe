
import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Badge } from '@/components/ui/badge';
import { BellIcon, CheckCheck, Clock } from 'lucide-react';
import { 
  useNotifications, 
  useMarkNotificationAsRead, 
  useMarkAllNotificationsAsRead,
  useMarkConversationNotificationsAsRead,
  type GroupedNotification 
} from '@/hooks/useNotifications';
import { formatDistanceToNow } from 'date-fns';
import { useNavigate } from 'react-router-dom';
import ChatDialog from '@/components/chat/ChatDialog';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/integrations/supabase/client';

const NotificationCenter = () => {
  const { user } = useAuth();
  const { data: notifications = [], isLoading, refetch } = useNotifications();
  
  // Debug: Log when notifications change
  React.useEffect(() => {
    console.log('NotificationCenter: notifications updated:', notifications.length, 'items');
    if (notifications.length > 0) {
      console.log('Latest notification:', notifications[0]);
    }
  }, [notifications]);
  const markAsRead = useMarkNotificationAsRead();
  const markAllAsRead = useMarkAllNotificationsAsRead();
  const markConversationAsRead = useMarkConversationNotificationsAsRead();
  const navigate = useNavigate();
  const [chatDialogOpen, setChatDialogOpen] = useState(false);
  const [selectedConversation, setSelectedConversation] = useState<any>(null);

  const unreadCount = notifications.filter(n => !n.read || (n.count && n.count > 0)).length;

  const handleNotificationClick = async (notification: GroupedNotification) => {
    // Handle message notifications specially - open chat dialog
    if (notification.type === 'message_received' && notification.conversation_id) {
      try {
        // Mark all notifications for this conversation as read
        markConversationAsRead.mutate(notification.conversation_id);

        // Get conversation details
        const { data: conversation } = await supabase
          .from('conversations')
          .select(`
            *,
            jobs(title),
            client_profile:profiles!conversations_client_id_fkey(id, full_name),
            provider_profile:profiles!conversations_provider_id_fkey(id, full_name)
          `)
          .eq('id', notification.conversation_id)
          .single();

        if (conversation) {
          setSelectedConversation(conversation);
          setChatDialogOpen(true);
          return;
        }
      } catch (error) {
        console.error('Error fetching conversation:', error);
      }
    } else {
      // Mark as read if not already read
      if (!notification.read) {
        markAsRead.mutate(notification.id);
      }

      // Navigate based on notification type and related data
      if (notification.related_job_id) {
        if (notification.type === 'proposal_received' || 
            notification.type === 'proposal_accepted' || 
            notification.type === 'proposal_rejected' ||
            notification.type === 'deal_created' ||
            notification.type === 'deal_completed' ||
            notification.type === 'counter_proposal') {
          navigate('/my-jobs');
        }
      }
    }
  };

  const handleMarkAllAsRead = () => {
    markAllAsRead.mutate();
  };

  // Debug function to test notification system
  const testNotification = async () => {
    if (!user) return;
    
    console.log('Creating test notification for user:', user.id);
    try {
      const { data, error } = await supabase.rpc('create_notification', {
        p_user_id: user.id,
        p_title: 'Test Notification',
        p_message: 'This is a test notification to verify the system is working',
        p_type: 'test',
        p_related_job_id: null
      });
      
      if (error) {
        console.error('Test notification error:', error);
      } else {
        console.log('Test notification created:', data);
        // Force refresh without page reload
        await refetch();
      }
    } catch (error) {
      console.error('Test notification failed:', error);
    }
  };

  // Manual refresh function
  const manualRefresh = async () => {
    console.log('Manual refresh triggered...');
    await refetch();
  };

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'proposal_received':
        return '📝';
      case 'proposal_accepted':
        return '✅';
      case 'proposal_rejected':
        return '❌';
      case 'deal_created':
        return '🤝';
      case 'deal_completed':
        return '🎉';
      case 'counter_proposal':
        return '🔄';
      case 'message_received':
        return '💬';
      default:
        return '📢';
    }
  };

  if (isLoading) {
    return (
      <Button variant="ghost" size="icon" disabled>
        <BellIcon className="h-5 w-5 fill-current" />
      </Button>
    );
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" className="relative">
          <BellIcon className="h-5 w-5 fill-current" />
          {unreadCount > 0 && (
            <Badge 
              variant="destructive" 
              className="absolute -top-1 -right-1 h-5 w-5 flex items-center justify-center text-xs p-0"
            >
              {unreadCount > 9 ? '9+' : unreadCount}
            </Badge>
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-80" align="end">
        <DropdownMenuLabel className="flex items-center justify-between">
          <span>Notifications</span>
          <div className="flex gap-1">
            {/* Temporary debug buttons - remove after debugging */}
            <Button
              variant="ghost"
              size="sm"
              onClick={testNotification}
              className="h-auto p-1 text-xs bg-blue-100"
            >
              Test
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={manualRefresh}
              className="h-auto p-1 text-xs bg-green-100"
            >
              Refresh
            </Button>
            {unreadCount > 0 && (
              <Button
                variant="ghost"
                size="sm"
                onClick={handleMarkAllAsRead}
                className="h-auto p-1 text-xs"
              >
                <CheckCheck className="h-3 w-3 mr-1" />
                Mark all read
              </Button>
            )}
          </div>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        
        {notifications.length === 0 ? (
          <div className="p-4 text-center text-sm text-muted-foreground">
            No notifications yet
          </div>
        ) : (
          <div className="max-h-96 overflow-y-auto">
            {notifications.map((notification) => (
              <DropdownMenuItem
                key={notification.id}
                className={`flex flex-col items-start p-3 cursor-pointer ${
                  (!notification.read || (notification.count && notification.count > 0)) ? 'bg-muted/50' : ''
                }`}
                onClick={() => handleNotificationClick(notification)}
              >
                <div className="flex items-start justify-between w-full">
                  <div className="flex items-start space-x-2 flex-1">
                    <span className="text-lg">{getNotificationIcon(notification.type)}</span>
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-sm flex items-center gap-2">
                        {notification.title}
                        {notification.count && notification.count > 1 && (
                          <Badge variant="secondary" className="text-xs">
                            {notification.count}
                          </Badge>
                        )}
                      </div>
                      <div className="text-xs text-muted-foreground mt-1 break-words">
                        {notification.message}
                      </div>
                      <div className="flex items-center text-xs text-muted-foreground mt-2">
                        <Clock className="h-3 w-3 mr-1" />
                        {formatDistanceToNow(new Date(notification.created_at), { addSuffix: true })}
                      </div>
                    </div>
                  </div>
                  {(!notification.read || (notification.count && notification.count > 0)) && (
                    <div className="h-2 w-2 bg-blue-500 rounded-full mt-1 flex-shrink-0" />
                  )}
                </div>
              </DropdownMenuItem>
            ))}
          </div>
        )}
      </DropdownMenuContent>
      
      {/* Chat Dialog for message notifications */}
      {selectedConversation && (
        <ChatDialog
          open={chatDialogOpen}
          onOpenChange={setChatDialogOpen}
          conversationId={selectedConversation.id}
          jobTitle={selectedConversation.jobs?.title || 'Unknown Job'}
          otherParticipant={{
            id: user?.id === selectedConversation.client_id 
              ? selectedConversation.provider_id 
              : selectedConversation.client_id,
            name: user?.id === selectedConversation.client_id
              ? selectedConversation.provider_profile?.full_name || 'Unknown Provider'
              : selectedConversation.client_profile?.full_name || 'Unknown Client'
          }}
        />
      )}
    </DropdownMenu>
  );
};

export default NotificationCenter;
