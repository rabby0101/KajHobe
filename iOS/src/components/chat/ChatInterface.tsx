import React, { useEffect, useState } from 'react';
import { useConversationMessages, useSendMessage, Message } from '@/hooks/useConversations';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar';
import { formatDistanceToNow } from 'date-fns';
import { supabase } from '@/integrations/supabase/client';

interface ChatInterfaceProps {
  conversationId: string;
  jobTitle: string;
  otherParticipant: {
    id: string;
    name: string;
    avatar_url?: string;
  };
}

const ChatInterface: React.FC<ChatInterfaceProps> = ({
  conversationId,
  jobTitle,
  otherParticipant,
}) => {
  const { user } = useAuth();
  const { data: messages = [], refetch } = useConversationMessages(conversationId);
  const sendMessage = useSendMessage();
  const [newMessage, setNewMessage] = useState('');

  // Set up real-time subscription
  useEffect(() => {
    const channel = supabase
      .channel('messages-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `conversation_id=eq.${conversationId}`
        },
        () => {
          refetch();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [conversationId, refetch]);

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim()) return;

    try {
      await sendMessage.mutateAsync({
        conversation_id: conversationId,
        content: newMessage.trim(),
      });
      setNewMessage('');
    } catch (error) {
      console.error('Failed to send message:', error);
    }
  };

  const formatTime = (timestamp: string) => {
    return formatDistanceToNow(new Date(timestamp), { addSuffix: true });
  };

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map(n => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  return (
    <Card className="h-[600px] flex flex-col">
      <CardHeader className="border-b">
        <CardTitle className="flex items-center gap-3">
          <Avatar className="h-8 w-8">
            <AvatarImage src={otherParticipant.avatar_url} />
            <AvatarFallback>{getInitials(otherParticipant.name)}</AvatarFallback>
          </Avatar>
          <div>
            <div className="text-sm font-semibold">{otherParticipant.name}</div>
            <div className="text-xs text-muted-foreground">{jobTitle}</div>
          </div>
        </CardTitle>
      </CardHeader>

      <CardContent className="flex-1 flex flex-col p-0">
        {/* Messages Area */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length === 0 ? (
            <div className="text-center text-muted-foreground py-8">
              <p>No messages yet. Start a conversation!</p>
            </div>
          ) : (
            messages.map((message) => (
              <MessageBubble
                key={message.id}
                message={message}
                isOwnMessage={message.sender_id === user?.id}
                formatTime={formatTime}
              />
            ))
          )}
        </div>

        {/* Message Input */}
        <div className="border-t p-4">
          <form onSubmit={handleSendMessage} className="flex gap-2">
            <Input
              value={newMessage}
              onChange={(e) => setNewMessage(e.target.value)}
              placeholder="Type your message..."
              disabled={sendMessage.isPending}
              className="flex-1"
            />
            <Button 
              type="submit" 
              disabled={!newMessage.trim() || sendMessage.isPending}
            >
              Send
            </Button>
          </form>
        </div>
      </CardContent>
    </Card>
  );
};

interface MessageBubbleProps {
  message: Message;
  isOwnMessage: boolean;
  formatTime: (timestamp: string) => string;
}

const MessageBubble: React.FC<MessageBubbleProps> = ({
  message,
  isOwnMessage,
  formatTime,
}) => {
  return (
    <div className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-[70%] rounded-lg px-3 py-2 ${
          isOwnMessage
            ? 'bg-primary text-primary-foreground'
            : 'bg-muted text-muted-foreground'
        }`}
      >
        <p className="text-sm">{message.content}</p>
        <p className={`text-xs mt-1 ${
          isOwnMessage ? 'text-primary-foreground/70' : 'text-muted-foreground/70'
        }`}>
          {formatTime(message.created_at)}
        </p>
      </div>
    </div>
  );
};

export default ChatInterface;