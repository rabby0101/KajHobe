
import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Clock, DollarSign } from 'lucide-react';

interface OfferFormProps {
  onSubmit: (offerData: OfferData) => void;
  onCancel: () => void;
  isLoading?: boolean;
  initialData?: Partial<OfferData>;
  isCounterOffer?: boolean;
}

/**
 * Deal-offer payload — mirrors the iOS/Android `deal_offer` shape so offers render
 * identically across platforms (amount in whole BDT, optional terms/timeline/message).
 */
export interface OfferData {
  amount: number;
  terms: string;
  timeline: string;
  additionalMessage: string;
}

const OfferForm: React.FC<OfferFormProps> = ({
  onSubmit,
  onCancel,
  isLoading,
  initialData,
  isCounterOffer = false
}) => {
  const [formData, setFormData] = useState<OfferData>({
    amount: initialData?.amount || 0,
    terms: initialData?.terms || '',
    timeline: initialData?.timeline || '',
    additionalMessage: initialData?.additionalMessage || ''
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <Card className="w-full max-w-md">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <DollarSign className="h-5 w-5" />
          {isCounterOffer ? 'Send Counter Offer' : 'Send Deal Offer'}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <Label htmlFor="amount">Amount (৳)</Label>
            <Input
              id="amount"
              type="number"
              placeholder="800"
              value={formData.amount || ''}
              onChange={(e) => setFormData(prev => ({ ...prev, amount: parseInt(e.target.value) || 0 }))}
              required
              min="1"
            />
          </div>

          <div>
            <Label htmlFor="terms">Terms &amp; Conditions</Label>
            <Textarea
              id="terms"
              placeholder="e.g., Replace ceiling light, materials included"
              value={formData.terms}
              onChange={(e) => setFormData(prev => ({ ...prev, terms: e.target.value }))}
              rows={2}
            />
          </div>

          <div>
            <Label htmlFor="timeline" className="flex items-center gap-1">
              <Clock className="h-3 w-3" />
              Duration
            </Label>
            <Input
              id="timeline"
              type="text"
              placeholder="e.g., 2 days"
              value={formData.timeline}
              onChange={(e) => setFormData(prev => ({ ...prev, timeline: e.target.value }))}
            />
          </div>

          <div>
            <Label htmlFor="additionalMessage">Message</Label>
            <Textarea
              id="additionalMessage"
              placeholder="Any specific requirements or details..."
              value={formData.additionalMessage}
              onChange={(e) => setFormData(prev => ({ ...prev, additionalMessage: e.target.value }))}
              rows={2}
            />
          </div>

          <div className="flex gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={onCancel}
              disabled={isLoading}
              className="flex-1"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={isLoading}
              className="flex-1"
            >
              {isLoading ? 'Sending...' : (isCounterOffer ? 'Send Counter' : 'Send Offer')}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
};

export default OfferForm;
