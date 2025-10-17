import React, { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Separator } from '@/components/ui/separator';
import { useAuth } from '@/contexts/AuthContext';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';
import { formatDistanceToNow } from 'date-fns';
import { 
  Bell, 
  CheckCircle, 
  Clock, 
  AlertCircle, 
  MessageSquare, 
  DollarSign,
  User,
  Briefcase,
  RefreshCw,
  Check,
  X
} from 'lucide-react';

interface Notification {
  id: string;
  type: 'job_interest' | 'deal_offer' | 'message' | 'deal_completion' | 'rating';
  title: string;
  message: string;
  is_read: boolean;
  created_at: string;
  job_id?: string;
  job_title?: string;
  sender_name?: string;
  sender_id?: string;
  metadata?: any;
}

const Notifications: React.FC = () => {
  const { user } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Fetch notifications - simplified for now
  const { data: notifications = [], isLoading } = useQuery({
    queryKey: ['notifications', user?.id],
    queryFn: async () => {
      try {
        if (!user?.id) return [];
        
        // Return empty array for now to prevent database errors
        return [] as Notification[];
      } catch (error) {
        console.error('Notifications error:', error);
        return [];
      }
    },
    enabled: !!user?.id,
    refetchInterval: 30000,
  });

  // Mark notification as read
  const markAsRead = async (notificationId: string) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('id', notificationId);

      if (error) throw error;

      // Update cache
      queryClient.setQueryData(['notifications', user?.id], (oldData: Notification[] | undefined) => {
        if (!oldData) return oldData;
        return oldData.map(notification => 
          notification.id === notificationId 
            ? { ...notification, is_read: true }
            : notification
        );
      });
    } catch (error) {
      console.error('Error marking notification as read:', error);
    }
  };

  // Mark all notifications as read
  const markAllAsRead = async () => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('user_id', user?.id)
        .eq('is_read', false);

      if (error) throw error;

      // Update cache
      queryClient.setQueryData(['notifications', user?.id], (oldData: Notification[] | undefined) => {
        if (!oldData) return oldData;
        return oldData.map(notification => ({ ...notification, is_read: true }));
      });

      toast({
        title: "All notifications marked as read",
        description: "Your notifications have been updated",
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to mark notifications as read",
        variant: "destructive",
      });
    }
  };

  // Refresh notifications
  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      await queryClient.invalidateQueries({ queryKey: ['notifications'] });
    } finally {
      setIsRefreshing(false);
    }
  };

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'job_interest':
        return <User className="h-4 w-4" />;
      case 'deal_offer':
        return <DollarSign className="h-4 w-4" />;
      case 'message':
        return <MessageSquare className="h-4 w-4" />;
      case 'deal_completion':
        return <CheckCircle className="h-4 w-4" />;
      case 'rating':
        return <Briefcase className="h-4 w-4" />;
      default:
        return <Bell className="h-4 w-4" />;
    }
  };

  const getNotificationColor = (type: string) => {
    switch (type) {
      case 'job_interest':
        return 'bg-blue-500';
      case 'deal_offer':
        return 'bg-green-500';
      case 'message':
        return 'bg-purple-500';
      case 'deal_completion':
        return 'bg-orange-500';
      case 'rating':
        return 'bg-yellow-500';
      default:
        return 'bg-gray-500';
    }
  };

  const unreadNotifications = notifications.filter(n => !n.is_read);
  const readNotifications = notifications.filter(n => n.is_read);

  const NotificationCard: React.FC<{ notification: Notification }> = ({ notification }) => (
    <Card 
      className={`cursor-pointer transition-all hover:shadow-md ${
        !notification.is_read ? 'bg-blue-50 border-blue-200 dark:bg-blue-950/20' : ''
      }`}
      onClick={() => !notification.is_read && markAsRead(notification.id)}
    >
      <CardContent className="p-4">
        <div className="flex items-start space-x-3">
          <div className={`p-2 rounded-full ${getNotificationColor(notification.type)} text-white`}>
            {getNotificationIcon(notification.type)}
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-sm">{notification.title}</h3>
              <div className="flex items-center space-x-2">
                {!notification.is_read && (
                  <div className="w-2 h-2 bg-blue-500 rounded-full" />
                )}
                <span className="text-xs text-muted-foreground">
                  {formatDistanceToNow(new Date(notification.created_at), { addSuffix: true })}
                </span>
              </div>
            </div>
            <p className="text-sm text-muted-foreground mt-1">
              {notification.message}
            </p>
            {notification.job_title && (
              <p className="text-xs text-blue-600 mt-1 font-medium">
                Job: {notification.job_title}
              </p>
            )}
            {notification.sender_name && (
              <p className="text-xs text-gray-600 mt-1">
                From: {notification.sender_name}
              </p>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );

  if (isLoading) {
    return (
      <div className="container mx-auto p-6">
        <div className="flex items-center justify-center h-64">
          <RefreshCw className="h-8 w-8 animate-spin" />
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <Bell className="h-8 w-8 text-blue-600" />
          <h1 className="text-3xl font-bold">Notifications</h1>
          {unreadNotifications.length > 0 && (
            <Badge variant="destructive">
              {unreadNotifications.length}
            </Badge>
          )}
        </div>
        <div className="flex space-x-2">
          <Button 
            onClick={handleRefresh} 
            disabled={isRefreshing}
            size="sm"
            variant="outline"
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${isRefreshing ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
          {unreadNotifications.length > 0 && (
            <Button 
              onClick={markAllAsRead}
              size="sm"
            >
              <Check className="h-4 w-4 mr-2" />
              Mark All Read
            </Button>
          )}
        </div>
      </div>

      {/* Notifications */}
      <Tabs defaultValue="unread" className="space-y-4">
        <TabsList>
          <TabsTrigger value="unread">
            Unread
            {unreadNotifications.length > 0 && (
              <Badge variant="destructive" className="ml-2">
                {unreadNotifications.length}
              </Badge>
            )}
          </TabsTrigger>
          <TabsTrigger value="all">All Notifications</TabsTrigger>
        </TabsList>

        <TabsContent value="unread" className="space-y-4">
          {unreadNotifications.length > 0 ? (
            unreadNotifications.map((notification) => (
              <NotificationCard key={notification.id} notification={notification} />
            ))
          ) : (
            <Card>
              <CardContent className="p-8">
                <div className="text-center">
                  <CheckCircle className="h-12 w-12 text-green-500 mx-auto mb-4" />
                  <h3 className="text-lg font-semibold mb-2">All caught up!</h3>
                  <p className="text-muted-foreground">
                    You have no unread notifications
                  </p>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="all" className="space-y-4">
          {notifications.length > 0 ? (
            notifications.map((notification) => (
              <NotificationCard key={notification.id} notification={notification} />
            ))
          ) : (
            <Card>
              <CardContent className="p-8">
                <div className="text-center">
                  <Bell className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                  <h3 className="text-lg font-semibold mb-2">No notifications yet</h3>
                  <p className="text-muted-foreground">
                    You'll see notifications here when you have activity
                  </p>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
};

export default Notifications;