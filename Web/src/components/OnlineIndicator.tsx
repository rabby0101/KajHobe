import { cn } from '@/lib/utils';
import { presenceLabel } from '@/lib/timeAgo';

interface OnlineIndicatorProps {
  isOnline: boolean | null | undefined;
  lastSeenAt?: string | null;
  /** Show the "Online" / "last seen …" text next to the dot. */
  showLabel?: boolean;
  className?: string;
}

/** Online/offline dot with optional "Online" / "last seen …" label. */
export default function OnlineIndicator({
  isOnline,
  lastSeenAt,
  showLabel = false,
  className,
}: OnlineIndicatorProps) {
  return (
    <span className={cn('inline-flex items-center gap-1.5', className)}>
      <span
        className={cn('h-2.5 w-2.5 rounded-full', isOnline ? 'bg-green-500' : 'bg-muted-foreground/40')}
        aria-hidden
      />
      {showLabel && (
        <span className="text-xs text-muted-foreground">{presenceLabel(isOnline, lastSeenAt)}</span>
      )}
    </span>
  );
}
