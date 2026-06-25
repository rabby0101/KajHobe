import React, { useState, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import Header from '@/components/Header';
import { Conversation, isConversationArchivedFor, useArchiveConversation } from '@/hooks/useConversations';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar';
import { Search, MessageSquare, RefreshCw, Send, Phone, Video, Info, ArrowLeft, DollarSign, Archive, ArchiveRestore } from 'lucide-react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';
import { useConversationMessages, useSendMessage } from '@/hooks/useConversations';
import { formatDistanceToNow } from 'date-fns';
import MessageList from '@/components/chat/MessageList';
import OfferForm, { OfferData } from '@/components/chat/OfferForm';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { useMyDeals } from '@/hooks/useDeals';
import { useSendDealOffer } from '@/hooks/useDealOffers';

const Messages = () => {
  const { user } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [selectedConversation, setSelectedConversation] = useState<Conversation | null>(null);
  const [searchText, setSearchText] = useState('');
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [newMessage, setNewMessage] = useState('');
  const [isMobile, setIsMobile] = useState(false);
  const [showOfferForm, setShowOfferForm] = useState(false);
  const [isProvider, setIsProvider] = useState(false);
  const [showArchived, setShowArchived] = useState(false);
  const archiveConversation = useArchiveConversation();

  const toggleArchive = (e: React.MouseEvent, conversation: Conversation) => {
    e.stopPropagation();
    const archived = isConversationArchivedFor(conversation, user?.id);
    archiveConversation.mutate({ conversation, archived: !archived });
    if (selectedConversation?.id === conversation.id) setSelectedConversation(null);
  };

  // Check if mobile
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // Fetch conversations with real-time updates
  const { data: conversations = [], isLoading, refetch } = useQuery({
    queryKey: ['conversations', user?.id],
    queryFn: async () => {
      try {
        if (!user?.id) return [];
        
        console.log('Fetching conversations...');
        const { data, error } = await supabase
          .from('conversations')
          .select(`
            *,
            jobs:job_id(title),
            client_profile:client_id(full_name, avatar_url),
            provider_profile:provider_id(full_name, avatar_url)
          `)
          .or(`client_id.eq.${user.id},provider_id.eq.${user.id}`)
          .order('updated_at', { ascending: false });
        
        if (error) {
          console.error('Error fetching conversations:', error);
          return [];
        }
        
        console.log('Conversations fetched:', data);
        return (data || []) as Conversation[];
      } catch (error) {
        console.error('Conversations error:', error);
        return [];
      }
    },
    enabled: !!user?.id,
    retry: 1,
    staleTime: 30000, // 30 seconds
    refetchInterval: 30000, // Refetch every 30 seconds
    refetchOnWindowFocus: true,
  });

  // Fetch messages for selected conversation
  const { data: messages = [], refetch: refetchMessages } = useConversationMessages(selectedConversation?.id || '');
  const sendMessage = useSendMessage();
  const sendDealOffer = useSendDealOffer();
  const { data: deals } = useMyDeals();

  // Check if user is provider for current conversation
  useEffect(() => {
    if (selectedConversation && user) {
      setIsProvider(selectedConversation.provider_id === user.id);
    }
  }, [selectedConversation, user]);

  // Helper function to check if deal is completed or if offers should be disabled
  const canSendOffer = () => {
    if (!selectedConversation || !isProvider) return false;
    
    // Check if there's a deal for this conversation
    const conversationDeal = deals?.find(deal => 
      deal.job_id === selectedConversation.job_id &&
      (deal.client_id === selectedConversation.client_id || deal.provider_id === selectedConversation.provider_id)
    );
    
    // If there's a deal and it's completed, don't allow new offers
    if (conversationDeal && conversationDeal.status === 'completed') {
      return false;
    }
    
    // Check if there are any pending offers in messages
    const hasPendingOffer = messages.some(message => 
      message.negotiation_data && 
      message.negotiation_data.status === 'pending' &&
      message.sender_id === user?.id
    );
    
    // Don't allow new offers if there's already a pending offer from this provider
    if (hasPendingOffer) {
      return false;
    }
    
    return true;
  };

  // Helper function to get the reason why offers are disabled
  const getOfferDisabledReason = () => {
    if (!selectedConversation || !isProvider) return null;
    
    const conversationDeal = deals?.find(deal => 
      deal.job_id === selectedConversation.job_id &&
      (deal.client_id === selectedConversation.client_id || deal.provider_id === selectedConversation.provider_id)
    );
    
    if (conversationDeal && conversationDeal.status === 'completed') {
      return "Deal completed";
    }
    
    const hasPendingOffer = messages.some(message => 
      message.negotiation_data && 
      message.negotiation_data.status === 'pending' &&
      message.sender_id === user?.id
    );
    
    if (hasPendingOffer) {
      return "Offer pending";
    }
    
    return null;
  };

  // Mark messages as read when conversation is selected
  useEffect(() => {
    const markMessagesAsRead = async () => {
      if (!selectedConversation?.id || !user?.id) return;

      try {
        // Mark all unread messages in this conversation as read
        const { error } = await supabase
          .from('messages')
          .update({ read_at: new Date().toISOString() })
          .eq('conversation_id', selectedConversation.id)
          .neq('sender_id', user.id) // Only mark messages not sent by current user
          .is('read_at', null); // Only mark messages that haven't been read yet

        if (error) {
          console.error('Error marking messages as read:', error);
        } else {
          console.log('Messages marked as read for conversation:', selectedConversation.id);
          // Refresh unread count after marking messages as read
          queryClient.invalidateQueries({ queryKey: ['unread-messages'] });
        }
      } catch (error) {
        console.error('Error in markMessagesAsRead:', error);
      }
    };

    // Add a small delay to ensure the conversation is fully loaded
    const timer = setTimeout(() => {
      markMessagesAsRead();
    }, 500);

    return () => clearTimeout(timer);
  }, [selectedConversation?.id, user?.id]);

  // Helper functions
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

  // Handle sending message
  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !selectedConversation) return;

    try {
      await sendMessage.mutateAsync({
        conversation_id: selectedConversation.id,
        content: newMessage.trim(),
      });
      setNewMessage('');
      refetchMessages();
      // Refresh unread count after sending message
      queryClient.invalidateQueries({ queryKey: ['unread-messages'] });
    } catch (error) {
      console.error('Failed to send message:', error);
      toast({
        title: "Error",
        description: "Failed to send message",
        variant: "destructive",
      });
    }
  };

  // Handle refresh
  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      await refetch();
      if (selectedConversation) {
        await refetchMessages();
      }
      toast({
        title: "Messages refreshed",
        description: "Latest conversations loaded",
      });
    } catch (error) {
      toast({
        title: "Refresh failed",
        description: "Could not refresh messages",
        variant: "destructive",
      });
    } finally {
      setIsRefreshing(false);
    }
  };

  // Split by the current user's archive flag, then filter by search.
  const archivedCount = conversations.filter(c => isConversationArchivedFor(c, user?.id)).length;
  const filteredConversations = conversations.filter(conversation => {
    if (isConversationArchivedFor(conversation, user?.id) !== showArchived) return false;
    if (!searchText) return true;
    const otherParticipant = getOtherParticipant(conversation);
    const jobTitle = conversation.jobs?.title || '';
    const searchLower = searchText.toLowerCase();
    return (
      otherParticipant.name.toLowerCase().includes(searchLower) ||
      jobTitle.toLowerCase().includes(searchLower)
    );
  });

  // Handle sending offer
  const handleSendOffer = async (offerData: OfferData) => {
    if (!selectedConversation || !user) return;

    try {
      // Send in the cross-platform `deal_offer` format (deal_offers row + linked
      // message) so it renders on iOS/Android and supports Accept & Pay (escrow).
      await sendDealOffer.mutateAsync({
        conversationId: selectedConversation.id,
        jobId: selectedConversation.job_id,
        clientId: selectedConversation.client_id,
        providerId: selectedConversation.provider_id,
        amount: offerData.amount,
        terms: offerData.terms,
        timeline: offerData.timeline,
        additionalMessage: offerData.additionalMessage,
      });

      setShowOfferForm(false);
      refetchMessages();
      queryClient.invalidateQueries({ queryKey: ['unread-messages'] });

      toast({
        title: "Offer sent",
        description: "Your offer has been sent successfully",
      });
    } catch (error) {
      console.error('Error sending offer:', error);
      toast({
        title: "Error",
        description: "Failed to send offer",
        variant: "destructive",
      });
    }
  };

  // Handle accepting offer
  const handleAcceptOffer = async (messageId: string) => {
    try {
      const { error } = await supabase
        .from('messages')
        .update({ 
          negotiation_data: { 
            ...messages.find(m => m.id === messageId)?.negotiation_data,
            status: 'accepted' 
          } 
        })
        .eq('id', messageId);

      if (error) throw error;

      refetchMessages();
      toast({
        title: "Offer accepted",
        description: "The offer has been accepted",
      });
    } catch (error) {
      console.error('Error accepting offer:', error);
      toast({
        title: "Error",
        description: "Failed to accept offer",
        variant: "destructive",
      });
    }
  };

  // Handle rejecting offer
  const handleRejectOffer = async (messageId: string) => {
    try {
      const { error } = await supabase
        .from('messages')
        .update({ 
          negotiation_data: { 
            ...messages.find(m => m.id === messageId)?.negotiation_data,
            status: 'rejected' 
          } 
        })
        .eq('id', messageId);

      if (error) throw error;

      refetchMessages();
      toast({
        title: "Offer rejected",
        description: "The offer has been rejected",
      });
    } catch (error) {
      console.error('Error rejecting offer:', error);
      toast({
        title: "Error",
        description: "Failed to reject offer",
        variant: "destructive",
      });
    }
  };

  // Disable real-time subscriptions temporarily to fix multiple subscription issues
  // Auto-refresh functionality will handle updates instead
  // useEffect(() => {
  //   if (!user?.id) return;
  //   console.log('Real-time messages disabled to prevent subscription issues');
  // }, [user?.id, refetch, selectedConversation, refetchMessages, queryClient]);

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

  // Mobile view - show conversation list or chat
  if (isMobile) {
    return (
      <div className="h-screen bg-background">
        <Header />
        <div className="flex flex-col h-[calc(100vh-64px)]">
        
        {selectedConversation ? (
          // Mobile Chat View
          <div className="flex-1 flex flex-col">
            {/* Chat Header */}
            <div className="flex items-center justify-between p-4 border-b bg-card">
              <div className="flex items-center space-x-3">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setSelectedConversation(null)}
                >
                  <ArrowLeft className="h-4 w-4" />
                </Button>
                <Avatar className="h-8 w-8">
                  <AvatarImage src={getOtherParticipant(selectedConversation).avatar_url} />
                  <AvatarFallback>{getInitials(getOtherParticipant(selectedConversation).name)}</AvatarFallback>
                </Avatar>
                <div>
                  <div className="font-semibold text-sm">{getOtherParticipant(selectedConversation).name}</div>
                  <div className="text-xs text-muted-foreground">{selectedConversation.jobs?.title}</div>
                </div>
              </div>
              <div className="flex items-center space-x-2">
                <Button variant="ghost" size="sm">
                  <Phone className="h-4 w-4" />
                </Button>
                <Button variant="ghost" size="sm">
                  <Video className="h-4 w-4" />
                </Button>
                <Button variant="ghost" size="sm">
                  <Info className="h-4 w-4" />
                </Button>
              </div>
            </div>
            
            {/* Messages Area */}
            <div className="flex-1 overflow-y-auto p-4 min-h-0">
              {messages.length === 0 ? (
                <div className="text-center text-muted-foreground py-8">
                  <MessageSquare className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
                  <p>No messages yet. Start the conversation!</p>
                </div>
              ) : (
                <MessageList
                  messages={messages}
                  currentUserId={user?.id || ''}
                  onSendOffer={handleSendOffer}
                  onAcceptOffer={handleAcceptOffer}
                  onRejectOffer={handleRejectOffer}
                  jobId={selectedConversation?.job_id}
                  clientId={selectedConversation?.client_id}
                  providerId={selectedConversation?.provider_id}
                  jobData={selectedConversation?.jobs}
                  dealData={deals?.find(deal => deal.job_id === selectedConversation?.job_id)}
                />
              )}
            </div>
            
            {/* Message Input */}
            <div className="p-4 border-t bg-card">
              <div className="flex flex-col space-y-2">
                {/* Offer button for providers */}
                {canSendOffer() ? (
                  <Button
                    onClick={() => setShowOfferForm(true)}
                    variant="outline"
                    size="sm"
                    className="self-start"
                  >
                    <DollarSign className="h-4 w-4 mr-2" />
                    Send Offer
                  </Button>
                ) : isProvider && getOfferDisabledReason() && (
                  <div className="text-xs text-muted-foreground self-start px-2 py-1 bg-muted rounded">
                    {getOfferDisabledReason()}
                  </div>
                )}
                
                <form onSubmit={handleSendMessage} className="flex space-x-2">
                  <Input
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    placeholder="Type a message..."
                    className="flex-1"
                    disabled={sendMessage.isPending}
                  />
                  <Button 
                    type="submit" 
                    disabled={!newMessage.trim() || sendMessage.isPending}
                    size="sm"
                  >
                    <Send className="h-4 w-4" />
                  </Button>
                </form>
              </div>
            </div>
          </div>
        ) : (
          // Mobile Conversation List
          <div className="flex-1 flex flex-col">
            {/* Header */}
            <div className="flex items-center justify-between p-4 border-b bg-card">
              <div className="flex items-center space-x-2">
                <MessageSquare className="h-6 w-6 text-primary" />
                <h1 className="text-lg font-semibold">Messages</h1>
                {conversations.length > 0 && (
                  <Badge variant="secondary" className="text-xs">
                    {conversations.length}
                  </Badge>
                )}
              </div>
              <div className="flex items-center gap-1">
                <Button
                  onClick={() => setShowArchived(v => !v)}
                  size="sm"
                  variant={showArchived ? 'secondary' : 'ghost'}
                  title={showArchived ? 'Show active' : 'Show archived'}
                >
                  <Archive className="h-4 w-4 mr-1" />
                  {showArchived ? 'Active' : `Archived${archivedCount ? ` (${archivedCount})` : ''}`}
                </Button>
                <Button
                  onClick={handleRefresh}
                  disabled={isRefreshing}
                  size="sm"
                  variant="ghost"
                >
                  <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
                </Button>
              </div>
            </div>

            {/* Search */}
            <div className="p-4 border-b bg-card">
              <div className="relative">
                <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search conversations..."
                  value={searchText}
                  onChange={(e) => setSearchText(e.target.value)}
                  className="pl-10"
                />
              </div>
            </div>
            
            {/* Conversations */}
            <div className="flex-1 overflow-y-auto">
              {isLoading ? (
                <div className="text-center py-8">
                  <RefreshCw className="h-6 w-6 animate-spin mx-auto mb-2" />
                  <p className="text-muted-foreground">Loading conversations...</p>
                </div>
              ) : filteredConversations.length === 0 ? (
                <div className="text-center py-12">
                  <MessageSquare className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
                  <p className="text-muted-foreground">
                    {showArchived ? 'No archived conversations' : 'No conversations yet'}
                  </p>
                  {!showArchived && (
                    <p className="text-sm text-muted-foreground">Start a conversation from a job proposal!</p>
                  )}
                </div>
              ) : (
                filteredConversations.map((conversation) => {
                  const otherParticipant = getOtherParticipant(conversation);
                  return (
                    <div
                      key={conversation.id}
                      className="group flex items-center space-x-3 p-4 hover:bg-muted/50 cursor-pointer border-b"
                      onClick={() => setSelectedConversation(conversation)}
                    >
                      <Avatar className="h-12 w-12">
                        <AvatarImage src={otherParticipant.avatar_url} />
                        <AvatarFallback>{getInitials(otherParticipant.name)}</AvatarFallback>
                      </Avatar>
                      <div className="flex-1 min-w-0">
                        <div className="flex justify-between items-start">
                          <div className="flex-1 min-w-0">
                            <p className="font-semibold text-sm truncate">{otherParticipant.name}</p>
                            <p className="text-xs text-muted-foreground truncate">{conversation.jobs?.title}</p>
                          </div>
                          <div className="text-right ml-2">
                            <p className="text-xs text-muted-foreground">
                              {formatDistanceToNow(new Date(conversation.updated_at), { addSuffix: true })}
                            </p>
                            {conversation.deal_id && (
                              <Badge variant="secondary" className="text-xs mt-1">
                                Deal
                              </Badge>
                            )}
                          </div>
                        </div>
                      </div>
                      <Button
                        size="icon"
                        variant="ghost"
                        className="h-8 w-8 shrink-0"
                        title={showArchived ? 'Restore' : 'Archive'}
                        onClick={(e) => toggleArchive(e, conversation)}
                      >
                        {showArchived ? <ArchiveRestore className="h-4 w-4" /> : <Archive className="h-4 w-4" />}
                      </Button>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        )}
        </div>
      </div>
    );
  }

  // Desktop view - show both conversation list and chat
  return (
    <div className="h-screen bg-background">
      <Header />
      <div className="flex h-[calc(100vh-64px)]">
        {/* Left Sidebar - Conversations */}
        <div className="w-80 border-r bg-card flex flex-col">
          {/* Header */}
          <div className="flex items-center justify-between p-4 border-b">
            <div className="flex items-center space-x-2">
              <MessageSquare className="h-5 w-5 text-primary" />
              <h1 className="text-lg font-semibold">Messages</h1>
              {conversations.length > 0 && (
                <Badge variant="secondary" className="text-xs">
                  {conversations.length}
                </Badge>
              )}
            </div>
            <div className="flex items-center gap-1">
              <Button
                onClick={() => setShowArchived(v => !v)}
                size="sm"
                variant={showArchived ? 'secondary' : 'ghost'}
                title={showArchived ? 'Show active' : 'Show archived'}
              >
                <Archive className="h-4 w-4 mr-1" />
                {showArchived ? 'Active' : `Archived${archivedCount ? ` (${archivedCount})` : ''}`}
              </Button>
              <Button
                onClick={handleRefresh}
                disabled={isRefreshing}
                size="sm"
                variant="ghost"
              >
                <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
              </Button>
            </div>
          </div>

          {/* Search */}
          <div className="p-4 border-b">
            <div className="relative">
              <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search conversations..."
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
                className="pl-10"
              />
            </div>
          </div>
          
          {/* Conversations List */}
          <div className="flex-1 overflow-y-auto">
            {isLoading ? (
              <div className="text-center py-8">
                <RefreshCw className="h-6 w-6 animate-spin mx-auto mb-2" />
                <p className="text-muted-foreground">Loading conversations...</p>
              </div>
            ) : filteredConversations.length === 0 ? (
              <div className="text-center py-12">
                <MessageSquare className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
                <p className="text-muted-foreground">
                  {showArchived ? 'No archived conversations' : 'No conversations yet'}
                </p>
                {!showArchived && (
                  <p className="text-sm text-muted-foreground">Start a conversation from a job proposal!</p>
                )}
              </div>
            ) : (
              filteredConversations.map((conversation) => {
                const otherParticipant = getOtherParticipant(conversation);
                const isSelected = conversation.id === selectedConversation?.id;

                return (
                  <div
                    key={conversation.id}
                    className={`group flex items-center space-x-3 p-4 hover:bg-muted/50 cursor-pointer border-b ${
                      isSelected ? 'bg-muted' : ''
                    }`}
                    onClick={() => setSelectedConversation(conversation)}
                  >
                    <Avatar className="h-12 w-12">
                      <AvatarImage src={otherParticipant.avatar_url} />
                      <AvatarFallback>{getInitials(otherParticipant.name)}</AvatarFallback>
                    </Avatar>
                    <div className="flex-1 min-w-0">
                      <div className="flex justify-between items-start">
                        <div className="flex-1 min-w-0">
                          <p className="font-semibold text-sm truncate">{otherParticipant.name}</p>
                          <p className="text-xs text-muted-foreground truncate">{conversation.jobs?.title}</p>
                        </div>
                        <div className="text-right ml-2">
                          <p className="text-xs text-muted-foreground">
                            {formatDistanceToNow(new Date(conversation.updated_at), { addSuffix: true })}
                          </p>
                          {conversation.deal_id && (
                            <Badge variant="secondary" className="text-xs mt-1">
                              Deal
                            </Badge>
                          )}
                        </div>
                      </div>
                    </div>
                    <Button
                      size="icon"
                      variant="ghost"
                      className="h-8 w-8 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity"
                      title={showArchived ? 'Restore' : 'Archive'}
                      onClick={(e) => toggleArchive(e, conversation)}
                    >
                      {showArchived ? <ArchiveRestore className="h-4 w-4" /> : <Archive className="h-4 w-4" />}
                    </Button>
                  </div>
                );
              })
            )}
          </div>
        </div>
        
        {/* Right Side - Chat Area */}
        <div className="flex-1 flex flex-col">
          {selectedConversation ? (
            <>
              {/* Chat Header */}
              <div className="flex items-center justify-between p-4 border-b bg-card">
                <div className="flex items-center space-x-3">
                  <Avatar className="h-10 w-10">
                    <AvatarImage src={getOtherParticipant(selectedConversation).avatar_url} />
                    <AvatarFallback>{getInitials(getOtherParticipant(selectedConversation).name)}</AvatarFallback>
                  </Avatar>
                  <div>
                    <div className="font-semibold">{getOtherParticipant(selectedConversation).name}</div>
                    <div className="text-sm text-muted-foreground">{selectedConversation.jobs?.title}</div>
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <Button variant="ghost" size="sm">
                    <Phone className="h-4 w-4" />
                  </Button>
                  <Button variant="ghost" size="sm">
                    <Video className="h-4 w-4" />
                  </Button>
                  <Button variant="ghost" size="sm">
                    <Info className="h-4 w-4" />
                  </Button>
                </div>
              </div>
              
              {/* Messages Area */}
              <div className="flex-1 overflow-y-auto p-4 min-h-0">
                {messages.length === 0 ? (
                  <div className="text-center text-muted-foreground py-12">
                    <MessageSquare className="h-16 w-16 mx-auto mb-4 text-muted-foreground" />
                    <p>No messages yet. Start the conversation!</p>
                  </div>
                ) : (
                  <MessageList
                    messages={messages}
                    currentUserId={user?.id || ''}
                    onSendOffer={handleSendOffer}
                    onAcceptOffer={handleAcceptOffer}
                    onRejectOffer={handleRejectOffer}
                    jobId={selectedConversation?.job_id}
                    clientId={selectedConversation?.client_id}
                    providerId={selectedConversation?.provider_id}
                    jobData={selectedConversation?.jobs}
                    dealData={deals?.find(deal => deal.job_id === selectedConversation?.job_id)}
                  />
                )}
              </div>
              
              {/* Message Input */}
              <div className="p-4 border-t bg-card">
                <div className="flex flex-col space-y-2">
                  {/* Offer button for providers */}
                  {canSendOffer() ? (
                    <Button
                      onClick={() => setShowOfferForm(true)}
                      variant="outline"
                      size="sm"
                      className="self-start"
                    >
                      <DollarSign className="h-4 w-4 mr-2" />
                      Send Offer
                    </Button>
                  ) : isProvider && getOfferDisabledReason() && (
                    <div className="text-xs text-muted-foreground self-start px-2 py-1 bg-muted rounded">
                      {getOfferDisabledReason()}
                    </div>
                  )}
                  
                  <form onSubmit={handleSendMessage} className="flex space-x-2">
                    <Input
                      value={newMessage}
                      onChange={(e) => setNewMessage(e.target.value)}
                      placeholder="Type a message..."
                      className="flex-1"
                      disabled={sendMessage.isPending}
                    />
                    <Button 
                      type="submit" 
                      disabled={!newMessage.trim() || sendMessage.isPending}
                    >
                      <Send className="h-4 w-4 mr-2" />
                      Send
                    </Button>
                  </form>
                </div>
              </div>
            </>
          ) : (
            // No conversation selected
            <div className="flex-1 flex items-center justify-center bg-muted/20">
              <div className="text-center">
                <MessageSquare className="h-20 w-20 text-muted-foreground mx-auto mb-4" />
                <h3 className="text-xl font-semibold mb-2">Select a conversation</h3>
                <p className="text-muted-foreground">
                  Choose a conversation from the list to start chatting
                </p>
              </div>
            </div>
          )}
        </div>
      </div>
      
      {/* Offer Form Dialog */}
      <Dialog open={showOfferForm} onOpenChange={setShowOfferForm}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Send Custom Offer</DialogTitle>
          </DialogHeader>
          <OfferForm
            onSubmit={handleSendOffer}
            onCancel={() => setShowOfferForm(false)}
            isLoading={sendMessage.isPending}
          />
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default Messages;