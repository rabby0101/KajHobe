
import React, { useState, useEffect, useRef } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { useMessages, useSendMessage } from '@/hooks/useChat';
import { useAuth } from '@/contexts/AuthContext';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { toast } from '@/hooks/use-toast';
import { useCreateDeal } from '@/hooks/useJobActions';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import { MessageCircle, User, Briefcase } from 'lucide-react';
import { OfferData } from './OfferForm';

interface ChatDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  conversationId: string;
  jobTitle: string;
  otherParticipant: {
    id: string;
    name: string;
  };
}

const ChatDialog: React.FC<ChatDialogProps> = ({ 
  open, 
  onOpenChange, 
  conversationId,
  jobTitle,
  otherParticipant
}) => {
  const { user } = useAuth();
  const { data: messages = [], isLoading } = useMessages(conversationId);
  const sendMessage = useSendMessage();
  const createDeal = useCreateDeal();
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Get conversation details
  const { data: conversation } = useQuery({
    queryKey: ['conversation', conversationId],
    queryFn: async () => {
      if (!conversationId) return null;
      
      const { data, error } = await supabase
        .from('conversations')
        .select('*')
        .eq('id', conversationId)
        .single();
      
      if (error) throw error;
      return data;
    },
    enabled: !!conversationId
  });

  // Get job details
  const { data: jobData } = useQuery({
    queryKey: ['job', conversation?.job_id],
    queryFn: async () => {
      if (!conversation?.job_id) return null;
      
      const { data, error } = await supabase
        .from('jobs')
        .select('*')
        .eq('id', conversation.job_id)
        .single();
      
      if (error) throw error;
      return data;
    },
    enabled: !!conversation?.job_id
  });

  // Get deal details if exists
  const { data: dealData } = useQuery({
    queryKey: ['deal', conversation?.job_id, conversation?.client_id, conversation?.provider_id],
    queryFn: async () => {
      if (!conversation) return null;
      
      const { data, error } = await supabase
        .from('deals')
        .select('*')
        .eq('job_id', conversation.job_id)
        .eq('client_id', conversation.client_id)
        .eq('provider_id', conversation.provider_id)
        .maybeSingle();
      
      if (error && error.code !== 'PGRST116') throw error;
      return data;
    },
    enabled: !!conversation
  });

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    if (messages.length > 0) {
      scrollToBottom();
    }
  }, [messages.length]);

  const handleSendMessage = async (
    content: string, 
    messageType: string = 'text', 
    attachmentUrl?: string, 
    negotiationData?: any
  ) => {
    try {
      await sendMessage.mutateAsync({
        conversationId,
        content,
        messageType,
        attachmentUrl,
        negotiationData
      });
    } catch (error) {
      console.error('Failed to send message:', error);
      toast({
        title: "Error",
        description: "Failed to send message. Please try again.",
        variant: "destructive",
      });
    }
  };

  const handleSendOffer = async (offerData: OfferData) => {
    try {
      const negotiationData = {
        type: 'offer',
        serviceDescription: offerData.serviceDescription,
        proposedCost: offerData.proposedCost,
        serviceDate: offerData.serviceDate,
        serviceTime: offerData.serviceTime,
        additionalNotes: offerData.additionalNotes,
        status: 'pending'
      };

      await handleSendMessage(
        `Sent an offer: ${offerData.serviceDescription} - ৳${offerData.proposedCost}`, 
        'negotiation', 
        offerData.attachmentUrl,
        negotiationData
      );
      
      toast({
        title: "Offer Sent!",
        description: "Your custom offer has been sent successfully.",
      });
    } catch (error) {
      console.error('Failed to send offer:', error);
      toast({
        title: "Error",
        description: "Failed to send offer. Please try again.",
        variant: "destructive",
      });
    }
  };

  const handleAcceptOffer = async (messageId: string) => {
    try {
      const message = messages.find(m => m.id === messageId);
      if (!message || !conversation) return;

      const offerData = message.negotiation_data;
      
      // Create the deal directly without creating a proposal first
      await createDeal.mutateAsync({
        jobId: conversation.job_id,
        clientId: conversation.client_id,
        providerId: conversation.provider_id,
        proposalId: null, // We'll set this to null since this is a chat-based deal
        agreedAmount: offerData.proposedCost
      });

      // Update the message status
      await supabase
        .from('messages')
        .update({ 
          negotiation_data: { 
            ...offerData, 
            status: 'accepted' 
          } 
        })
        .eq('id', messageId);

      // Send confirmation message
      await handleSendMessage(
        `✅ Offer accepted! Deal created for ৳${offerData.proposedCost}`,
        'text'
      );
      
      toast({
        title: "Deal Created!",
        description: `Offer accepted for ৳${offerData.proposedCost}. You can view it in your deals section.`,
      });
    } catch (error) {
      console.error('Error accepting offer:', error);
      toast({
        title: "Error",
        description: "Failed to accept offer. Please try again.",
        variant: "destructive",
      });
    }
  };

  const handleRejectOffer = async (messageId: string) => {
    try {
      const message = messages.find(m => m.id === messageId);
      if (!message) return;

      const offerData = message.negotiation_data;
      
      // Update the message status
      await supabase
        .from('messages')
        .update({ 
          negotiation_data: { 
            ...offerData, 
            status: 'rejected' 
          } 
        })
        .eq('id', messageId);

      // Send rejection message
      await handleSendMessage(
        `❌ Offer rejected. Feel free to send a new offer or continue the discussion.`,
        'text'
      );
      
      toast({
        title: "Offer Rejected",
        description: "The offer has been rejected.",
      });
    } catch (error) {
      console.error('Error rejecting offer:', error);
      toast({
        title: "Error",
        description: "Failed to reject offer. Please try again.",
        variant: "destructive",
      });
    }
  };

  const getUserType = () => {
    if (!conversation || !user) return 'User';
    return user.id === conversation.client_id ? 'Customer' : 'Provider';
  };

  const getOtherUserType = () => {
    if (!conversation || !user) return 'User';
    return user.id === conversation.client_id ? 'Provider' : 'Customer';
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[500px] h-[600px] flex flex-col">
        <DialogHeader className="border-b pb-4">
          <DialogTitle className="flex items-center gap-3">
            <MessageCircle className="h-5 w-5" />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span>{otherParticipant.name}</span>
                <Badge variant="outline" className="text-xs flex items-center gap-1">
                  <User className="h-3 w-3" />
                  {getOtherUserType()}
                </Badge>
              </div>
              <div className="flex items-center gap-2 mt-1">
                <Briefcase className="h-3 w-3 text-muted-foreground" />
                <p className="text-sm text-muted-foreground font-normal">
                  {jobTitle}
                </p>
              </div>
            </div>
          </DialogTitle>
        </DialogHeader>
        
        <div className="flex-1 flex flex-col min-h-0">
          <div className="flex-1 overflow-y-auto p-4">
            {isLoading ? (
              <div className="text-center text-muted-foreground">
                Loading messages...
              </div>
            ) : messages.length === 0 ? (
              <div className="text-center text-muted-foreground py-8">
                <MessageCircle className="h-12 w-12 mx-auto mb-2 opacity-50" />
                <p>No messages yet. Start the conversation!</p>
              </div>
            ) : (
              <MessageList 
                messages={messages} 
                currentUserId={user?.id || ''} 
                onSendOffer={handleSendOffer}
                onAcceptOffer={handleAcceptOffer}
                onRejectOffer={handleRejectOffer}
                jobId={conversation?.job_id}
                clientId={conversation?.client_id}
                providerId={conversation?.provider_id}
                jobData={jobData}
                dealData={dealData}
              />
            )}
            <div ref={messagesEndRef} />
          </div>
          
          <div className="border-t p-4">
            <MessageInput 
              onSendMessage={handleSendMessage}
              onSendOffer={handleSendOffer}
              disabled={sendMessage.isPending}
              showOfferButton={!dealData} // Hide offer button if deal exists
              conversationId={conversationId}
            />
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default ChatDialog;
