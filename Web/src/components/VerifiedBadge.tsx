import { BadgeCheck } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

interface VerifiedBadgeProps {
  compact?: boolean;
  className?: string;
}

/**
 * "Verified" badge — granted by manual admin approval
 * (profiles.is_verified_provider). Distinct from the auto-computed TrustBadge;
 * shown only for approved providers.
 */
export default function VerifiedBadge({ compact = false, className }: VerifiedBadgeProps) {
  return (
    <Badge className={cn('gap-1 border-0 bg-blue-500 text-white hover:bg-blue-500', className)}>
      <BadgeCheck className="h-3 w-3" />
      {!compact && <span>Verified</span>}
    </Badge>
  );
}
