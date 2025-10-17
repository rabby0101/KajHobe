
import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { CalendarDays, Clock, DollarSign } from 'lucide-react';
import ImageUpload from './ImageUpload';

interface OfferFormProps {
  onSubmit: (offerData: OfferData) => void;
  onCancel: () => void;
  isLoading?: boolean;
  initialData?: Partial<OfferData>;
  isCounterOffer?: boolean;
}

export interface OfferData {
  serviceDescription: string;
  proposedCost: number;
  serviceDate: string;
  serviceTime: string;
  additionalNotes: string;
  attachmentUrl?: string;
}

const OfferForm: React.FC<OfferFormProps> = ({
  onSubmit,
  onCancel,
  isLoading,
  initialData,
  isCounterOffer = false
}) => {
  const [formData, setFormData] = useState<OfferData>({
    serviceDescription: initialData?.serviceDescription || '',
    proposedCost: initialData?.proposedCost || 0,
    serviceDate: initialData?.serviceDate || '',
    serviceTime: initialData?.serviceTime || '',
    additionalNotes: initialData?.additionalNotes || '',
    attachmentUrl: initialData?.attachmentUrl || ''
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  const handleImageUpload = (imageUrl: string) => {
    setFormData(prev => ({ ...prev, attachmentUrl: imageUrl }));
  };

  return (
    <Card className="w-full max-w-md">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <DollarSign className="h-5 w-5" />
          {isCounterOffer ? 'Send Counter Offer' : 'Send Custom Offer'}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <Label htmlFor="serviceDescription">Service Description</Label>
            <Textarea
              id="serviceDescription"
              placeholder="e.g., Replace ceiling light"
              value={formData.serviceDescription}
              onChange={(e) => setFormData(prev => ({ ...prev, serviceDescription: e.target.value }))}
              required
              rows={2}
            />
          </div>

          <div>
            <Label htmlFor="proposedCost">Proposed Cost (৳)</Label>
            <Input
              id="proposedCost"
              type="number"
              placeholder="800"
              value={formData.proposedCost || ''}
              onChange={(e) => setFormData(prev => ({ ...prev, proposedCost: parseInt(e.target.value) || 0 }))}
              required
              min="1"
            />
          </div>

          <div className="grid grid-cols-2 gap-2">
            <div>
              <Label htmlFor="serviceDate" className="flex items-center gap-1">
                <CalendarDays className="h-3 w-3" />
                Date
              </Label>
              <Input
                id="serviceDate"
                type="date"
                value={formData.serviceDate}
                onChange={(e) => setFormData(prev => ({ ...prev, serviceDate: e.target.value }))}
                required
              />
            </div>

            <div>
              <Label htmlFor="serviceTime" className="flex items-center gap-1">
                <Clock className="h-3 w-3" />
                Time
              </Label>
              <Input
                id="serviceTime"
                type="time"
                value={formData.serviceTime}
                onChange={(e) => setFormData(prev => ({ ...prev, serviceTime: e.target.value }))}
                required
              />
            </div>
          </div>

          <div>
            <Label htmlFor="additionalNotes">Additional Notes</Label>
            <Textarea
              id="additionalNotes"
              placeholder="Any specific requirements or details..."
              value={formData.additionalNotes}
              onChange={(e) => setFormData(prev => ({ ...prev, additionalNotes: e.target.value }))}
              rows={2}
            />
          </div>

          <div>
            <Label>Optional Image Attachment</Label>
            <ImageUpload
              onImageUploaded={handleImageUpload}
              disabled={isLoading}
            />
            {formData.attachmentUrl && (
              <div className="mt-2">
                <img
                  src={formData.attachmentUrl}
                  alt="Attachment preview"
                  className="w-full h-20 object-cover rounded border"
                />
              </div>
            )}
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
