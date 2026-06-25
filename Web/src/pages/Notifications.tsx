import React, { useMemo } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import {
  Bell, CheckCircle, MessageSquare, DollarSign, User, Briefcase, Check, Archive, ArchiveRestore,
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import Header from '@/components/Header';
import { cn } from '@/lib/utils';
import {
  useEnhancedNotifications,
  useSetNotificationState,
  useMarkAllNotificationsAsRead,
  useRespondToInterestNotification,
  type EnhancedNotification,
  type NotificationState,
} from '@/hooks/useNotifications';
import { toast } from '@/hooks/use-toast';

function iconFor(type: string | null) {
  switch (type) {
    case 'interest_request':
    case 'show_interest':
      return <User className="h-4 w-4" />;
    case 'deal_offer_received':
    case 'deal_offer_responded':
    case 'deal_created':
    case 'deal_accepted':
      return <DollarSign className="h-4 w-4" />;
    case 'message_received':
      return <MessageSquare className="h-4 w-4" />;
    case 'deal_completed':
    case 'completion_request':
      return <CheckCircle className="h-4 w-4" />;
    default:
      return <Briefcase className="h-4 w-4" />;
  }
}

function colorFor(priority: string | null) {
  if (priority === 'high') return 'bg-red-500';
  if (priority === 'low') return 'bg-gray-400';
  return 'bg-blue-500';
}

/** Today / Yesterday / Older buckets (parity with iOS time grouping). */
function groupByDay(items: EnhancedNotification[]): { label: string; items: EnhancedNotification[] }[] {
  const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const today = startOfDay(new Date());
  const yesterday = today - 86400_000;
  const buckets: Record<string, EnhancedNotification[]> = { Today: [], Yesterday: [], Older: [] };
  for (const n of items) {
    const day = startOfDay(new Date(n.created_at));
    if (day === today) buckets.Today.push(n);
    else if (day === yesterday) buckets.Yesterday.push(n);
    else buckets.Older.push(n);
  }
  return ['Today', 'Yesterday', 'Older']
    .map((label) => ({ label, items: buckets[label] }))
    .filter((g) => g.items.length > 0);
}

const Notifications: React.FC = () => {
  const { data: notifications = [], isLoading } = useEnhancedNotifications();
  const setState = useSetNotificationState();
  const markAll = useMarkAllNotificationsAsRead();
  const respondInterest = useRespondToInterestNotification();

  const byState = useMemo(
    () => ({
      unread: notifications.filter((n) => n.notification_state === 'unread'),
      read: notifications.filter((n) => n.notification_state === 'read'),
      archived: notifications.filter((n) => n.notification_state === 'archived'),
    }),
    [notifications]
  );

  const handleInterest = (n: EnhancedNotification, accept: boolean) => {
    const interestId = n.action_data?.interest_id;
    if (!interestId) {
      toast({ title: 'Missing interest reference', variant: 'destructive' });
      return;
    }
    respondInterest.mutate(
      { notificationId: n.id, interestId, accept },
      {
        onSuccess: () =>
          toast({ title: accept ? 'Interest accepted' : 'Interest declined',
            description: accept ? 'A conversation has been opened.' : undefined }),
        onError: () => toast({ title: 'Action failed', description: 'Please try again.', variant: 'destructive' }),
      }
    );
  };

  const NotificationCard: React.FC<{ n: EnhancedNotification }> = ({ n }) => {
    const isInteractive = n.interaction_type === 'interactive' && !!n.action_data?.interest_id && n.notification_state === 'unread';
    return (
      <Card className={cn(n.notification_state === 'unread' && 'border-blue-200 bg-blue-50/60 dark:bg-blue-950/20')}>
        <CardContent className="flex items-start gap-3 p-4">
          {n.avatar_url ? (
            <Avatar className="h-9 w-9">
              <AvatarImage src={n.avatar_url} />
              <AvatarFallback>{(n.action_data?.provider_name ?? 'U').slice(0, 1)}</AvatarFallback>
            </Avatar>
          ) : (
            <div className={cn('rounded-full p-2 text-white', colorFor(n.priority))}>{iconFor(n.type)}</div>
          )}
          <div className="min-w-0 flex-1">
            <div className="flex items-start justify-between gap-2">
              <h3 className="text-sm font-semibold">{n.title}</h3>
              <span className="shrink-0 text-xs text-muted-foreground">
                {formatDistanceToNow(new Date(n.created_at), { addSuffix: true })}
              </span>
            </div>
            {n.message && <p className="mt-1 text-sm text-muted-foreground">{n.message}</p>}

            {isInteractive ? (
              <div className="mt-3 flex gap-2">
                <Button size="sm" disabled={respondInterest.isPending} onClick={() => handleInterest(n, true)}>
                  Accept
                </Button>
                <Button size="sm" variant="outline" disabled={respondInterest.isPending} onClick={() => handleInterest(n, false)}>
                  Decline
                </Button>
              </div>
            ) : (
              <div className="mt-2 flex gap-3">
                {n.notification_state === 'unread' && (
                  <button className="text-xs text-blue-600 hover:underline" onClick={() => setState.mutate({ id: n.id, state: 'read' })}>
                    Mark read
                  </button>
                )}
                {n.notification_state === 'archived' ? (
                  <button className="flex items-center gap-1 text-xs text-muted-foreground hover:underline" onClick={() => setState.mutate({ id: n.id, state: 'read' })}>
                    <ArchiveRestore className="h-3 w-3" /> Restore
                  </button>
                ) : (
                  <button className="flex items-center gap-1 text-xs text-muted-foreground hover:underline" onClick={() => setState.mutate({ id: n.id, state: 'archived' })}>
                    <Archive className="h-3 w-3" /> Archive
                  </button>
                )}
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    );
  };

  const renderList = (items: EnhancedNotification[], emptyLabel: string) => {
    if (items.length === 0) {
      return (
        <Card>
          <CardContent className="p-8 text-center">
            <Bell className="mx-auto mb-3 h-10 w-10 text-muted-foreground" />
            <p className="text-muted-foreground">{emptyLabel}</p>
          </CardContent>
        </Card>
      );
    }
    return (
      <div className="space-y-4">
        {groupByDay(items).map((group) => (
          <div key={group.label} className="space-y-2">
            <div className="flex items-center gap-2 px-1">
              <span className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{group.label}</span>
              <Badge variant="secondary" className="text-xs">{group.items.length}</Badge>
            </div>
            {group.items.map((n) => <NotificationCard key={n.id} n={n} />)}
          </div>
        ))}
      </div>
    );
  };

  const tabCount = (s: NotificationState) => byState[s].length;

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto space-y-6 p-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Bell className="h-7 w-7 text-blue-600" />
            <h1 className="text-2xl font-bold">Notifications</h1>
            {tabCount('unread') > 0 && <Badge variant="destructive">{tabCount('unread')}</Badge>}
          </div>
          {tabCount('unread') > 0 && (
            <Button size="sm" onClick={() => markAll.mutate()} disabled={markAll.isPending}>
              <Check className="mr-2 h-4 w-4" /> Mark all read
            </Button>
          )}
        </div>

        {isLoading ? (
          <div className="py-12 text-center text-muted-foreground">Loading…</div>
        ) : (
          <Tabs defaultValue="unread" className="space-y-4">
            <TabsList>
              <TabsTrigger value="unread">Unread{tabCount('unread') ? ` (${tabCount('unread')})` : ''}</TabsTrigger>
              <TabsTrigger value="read">Read{tabCount('read') ? ` (${tabCount('read')})` : ''}</TabsTrigger>
              <TabsTrigger value="archived">Archived{tabCount('archived') ? ` (${tabCount('archived')})` : ''}</TabsTrigger>
            </TabsList>
            <TabsContent value="unread">{renderList(byState.unread, "You're all caught up!")}</TabsContent>
            <TabsContent value="read">{renderList(byState.read, 'No read notifications.')}</TabsContent>
            <TabsContent value="archived">{renderList(byState.archived, 'No archived notifications.')}</TabsContent>
          </Tabs>
        )}
      </div>
    </div>
  );
};

export default Notifications;
