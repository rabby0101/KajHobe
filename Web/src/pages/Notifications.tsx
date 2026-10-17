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
import {
  useEnrichedJobInterests,
  EXCLUDED_BUSINESS_TYPES,
  type EnrichedJobInterest,
} from '@/hooks/useJobInterests';
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

/** Mobile-written rows (interest_accepted/rejected etc.) carry no title. */
function fallbackTitle(type: string | null): string {
  return ({
    interest_accepted: 'Interest Accepted',
    interest_rejected: 'Interest Declined',
    deal_created: 'Deal Created',
    deal_accepted: 'Deal Accepted',
    deal_completed: 'Deal Completed',
    completion_request: 'Completion Request',
  } as Record<string, string>)[type ?? ''] ?? 'Notification';
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
  const { data: interests = [] } = useEnrichedJobInterests();
  const setState = useSetNotificationState();
  const markAll = useMarkAllNotificationsAsRead();
  const respondInterest = useRespondToInterestNotification();

  // Business feed excludes the same types as iOS/Android: interest requests
  // are rendered from job_interests below, chat lives in Messages, and the
  // offer types are superseded by deal_created — no event shows twice.
  const business = useMemo(
    () => notifications.filter((n) => !EXCLUDED_BUSINESS_TYPES.has(n.type ?? '')),
    [notifications]
  );

  const byState = useMemo(
    () => ({
      unread: business.filter((n) => n.notification_state === 'unread'),
      read: business.filter((n) => n.notification_state === 'read'),
      archived: business.filter((n) => n.notification_state === 'archived'),
    }),
    [business]
  );

  const handleInterest = (interest: EnrichedJobInterest, accept: boolean) => {
    respondInterest.mutate(
      {
        interestId: interest.id,
        jobId: interest.job_id,
        providerId: interest.provider_id,
        accept,
      },
      {
        onSuccess: () =>
          toast({ title: accept ? 'Interest accepted' : 'Interest declined',
            description: accept ? 'A conversation has been opened.' : undefined }),
        onError: () => toast({ title: 'Action failed', description: 'Please try again.', variant: 'destructive' }),
      }
    );
  };

  /** Interactive interest-request card sourced from job_interests (mobile parity). */
  const InterestCard: React.FC<{ interest: EnrichedJobInterest }> = ({ interest }) => (
    <Card className="border-blue-200 bg-blue-50/60 dark:bg-blue-950/20">
      <CardContent className="flex items-start gap-3 p-4">
        <Avatar className="h-9 w-9">
          <AvatarImage src={interest.provider_avatar ?? undefined} />
          <AvatarFallback>{(interest.provider_name ?? 'U').slice(0, 1)}</AvatarFallback>
        </Avatar>
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <h3 className="text-sm font-semibold">New Interest Request</h3>
            <span className="shrink-0 text-xs text-muted-foreground">
              {formatDistanceToNow(new Date(interest.created_at), { addSuffix: true })}
            </span>
          </div>
          <p className="mt-1 text-sm text-muted-foreground">
            {interest.provider_name ?? 'Someone'} is interested in "{interest.job_title}"
          </p>
          {interest.message && (
            <p className="mt-1 text-sm italic text-muted-foreground">"{interest.message}"</p>
          )}
          <div className="mt-3 flex gap-2">
            <Button size="sm" disabled={respondInterest.isPending} onClick={() => handleInterest(interest, true)}>
              Accept
            </Button>
            <Button size="sm" variant="outline" disabled={respondInterest.isPending} onClick={() => handleInterest(interest, false)}>
              Decline
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  );

  const NotificationCard: React.FC<{ n: EnhancedNotification }> = ({ n }) => {
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
              <h3 className="text-sm font-semibold">{n.title || fallbackTitle(n.type)}</h3>
              <span className="shrink-0 text-xs text-muted-foreground">
                {formatDistanceToNow(new Date(n.created_at), { addSuffix: true })}
              </span>
            </div>
            {n.message && <p className="mt-1 text-sm text-muted-foreground">{n.message}</p>}

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
  // Header/unread badge = pending interests + unread business (iOS badge math).
  const unreadTotal = tabCount('unread') + interests.length;

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto space-y-6 p-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Bell className="h-7 w-7 text-blue-600" />
            <h1 className="text-2xl font-bold">Notifications</h1>
            {unreadTotal > 0 && <Badge variant="destructive">{unreadTotal}</Badge>}
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
              <TabsTrigger value="unread">Unread{unreadTotal ? ` (${unreadTotal})` : ''}</TabsTrigger>
              <TabsTrigger value="read">Read{tabCount('read') ? ` (${tabCount('read')})` : ''}</TabsTrigger>
              <TabsTrigger value="archived">Archived{tabCount('archived') ? ` (${tabCount('archived')})` : ''}</TabsTrigger>
            </TabsList>
            <TabsContent value="unread" className="space-y-4">
              {/* Interest requests first — sourced from job_interests (mobile parity). */}
              {interests.length > 0 && (
                <div className="space-y-2">
                  <div className="flex items-center gap-2 px-1">
                    <span className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                      Interest Requests
                    </span>
                    <Badge variant="secondary" className="text-xs">{interests.length}</Badge>
                  </div>
                  {interests.map((i) => <InterestCard key={i.id} interest={i} />)}
                </div>
              )}
              {interests.length === 0 || byState.unread.length > 0
                ? renderList(byState.unread, "You're all caught up!")
                : null}
            </TabsContent>
            <TabsContent value="read">{renderList(byState.read, 'No read notifications.')}</TabsContent>
            <TabsContent value="archived">{renderList(byState.archived, 'No archived notifications.')}</TabsContent>
          </Tabs>
        )}
      </div>
    </div>
  );
};

export default Notifications;
