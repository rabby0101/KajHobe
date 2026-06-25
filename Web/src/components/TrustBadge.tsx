import { HelpCircle, User, BadgeCheck, Star, Crown } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import { TRUST_LEVEL_META, normalizeTrustLevel } from '@/lib/trustLevel';

const ICONS = { HelpCircle, User, BadgeCheck, Star, Crown } as const;

interface TrustBadgeProps {
  trustLevel: string | null | undefined;
  compact?: boolean;
  className?: string;
}

export default function TrustBadge({ trustLevel, compact = false, className }: TrustBadgeProps) {
  const level = normalizeTrustLevel(trustLevel);
  const meta = TRUST_LEVEL_META[level];
  const Icon = ICONS[meta.icon];
  return (
    <Badge variant="secondary" className={cn(meta.className, 'gap-1 border-0', className)}>
      <Icon className="h-3 w-3" />
      {!compact && <span>{meta.label}</span>}
    </Badge>
  );
}
