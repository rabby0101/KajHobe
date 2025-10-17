
import React from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { Message } from '@/hooks/useChat';
import { formatDistanceToNow } from 'date-fns';
import { CheckCircle, XCircle, RefreshCw, Calendar, Clock, FileImage } from 'lucide-react';

interface OfferMessageProps {
  message: Message;
  isOwnMessage: boolean;
  onAccept?: () => void;
  onReject?: () => void;
  onCounter?: () => void;
  isLoading?: boolean;
}

const OfferMessage: React.FC<OfferMessageProps> = ({
  message,
  isOwnMessage,
  onAccept,
  onReject,
  onCounter,
  isLoading = false
}) => {
  const offerData = message.negotiation_data as any;
  
  if (!offerData) return null;

  const { 
    serviceDescription, 
    proposedCost, 
    serviceDate, 
    serviceTime, 
    additionalNotes, 
    status = 'pending',
    type = 'offer'
  } = offerData;

  const getStatusBadge = () => {
    switch (status) {
      case 'accepted':
        return <Badge className="bg-green-100 text-green-800">✅ Accepted</Badge>;
      case 'rejected':
        return <Badge variant="destructive">❌ Rejected</Badge>;
      case 'countered':
        return <Badge variant="secondary">🔁 Countered</Badge>;
      default:
        return <Badge variant="outline">⏳ Pending</Badge>;
    }
  };

  const getTypeDisplay = () => {
    switch (type) {
      case 'counter_offer':
        return '🔁 Counter Offer';
      case 'offer':
        return '💼 Custom Offer';
      default:
        return '💼 Offer';
    }
  };

  return (
    <Card className={`max-w-md ${isOwnMessage ? 'ml-auto' : 'mr-auto'}`}>
      <CardContent className="p-4">
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium">{getTypeDisplay()}</span>
            {getStatusBadge()}
          </div>
          
          <div className="space-y-3">
            <div>
              <h4 className="font-semibold text-sm text-muted-foreground">Service Description</h4>
              <p className="text-sm">{serviceDescription}</p>
            </div>

            <div className="flex items-center justify-between">
              <span className="text-2xl font-bold text-primary">৳{proposedCost}</span>
            </div>
            
            {(serviceDate || serviceTime) && (
              <div className="flex items-center gap-4 text-sm text-muted-foreground">
                {serviceDate && (
                  <div className="flex items-center gap-1">
                    <Calendar className="h-3 w-3" />
                    {new Date(serviceDate).toLocaleDateString()}
                  </div>
                )}
                {serviceTime && (
                  <div className="flex items-center gap-1">
                    <Clock className="h-3 w-3" />
                    {serviceTime}
                  </div>
                )}
              </div>
            )}
            
            {additionalNotes && (
              <>
                <Separator />
                <div>
                  <h4 className="font-semibold text-sm text-muted-foreground">Additional Notes</h4>
                  <p className="text-sm text-muted-foreground">"{additionalNotes}"</p>
                </div>
              </>
            )}

            {message.attachment_url && (
              <>
                <Separator />
                <div>
                  <h4 className="font-semibold text-sm text-muted-foreground flex items-center gap-1">
                    <FileImage className="h-3 w-3" />
                    Attachment
                  </h4>
                  <img
                    src={message.attachment_url}
                    alt="Offer attachment"
                    className="w-full h-32 object-cover rounded border cursor-pointer hover:opacity-90"
                    onClick={() => window.open(message.attachment_url!, '_blank')}
                  />
                </div>
              </>
            )}
          </div>

          {/* Action buttons - only show for received offers (not own messages) and when status is pending */}
          {!isOwnMessage && status === 'pending' && (
            <div className="flex gap-2 pt-2">
              <Button
                size="sm"
                onClick={onAccept}
                disabled={isLoading}
                className="flex-1"
              >
                <CheckCircle className="h-3 w-3 mr-1" />
                Accept
              </Button>
              
              <Button
                size="sm"
                variant="outline"
                onClick={onCounter}
                disabled={isLoading}
                className="flex-1"
              >
                <RefreshCw className="h-3 w-3 mr-1" />
                Counter
              </Button>
              
              <Button
                size="sm"
                variant="destructive"
                onClick={onReject}
                disabled={isLoading}
              >
                <XCircle className="h-3 w-3" />
              </Button>
            </div>
          )}
          
          <div className="text-xs text-muted-foreground">
            {formatDistanceToNow(new Date(message.created_at), { addSuffix: true })}
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default OfferMessage;
