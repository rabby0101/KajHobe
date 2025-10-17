
import React, { useState, KeyboardEvent } from 'react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { MessageCircle, DollarSign } from 'lucide-react';
import ImageUpload from './ImageUpload';
import OfferForm, { OfferData } from './OfferForm';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

interface MessageInputProps {
  onSendMessage: (content: string, messageType?: string, attachmentUrl?: string, negotiationData?: any) => void;
  onSendOffer?: (offerData: OfferData) => void;
  disabled?: boolean;
  showOfferButton?: boolean;
  conversationId?: string;
}

const MessageInput: React.FC<MessageInputProps> = ({ 
  onSendMessage, 
  onSendOffer,
  disabled,
  showOfferButton = true 
}) => {
  const [message, setMessage] = useState('');
  const [showOfferDialog, setShowOfferDialog] = useState(false);

  const handleSend = () => {
    if (message.trim() && !disabled) {
      onSendMessage(message.trim(), 'text');
      setMessage('');
    }
  };

  const handleImageUpload = (imageUrl: string) => {
    onSendMessage(message.trim() || 'Image', 'image', imageUrl);
    setMessage('');
  };

  const handleSendOffer = (offerData: OfferData) => {
    if (onSendOffer) {
      onSendOffer(offerData);
    }
    setShowOfferDialog(false);
  };

  const handleKeyPress = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <>
      <div className="space-y-2">
        <div className="flex gap-2">
          <Textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Type your message..."
            className="flex-1 resize-none min-h-[40px] max-h-[120px]"
            disabled={disabled}
            rows={1}
          />
          <div className="flex flex-col gap-2">
            <ImageUpload
              onImageUploaded={handleImageUpload}
              disabled={disabled}
            />
            <Button 
              onClick={handleSend}
              disabled={!message.trim() || disabled}
              size="sm"
            >
              <MessageCircle className="h-4 w-4" />
            </Button>
          </div>
        </div>
        
        {showOfferButton && (
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowOfferDialog(true)}
              disabled={disabled}
              className="flex-1"
            >
              <DollarSign className="h-4 w-4 mr-1" />
              Send Offer
            </Button>
          </div>
        )}
      </div>

      <Dialog open={showOfferDialog} onOpenChange={setShowOfferDialog}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Send Custom Offer</DialogTitle>
          </DialogHeader>
          <OfferForm
            onSubmit={handleSendOffer}
            onCancel={() => setShowOfferDialog(false)}
            isLoading={disabled}
          />
        </DialogContent>
      </Dialog>
    </>
  );
};

export default MessageInput;
