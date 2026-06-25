import React from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { Message } from '@/hooks/useConversations';
import { formatDistanceToNow } from 'date-fns';
import { DollarSign, XCircle, Clock } from 'lucide-react';
import AcceptAndPayButton from '@/components/payments/AcceptAndPayButton';

interface DealOfferBubbleProps {
  message: Message;
  isOwnMessage: boolean;
  /** Live status from the `deal_offers` row (not the message payload). */
  status: string;
  onReject?: (dealOfferId: string) => void;
  isRejecting?: boolean;
}

/**
 * Renders a `deal_offer` chat message identically to the iOS/Android `DealOfferBubble`:
 * amount (৳), terms, duration and message. The recipient (client) sees Accept & Pay
 * (bKash escrow) + Reject while the offer is pending; status comes from the live
 * `deal_offers` row so the webhook's accept flip is reflected.
 */
const DealOfferBubble: React.FC<DealOfferBubbleProps> = ({
  message,
  isOwnMessage,
  status,
  onReject,
  isRejecting = false,
}) => {
  const data = (message.negotiation_data ?? {}) as Record<string, unknown>;
  const dealOfferId = (data.deal_offer_id as string) || '';
  const amount = data.amount as number | undefined;
  const terms = data.terms as string | undefined;
  const timeline = data.timeline as string | undefined;
  const additionalMessage = data.additional_message as string | undefined;

  const getStatusBadge = () => {
    switch (status) {
      case 'accepted':
        return <Badge className="bg-green-100 text-green-800">✅ Accepted</Badge>;
      case 'rejected':
        return <Badge variant="destructive">❌ Rejected</Badge>;
      default:
        return <Badge variant="outline">⏳ Pending</Badge>;
    }
  };

  return (
    <Card className={`max-w-md ${isOwnMessage ? 'ml-auto' : 'mr-auto'}`}>
      <CardContent className="p-4">
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium flex items-center gap-1">
              <DollarSign className="h-4 w-4 text-green-600" />
              Deal Offer
            </span>
            {getStatusBadge()}
          </div>

          {amount !== undefined && (
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-muted-foreground">Amount</span>
              <span className="text-2xl font-bold text-primary">৳{amount}</span>
            </div>
          )}

          {terms && (
            <div>
              <h4 className="font-semibold text-sm text-muted-foreground">Terms &amp; Conditions</h4>
              <p className="text-sm">{terms}</p>
            </div>
          )}

          {timeline && (
            <div className="flex items-center gap-1 text-sm text-muted-foreground">
              <Clock className="h-3 w-3" />
              Duration: {timeline}
            </div>
          )}

          {additionalMessage && (
            <>
              <Separator />
              <div>
                <h4 className="font-semibold text-sm text-muted-foreground">Message</h4>
                <p className="text-sm text-muted-foreground">"{additionalMessage}"</p>
              </div>
            </>
          )}

          {/* The recipient (client) accepts by paying into escrow, or rejects. */}
          {!isOwnMessage && status === 'pending' && dealOfferId && (
            <div className="flex gap-2 pt-2">
              <AcceptAndPayButton dealOfferId={dealOfferId} className="flex-1" size="sm" />
              <Button
                size="sm"
                variant="destructive"
                onClick={() => onReject?.(dealOfferId)}
                disabled={isRejecting}
              >
                <XCircle className="h-3 w-3 mr-1" />
                Reject
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

export default DealOfferBubble;
