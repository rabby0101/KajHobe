
import React from 'react';
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
import { BellIcon, CheckCheck, Clock, User } from 'lucide-react';
import {
  useNotifications,
  useMarkNotificationAsRead,
  useMarkAllNotificationsAsRead,
  type GroupedNotification
} from '@/hooks/useNotifications';
import { useEnrichedJobInterests, EXCLUDED_BUSINESS_TYPES } from '@/hooks/useJobInterests';
import { formatDistanceToNow } from 'date-fns';
import { useNavigate } from 'react-router-dom';

const NotificationCenter = () => {
  const { data: notifications = [], isLoading } = useNotifications();
  const { data: interests = [] } = useEnrichedJobInterests();
  const markAsRead = useMarkNotificationAsRead();
  const markAllAsRead = useMarkAllNotificationsAsRead();
  const navigate = useNavigate();

  // Same feed rules as iOS/Android: chat lives in Messages, interest requests
  // come from job_interests, offer types are superseded by deal_created.
  const business = notifications.filter((n) => !EXCLUDED_BUSINESS_TYPES.has(n.type ?? ''));

  // Badge math mirrors iOS NotificationBadgeManager:
  // unread business notifications + pending interest requests on my jobs.
  const unreadBusiness = business.filter((n) => n.notification_state === 'unread').length;
  const unreadCount = unreadBusiness + interests.length;

  const handleNotificationClick = (notification: GroupedNotification) => {
    if (notification.notification_state === 'unread') {
      markAsRead.mutate(notification.id);
    }

    // Navigate based on notification type and related data
    const type = notification.type ?? '';
    if (type.includes('interest')) {
      navigate('/notifications');
    } else if (notification.related_job_id || notification.job_id) {
      navigate('/my-jobs');
    }
  };

  // Mobile-written rows (e.g. interest_accepted/rejected) carry no title —
  // render a label from the type, matching the mobile apps.
  const fallbackTitle = (type: string | null) =>
    ({
      interest_accepted: 'Interest Accepted',
      interest_rejected: 'Interest Declined',
      deal_created: 'Deal Created',
      deal_accepted: 'Deal Accepted',
      deal_completed: 'Deal Completed',
      completion_request: 'Completion Request',
    } as Record<string, string>)[type ?? ''] ?? 'Notification';

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'proposal_received':
        return '📝';
      case 'proposal_accepted':
      case 'interest_accepted':
        return '✅';
      case 'proposal_rejected':
      case 'interest_rejected':
        return '❌';
      case 'deal_created':
      case 'deal_accepted':
        return '🤝';
      case 'deal_completed':
        return '🎉';
      case 'completion_request':
        return '🏁';
      case 'counter_proposal':
        return '🔄';
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
          {unreadBusiness > 0 && (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => markAllAsRead.mutate()}
              className="h-auto p-1 text-xs"
            >
              <CheckCheck className="h-3 w-3 mr-1" />
              Mark all read
            </Button>
          )}
        </DropdownMenuLabel>
        <DropdownMenuSeparator />

        {/* Pending interest requests — actioned on the Notifications page. */}
        {interests.length > 0 && (
          <>
            <DropdownMenuItem
              className="flex cursor-pointer items-center gap-2 bg-blue-50/60 p-3 dark:bg-blue-950/20"
              onClick={() => navigate('/notifications')}
            >
              <User className="h-4 w-4 text-blue-600" />
              <span className="flex-1 text-sm font-medium">
                {interests.length} pending interest request{interests.length > 1 ? 's' : ''}
              </span>
              <div className="h-2 w-2 flex-shrink-0 rounded-full bg-blue-500" />
            </DropdownMenuItem>
            <DropdownMenuSeparator />
          </>
        )}

        {business.length === 0 && interests.length === 0 ? (
          <div className="p-4 text-center text-sm text-muted-foreground">
            No notifications yet
          </div>
        ) : (
          <div className="max-h-96 overflow-y-auto">
            {business.map((notification) => (
              <DropdownMenuItem
                key={notification.id}
                className={`flex flex-col items-start p-3 cursor-pointer ${
                  notification.notification_state === 'unread' ? 'bg-muted/50' : ''
                }`}
                onClick={() => handleNotificationClick(notification)}
              >
                <div className="flex items-start justify-between w-full">
                  <div className="flex items-start space-x-2 flex-1">
                    <span className="text-lg">{getNotificationIcon(notification.type)}</span>
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-sm flex items-center gap-2">
                        {notification.title || fallbackTitle(notification.type)}
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
                  {notification.notification_state === 'unread' && (
                    <div className="h-2 w-2 bg-blue-500 rounded-full mt-1 flex-shrink-0" />
                  )}
                </div>
              </DropdownMenuItem>
            ))}
          </div>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
};

export default NotificationCenter;
