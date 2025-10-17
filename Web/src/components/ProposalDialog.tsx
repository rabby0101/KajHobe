
import React, { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { useCreateProposal } from '@/hooks/useProposals';
import { toast } from '@/hooks/use-toast';

interface ProposalDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  jobId: string;
  jobTitle: string;
  budget: number;
}

const ProposalDialog = ({ 
  open, 
  onOpenChange, 
  jobId, 
  jobTitle, 
  budget 
}: ProposalDialogProps) => {
  const [message, setMessage] = useState('');
  const createProposal = useCreateProposal();

  const handleAcceptBudget = async () => {
    try {
      await createProposal.mutateAsync({
        job_id: jobId,
        amount: budget,
        message: message.trim() || 'I accept your budget and am ready to start working on this project.',
      });

      toast({
        title: "Budget Accepted!",
        description: "You've accepted the job budget. The client will be notified.",
      });

      setMessage('');
      onOpenChange(false);
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message || "Failed to accept budget",
        variant: "destructive",
      });
    }
  };

  const handleNegotiate = async () => {
    try {
      await createProposal.mutateAsync({
        job_id: jobId,
        amount: budget,
        message: message.trim() || 'I\'m interested in this project. Let\'s discuss the details.',
      });

      toast({
        title: "Interest Expressed!",
        description: "Your interest has been sent. You can now chat with the client to negotiate.",
      });

      setMessage('');
      onOpenChange(false);
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message || "Failed to express interest",
        variant: "destructive",
      });
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Send Proposal</DialogTitle>
        </DialogHeader>
        <div className="space-y-4">
          <div>
            <Label className="text-sm font-medium text-muted-foreground">Job</Label>
            <p className="text-sm font-semibold">{jobTitle}</p>
          </div>
          
          <div>
            <Label className="text-sm font-medium text-muted-foreground">Client's Budget</Label>
            <p className="text-xl font-bold text-primary">৳{budget}</p>
          </div>

          <div>
            <Label htmlFor="message">Message (Optional)</Label>
            <Textarea
              id="message"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Tell the client why you're the best fit for this job..."
              rows={3}
            />
          </div>

          <DialogFooter className="flex gap-2">
            <Button 
              type="button" 
              variant="outline" 
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button 
              type="button"
              variant="outline"
              onClick={handleNegotiate}
              disabled={createProposal.isPending}
              className="flex-1"
            >
              {createProposal.isPending ? 'Sending...' : 'Express Interest & Chat'}
            </Button>
            <Button 
              type="button"
              onClick={handleAcceptBudget}
              disabled={createProposal.isPending}
              className="flex-1"
            >
              {createProposal.isPending ? 'Accepting...' : 'Accept Budget'}
            </Button>
          </DialogFooter>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default ProposalDialog;
