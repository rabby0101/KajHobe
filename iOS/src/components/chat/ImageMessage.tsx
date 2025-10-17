import React from 'react';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { formatDistanceToNow } from 'date-fns';
import { Message } from '@/hooks/useConversations';

interface ImageMessageProps {
  message: Message;
  isOwnMessage: boolean;
}

const ImageMessage: React.FC<ImageMessageProps> = ({ message, isOwnMessage }) => {
  return (
    <div className={`flex gap-3 ${isOwnMessage ? 'flex-row-reverse' : 'flex-row'}`}>
      <Avatar className="h-8 w-8 flex-shrink-0">
        <AvatarImage src={message.sender_profile?.avatar_url} />
        <AvatarFallback>
          {message.sender_profile?.full_name?.charAt(0)?.toUpperCase() || 'U'}
        </AvatarFallback>
      </Avatar>
      
      <div className={`flex flex-col max-w-[70%] ${isOwnMessage ? 'items-end' : 'items-start'}`}>
        <div
          className={`rounded-lg overflow-hidden ${
            isOwnMessage
              ? 'bg-primary/10'
              : 'bg-muted'
          }`}
        >
          <img
            src={message.attachment_url || ''}
            alt="Shared image"
            className="max-w-full h-auto max-h-64 object-cover cursor-pointer hover:opacity-90 transition-opacity"
            onClick={() => window.open(message.attachment_url || '', '_blank')}
          />
          {message.content && (
            <div className={`px-3 py-2 ${
              isOwnMessage
                ? 'text-primary-foreground'
                : 'text-muted-foreground'
            }`}>
              <p className="text-sm">{message.content}</p>
            </div>
          )}
        </div>
        
        <span className="text-xs text-muted-foreground mt-1">
          {formatDistanceToNow(new Date(message.created_at), { addSuffix: true })}
        </span>
      </div>
    </div>
  );
};

export default ImageMessage;