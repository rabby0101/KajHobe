import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { toast } from '@/hooks/use-toast';

export interface Conversation {
  id: string;
  job_id: string;
  client_id: string;
  provider_id: string;
  proposal_id: string | null;
  deal_id: string | null;
  status: string;
  created_at: string;
  updated_at: string;
  jobs?: any;
  client_profile?: any;
  provider_profile?: any;
  last_message?: any;
}

export interface Message {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  message_type: string;
  attachment_url?: string | null;
  read_at?: string | null;
  created_at: string;
  sender_profile?: any;
  negotiation_data?: any;
  original_proposal_id?: string | null;
}

export const useConversations = () => {
  const { user } = useAuth();

  return useQuery({
    queryKey: ['conversations', user?.id],
    queryFn: async () => {
      if (!user) return [];
      
      const { data, error } = await supabase
        .from('conversations')
        .select(`
          *,
          jobs(title, category),
          client_profile:profiles!conversations_client_id_fkey(full_name, avatar_url),
          provider_profile:profiles!conversations_provider_id_fkey(full_name, avatar_url)
        `)
        .or(`client_id.eq.${user.id},provider_id.eq.${user.id}`)
        .order('updated_at', { ascending: false });
      
      if (error) {
        console.error('Error fetching conversations:', error);
        throw error;
      }
      
      return data as Conversation[];
    },
    enabled: !!user
  });
};

export const useConversationMessages = (conversationId: string) => {
  return useQuery({
    queryKey: ['messages', conversationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('messages')
        .select(`
          *,
          sender_profile:profiles!messages_sender_id_fkey(full_name, avatar_url)
        `)
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: true });
      
      if (error) {
        console.error('Error fetching messages:', error);
        throw error;
      }
      
      return data as Message[];
    },
    enabled: !!conversationId
  });
};

export const useCreateConversation = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: {
      job_id: string;
      client_id: string;
      provider_id: string;
      proposal_id?: string;
    }) => {
      // Check if conversation already exists
      const { data: existing } = await supabase
        .from('conversations')
        .select('id')
        .eq('job_id', params.job_id)
        .eq('client_id', params.client_id)
        .eq('provider_id', params.provider_id)
        .maybeSingle();

      if (existing) {
        return existing;
      }

      // Create new conversation
      const { data, error } = await supabase
        .from('conversations')
        .insert([params])
        .select()
        .single();

      if (error) {
        console.error('Error creating conversation:', error);
        throw error;
      }

      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
    }
  });
};

export const useSendMessage = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  return useMutation({
    mutationFn: async (params: {
      conversation_id: string;
      content: string;
      message_type?: string;
      attachment_url?: string;
      negotiation_data?: any;
      original_proposal_id?: string;
    }) => {
      if (!user) throw new Error('Must be logged in to send messages');

      const { data, error } = await supabase
        .from('messages')
        .insert([{
          ...params,
          sender_id: user.id,
          message_type: params.message_type || 'text'
        }])
        .select()
        .single();

      if (error) {
        console.error('Error sending message:', error);
        throw error;
      }

      return data;
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['messages', data.conversation_id] });
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to send message",
        variant: "destructive",
      });
    }
  });
};

export const useSendNegotiationMessage = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  return useMutation({
    mutationFn: async (params: {
      conversationId: string;
      amount: number;
      message: string;
      type: string;
      proposalId?: string;
    }) => {
      if (!user) throw new Error('Must be logged in to send messages');

      let finalProposalId = params.proposalId;

      // If this is a new proposal, create it in the proposals table
      if (params.type === 'proposal' && !params.proposalId) {
        // Get conversation details to get job_id and provider_id
        const { data: conversation } = await supabase
          .from('conversations')
          .select('job_id, provider_id, client_id')
          .eq('id', params.conversationId)
          .single();

        if (conversation) {
          // Determine who is the provider based on who is sending
          const isClientSending = user.id === conversation.client_id;
          const providerId = isClientSending ? conversation.provider_id : user.id;

          // Create the proposal
          const { data: newProposal, error: proposalError } = await supabase
            .from('proposals')
            .insert([{
              job_id: conversation.job_id,
              provider_id: providerId,
              amount: params.amount,
              message: params.message,
              status: 'pending'
            }])
            .select()
            .single();

          if (proposalError) {
            console.error('Error creating proposal:', proposalError);
            throw proposalError;
          }

          finalProposalId = newProposal.id;
        }
      }

      const negotiationData = {
        type: params.type,
        amount: params.amount,
        proposalId: finalProposalId,
        status: 'pending'
      };

      console.log('Sending negotiation with data:', negotiationData);

      const { data, error } = await supabase
        .from('messages')
        .insert([{
          conversation_id: params.conversationId,
          content: params.message,
          message_type: 'negotiation',
          sender_id: user.id,
          negotiation_data: negotiationData,
          original_proposal_id: finalProposalId
        }])
        .select()
        .single();

      if (error) {
        console.error('Error sending negotiation message:', error);
        throw error;
      }

      return data;
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['messages', data.conversation_id] });
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
      queryClient.invalidateQueries({ queryKey: ['proposals'] });
      toast({
        title: "Negotiation Sent",
        description: "Your negotiation message has been sent",
      });
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to send negotiation message",
        variant: "destructive",
      });
    }
  });
};

export const useMarkMessageAsRead = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (messageId: string) => {
      const { error } = await supabase
        .from('messages')
        .update({ read_at: new Date().toISOString() })
        .eq('id', messageId);

      if (error) {
        console.error('Error marking message as read:', error);
        throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['messages'] });
    }
  });
};