import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { useEffect } from 'react';

export interface Conversation {
  id: string;
  job_id: string;
  client_id: string;
  provider_id: string;
  proposal_id?: string;
  deal_id?: string;
  status: string;
  created_at: string;
  updated_at: string;
  jobs?: any;
  client_profile?: any;
  provider_profile?: any;
}

export interface Message {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  message_type: string;
  attachment_url?: string;
  negotiation_data?: any;
  read_at?: string;
  created_at: string;
  sender_profile?: any;
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
      
      if (error) throw error;
      return data as Conversation[];
    },
    enabled: !!user
  });
};

export const useMessages = (conversationId: string) => {
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: ['messages', conversationId],
    queryFn: async () => {
      if (!conversationId) return [];
      
      const { data, error } = await supabase
        .from('messages')
        .select(`
          *,
          sender_profile:profiles!messages_sender_id_fkey(full_name, avatar_url)
        `)
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: true });
      
      if (error) throw error;
      return data as Message[];
    },
    enabled: !!conversationId
  });

  // Set up real-time subscription
  useEffect(() => {
    if (!conversationId) return;

    const channel = supabase
      .channel(`messages-${conversationId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `conversation_id=eq.${conversationId}`
        },
        (payload) => {
          queryClient.invalidateQueries({ queryKey: ['messages', conversationId] });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [conversationId, queryClient]);

  return query;
};

export const useCreateConversation = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ 
      jobId, 
      clientId, 
      providerId, 
      proposalId 
    }: { 
      jobId: string; 
      clientId: string; 
      providerId: string; 
      proposalId?: string; 
    }) => {
      const { data, error } = await supabase
        .from('conversations')
        .insert({
          job_id: jobId,
          client_id: clientId,
          provider_id: providerId,
          proposal_id: proposalId
        })
        .select()
        .single();
      
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
    }
  });
};

export const useSendMessage = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ 
      conversationId, 
      content, 
      messageType = 'text',
      attachmentUrl,
      negotiationData
    }: { 
      conversationId: string; 
      content: string; 
      messageType?: string;
      attachmentUrl?: string;
      negotiationData?: any;
    }) => {
      const { data, error } = await supabase
        .from('messages')
        .insert({
          conversation_id: conversationId,
          content,
          message_type: messageType,
          attachment_url: attachmentUrl,
          negotiation_data: negotiationData,
          sender_id: (await supabase.auth.getUser()).data.user?.id
        })
        .select()
        .single();
      
      if (error) throw error;
      return data;
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['messages', variables.conversationId] });
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
    }
  });
};

export const useGetOrCreateConversation = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ 
      jobId, 
      clientId, 
      providerId, 
      proposalId 
    }: { 
      jobId: string; 
      clientId: string; 
      providerId: string; 
      proposalId?: string; 
    }) => {
      // First try to find existing conversation
      const { data: existing, error: searchError } = await supabase
        .from('conversations')
        .select('*')
        .eq('job_id', jobId)
        .eq('client_id', clientId)
        .eq('provider_id', providerId)
        .maybeSingle();
      
      if (searchError) throw searchError;
      
      if (existing) {
        return existing;
      }
      
      // Create new conversation if none exists
      const { data: newConversation, error: createError } = await supabase
        .from('conversations')
        .insert({
          job_id: jobId,
          client_id: clientId,
          provider_id: providerId,
          proposal_id: proposalId
        })
        .select()
        .single();
      
      if (createError) throw createError;
      return newConversation;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
    }
  });
};