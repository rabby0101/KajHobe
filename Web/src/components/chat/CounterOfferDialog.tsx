import React, { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';

interface CounterOfferDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  currentAmount: number;
  onSubmit: (amount: number, message: string) => void;
  isLoading?: boolean;
}

const CounterOfferDialog: React.FC<CounterOfferDialogProps> = ({
  open,
  onOpenChange,
  currentAmount,
  onSubmit,
  isLoading = false
}) => {
  const [amount, setAmount] = useState(currentAmount);
  const [message, setMessage] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (amount > 0) {
      onSubmit(amount, message);
      setMessage('');
      onOpenChange(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Make Counter Offer</DialogTitle>
        </DialogHeader>
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="amount">Your Counter Amount (৳)</Label>
            <Input
              id="amount"
              type="number"
              value={amount}
              onChange={(e) => setAmount(Number(e.target.value))}
              placeholder="Enter your counter amount"
              min="1"
              required
            />
            <p className="text-sm text-muted-foreground">
              Current proposal: ৳{currentAmount}
            </p>
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="message">Message (Optional)</Label>
            <Textarea
              id="message"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Explain your counter offer..."
              rows={3}
            />
          </div>
          
          <div className="flex gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              className="flex-1"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={amount <= 0 || isLoading}
              className="flex-1"
            >
              {isLoading ? 'Sending...' : 'Send Counter Offer'}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default CounterOfferDialog;