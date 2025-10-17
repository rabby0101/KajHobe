import React, { useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import Header from '@/components/Header';
import ConversationList from '@/components/chat/ConversationList';
import ChatInterface from '@/components/chat/ChatInterface';
import { Conversation } from '@/hooks/useConversations';

const Messages = () => {
  const { user } = useAuth();
  const [selectedConversation, setSelectedConversation] = useState<Conversation | null>(null);

  if (!user) {
    return (
      <div className="min-h-screen bg-background">
        <Header />
        <div className="container mx-auto px-4 py-8">
          <div className="text-center">Please sign in to view your messages.</div>
        </div>
      </div>
    );
  }

  const getOtherParticipant = (conversation: Conversation) => {
    if (conversation.client_id === user?.id) {
      return {
        id: conversation.provider_id,
        name: conversation.provider_profile?.full_name || 'Provider',
        avatar_url: conversation.provider_profile?.avatar_url,
      };
    } else {
      return {
        id: conversation.client_id,
        name: conversation.client_profile?.full_name || 'Client',
        avatar_url: conversation.client_profile?.avatar_url,
      };
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold text-foreground mb-8">Messages</h1>
        
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-1">
            <ConversationList
              onSelectConversation={setSelectedConversation}
              selectedConversationId={selectedConversation?.id}
            />
          </div>
          
          <div className="lg:col-span-2">
            {selectedConversation ? (
              <ChatInterface
                conversationId={selectedConversation.id}
                jobTitle={selectedConversation.jobs?.title || 'Job'}
                otherParticipant={getOtherParticipant(selectedConversation)}
              />
            ) : (
              <div className="h-[600px] flex items-center justify-center border rounded-lg bg-muted/50">
                <p className="text-muted-foreground">Select a conversation to start chatting</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Messages;