import { useState } from 'react';
import { Star } from 'lucide-react';
import { Button } from '@/components/ui/button';
import ReviewDialog from '@/components/ReviewDialog';
import { useHasReviewed } from '@/hooks/useReviews';

interface LeaveReviewButtonProps {
  jobId: string;
  reviewedUserId: string;
  reviewedUserName: string;
  reviewedUserAvatar?: string | null;
  /** Open the dialog immediately on mount (post-completion auto-prompt). */
  autoPrompt?: boolean;
  size?: 'default' | 'sm';
  variant?: 'default' | 'outline' | 'secondary' | 'ghost';
}

/**
 * "Leave review" affordance for a completed deal. Hides itself once the current
 * user has already reviewed this counterparty for this job (parity with iOS,
 * which suppresses the prompt + button after a review exists).
 */
export default function LeaveReviewButton({
  jobId,
  reviewedUserId,
  reviewedUserName,
  reviewedUserAvatar,
  autoPrompt = false,
  size = 'sm',
  variant = 'outline',
}: LeaveReviewButtonProps) {
  const { data: alreadyReviewed, isLoading } = useHasReviewed(jobId, reviewedUserId);
  const [open, setOpen] = useState(autoPrompt);

  if (isLoading || alreadyReviewed) return null;

  return (
    <>
      <Button size={size} variant={variant} onClick={() => setOpen(true)} className="gap-1">
        <Star className="h-4 w-4" />
        Leave review
      </Button>
      <ReviewDialog
        open={open}
        onOpenChange={setOpen}
        jobId={jobId}
        reviewedUserId={reviewedUserId}
        reviewedUserName={reviewedUserName}
        reviewedUserAvatar={reviewedUserAvatar}
      />
    </>
  );
}
