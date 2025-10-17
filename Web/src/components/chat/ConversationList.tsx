import React from 'react';
import { useConversations, Conversation } from '@/hooks/useConversations';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { formatDistanceToNow } from 'date-fns';

interface ConversationListProps {
  onSelectConversation: (conversation: Conversation) => void;
  selectedConversationId?: string;
}

const ConversationList: React.FC<ConversationListProps> = ({
  onSelectConversation,
  selectedConversationId,
}) => {
  const { user } = useAuth();
  const { data: conversations = [], isLoading } = useConversations();

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

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map(n => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Conversations</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-4">Loading conversations...</div>
        </CardContent>
      </Card>
    );
  }

  if (conversations.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Conversations</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8 text-muted-foreground">
            <p>No conversations yet.</p>
            <p className="text-sm">Start a conversation from a job proposal!</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Conversations ({conversations.length})</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <div className="space-y-1">
          {conversations.map((conversation) => {
            const otherParticipant = getOtherParticipant(conversation);
            const isSelected = conversation.id === selectedConversationId;

            return (
              <div
                key={conversation.id}
                className={`p-4 cursor-pointer hover:bg-muted transition-colors border-b last:border-b-0 ${
                  isSelected ? 'bg-muted' : ''
                }`}
                onClick={() => onSelectConversation(conversation)}
              >
                <div className="flex items-start gap-3">
                  <Avatar className="h-10 w-10">
                    <AvatarImage src={otherParticipant.avatar_url} />
                    <AvatarFallback>{getInitials(otherParticipant.name)}</AvatarFallback>
                  </Avatar>
                  
                  <div className="flex-1 min-w-0">
                    <div className="flex justify-between items-start">
                      <div>
                        <p className="font-semibold text-sm">{otherParticipant.name}</p>
                        <p className="text-xs text-muted-foreground truncate">
                          {conversation.jobs?.title}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-xs text-muted-foreground">
                          {formatDistanceToNow(new Date(conversation.updated_at), { addSuffix: true })}
                        </p>
                        {conversation.deal_id && (
                          <Badge variant="secondary" className="text-xs mt-1">
                            Deal Active
                          </Badge>
                        )}
                      </div>
                    </div>
                    
                    {conversation.last_message && (
                      <p className="text-sm text-muted-foreground mt-1 truncate">
                        {conversation.last_message.content}
                      </p>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
};

export default ConversationList;