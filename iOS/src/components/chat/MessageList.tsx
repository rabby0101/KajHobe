
import React, { useState } from 'react';
import { Message } from '@/hooks/useChat';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { formatDistanceToNow } from 'date-fns';
import ImageMessage from './ImageMessage';
import NegotiationMessage from './NegotiationMessage';
import OfferMessage from './OfferMessage';
import JobPreview from './JobPreview';
import DealSummary from './DealSummary';
import OfferForm, { OfferData } from './OfferForm';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

interface MessageListProps {
  messages: Message[];
  currentUserId: string;
  onSendOffer?: (offerData: OfferData) => void;
  onAcceptOffer?: (messageId: string) => void;
  onRejectOffer?: (messageId: string) => void;
  jobId?: string;
  clientId?: string;
  providerId?: string;
  jobData?: any;
  dealData?: any;
}

const MessageList: React.FC<MessageListProps> = ({ 
  messages, 
  currentUserId, 
  onSendOffer,
  onAcceptOffer,
  onRejectOffer,
  jobId,
  clientId,
  providerId,
  jobData,
  dealData
}) => {
  const [counterOfferDialog, setCounterOfferDialog] = useState<{
    open: boolean;
    message: Message | null;
  }>({ open: false, message: null });

  const handleCounterOffer = (message: Message) => {
    setCounterOfferDialog({ open: true, message });
  };

  const handleSendCounterOffer = (offerData: OfferData) => {
    if (onSendOffer) {
      onSendOffer(offerData);
    }
    setCounterOfferDialog({ open: false, message: null });
  };

  return (
    <>
      <div className="space-y-4">
        {/* Job Preview - shown at the top */}
        {jobData && (
          <JobPreview job={jobData} />
        )}

        {/* Deal Summary - shown when deal exists */}
        {dealData && (
          <DealSummary 
            deal={dealData}
            isProvider={currentUserId === providerId}
          />
        )}

        {messages.map((message) => {
          const isOwnMessage = message.sender_id === currentUserId;
          
          // Handle image messages
          if (message.message_type === 'image') {
            return (
              <ImageMessage
                key={message.id}
                message={message}
                isOwnMessage={isOwnMessage}
              />
            );
          }
          
          // Handle offer messages (new format)
          if (message.negotiation_data && message.negotiation_data.serviceDescription) {
            return (
              <OfferMessage
                key={message.id}
                message={message}
                isOwnMessage={isOwnMessage}
                onAccept={() => onAcceptOffer?.(message.id)}
                onReject={() => onRejectOffer?.(message.id)}
                onCounter={() => handleCounterOffer(message)}
              />
            );
          }
          
          // Handle legacy negotiation messages
          if (message.negotiation_data) {
            return (
              <NegotiationMessage
                key={message.id}
                message={message}
                isOwnMessage={isOwnMessage}
                jobId={jobId}
                clientId={clientId}
                providerId={providerId}
              />
            );
          }
          
          // Default text message
          return (
            <div
              key={message.id}
              className={`flex gap-3 ${isOwnMessage ? 'flex-row-reverse' : 'flex-row'}`}
            >
              <Avatar className="h-8 w-8 flex-shrink-0">
                <AvatarImage src={message.sender_profile?.avatar_url} />
                <AvatarFallback>
                  {message.sender_profile?.full_name?.charAt(0)?.toUpperCase() || 'U'}
                </AvatarFallback>
              </Avatar>
              
              <div className={`flex flex-col max-w-[70%] ${isOwnMessage ? 'items-end' : 'items-start'}`}>
                <div
                  className={`rounded-lg px-3 py-2 ${
                    isOwnMessage
                      ? 'bg-primary text-primary-foreground'
                      : 'bg-muted text-muted-foreground'
                  }`}
                >
                  <p className="text-sm">{message.content}</p>
                </div>
                
                <span className="text-xs text-muted-foreground mt-1">
                  {formatDistanceToNow(new Date(message.created_at), { addSuffix: true })}
                </span>
              </div>
            </div>
          );
        })}
      </div>

      <Dialog 
        open={counterOfferDialog.open} 
        onOpenChange={(open) => setCounterOfferDialog(prev => ({ ...prev, open }))}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Send Counter Offer</DialogTitle>
          </DialogHeader>
          {counterOfferDialog.message && (
            <OfferForm
              onSubmit={handleSendCounterOffer}
              onCancel={() => setCounterOfferDialog({ open: false, message: null })}
              initialData={counterOfferDialog.message.negotiation_data}
              isCounterOffer={true}
            />
          )}
        </DialogContent>
      </Dialog>
    </>
  );
};

export default MessageList;
