import { useEffect, useState } from 'react';
import { CheckCircle2 } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import StarRatingInput from '@/components/StarRatingInput';
import { useSubmitReview, ReviewError } from '@/hooks/useReviews';
import { toast } from '@/hooks/use-toast';

interface ReviewDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  jobId: string;
  reviewedUserId: string;
  reviewedUserName: string;
  reviewedUserAvatar?: string | null;
  onSubmitted?: () => void;
}

/** Review submission dialog (parity with iOS ReviewSheet). */
export default function ReviewDialog({
  open,
  onOpenChange,
  jobId,
  reviewedUserId,
  reviewedUserName,
  reviewedUserAvatar,
  onSubmitted,
}: ReviewDialogProps) {
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState('');
  const [showSuccess, setShowSuccess] = useState(false);
  const submit = useSubmitReview();

  // Reset transient state whenever the dialog opens.
  useEffect(() => {
    if (open) {
      setRating(0);
      setComment('');
      setShowSuccess(false);
    }
  }, [open]);

  // Auto-dismiss the success state after a beat.
  useEffect(() => {
    if (!showSuccess) return;
    const t = setTimeout(() => onOpenChange(false), 1200);
    return () => clearTimeout(t);
  }, [showSuccess, onOpenChange]);

  const handleSubmit = async () => {
    if (rating === 0) return;
    try {
      await submit.mutateAsync({ jobId, reviewedId: reviewedUserId, rating, comment });
      onSubmitted?.();
      setShowSuccess(true);
    } catch (err) {
      const kind = err instanceof ReviewError ? err.kind : 'unknown';
      if (kind === 'alreadyReviewed') {
        toast({ title: "You've already reviewed this job." });
        onOpenChange(false);
      } else if (kind === 'jobNotCompleted') {
        toast({ title: 'You can only review a completed job.', variant: 'destructive' });
      } else {
        toast({ title: 'Could not submit review. Please try again.', variant: 'destructive' });
      }
    }
  };

  return (
    <Dialog open={open} onOpenChange={submit.isPending ? undefined : onOpenChange}>
      <DialogContent className="sm:max-w-md">
        {showSuccess ? (
          <div className="flex flex-col items-center gap-3 py-10">
            <CheckCircle2 className="h-16 w-16 text-green-500" />
            <p className="text-lg font-semibold">Thanks for your review!</p>
          </div>
        ) : (
          <>
            <DialogHeader>
              <DialogTitle className="text-center">Leave a review</DialogTitle>
            </DialogHeader>

            <div className="flex flex-col items-center gap-2">
              <Avatar className="h-16 w-16">
                <AvatarImage src={reviewedUserAvatar ?? ''} />
                <AvatarFallback>{reviewedUserName.slice(0, 1).toUpperCase()}</AvatarFallback>
              </Avatar>
              <p className="text-center font-medium">How was your experience with {reviewedUserName}?</p>
            </div>

            <div className="py-2">
              <StarRatingInput value={rating} onChange={setRating} />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Comment (optional)</label>
              <Textarea
                value={comment}
                onChange={(e) => setComment(e.target.value)}
                placeholder="Share details about your experience…"
                rows={4}
              />
            </div>

            <div className="flex flex-col gap-2">
              <Button onClick={handleSubmit} disabled={rating === 0 || submit.isPending}>
                {submit.isPending ? 'Submitting…' : 'Submit review'}
              </Button>
              <Button variant="ghost" onClick={() => onOpenChange(false)} disabled={submit.isPending}>
                Maybe later
              </Button>
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
