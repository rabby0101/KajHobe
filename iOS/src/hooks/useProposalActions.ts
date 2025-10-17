
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { toast } from '@/hooks/use-toast';

export const useAcceptProposal = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (proposalId: string) => {
      console.log('Accepting proposal:', proposalId);
      
      // Get proposal details to create deal
      const { data: proposal, error: proposalError } = await supabase
        .from('proposals')
        .select('*, jobs(*)')
        .eq('id', proposalId)
        .single();
      
      if (proposalError) {
        console.error('Error fetching proposal:', proposalError);
        throw proposalError;
      }
      
      // Update proposal status to accepted
      const { error } = await supabase
        .from('proposals')
        .update({ status: 'accepted' })
        .eq('id', proposalId);
      
      if (error) {
        console.error('Error accepting proposal:', error);
        throw error;
      }

      // Create a deal record
      const { error: dealError } = await supabase
        .from('deals')
        .insert({
          job_id: proposal.job_id,
          client_id: proposal.jobs.client_id,
          provider_id: proposal.provider_id,
          proposal_id: proposalId,
          agreed_amount: proposal.amount,
          status: 'active'
        });

      if (dealError) {
        console.error('Error creating deal:', dealError);
        throw dealError;
      }

      // Update job status to in_progress
      const { error: jobError } = await supabase
        .from('jobs')
        .update({ status: 'in_progress' })
        .eq('id', proposal.job_id);

      if (jobError) {
        console.error('Error updating job status:', jobError);
        throw jobError;
      }
    },
    onSuccess: () => {
      toast({
        title: "Proposal Accepted!",
        description: "A deal has been created. You can now manage the project progress.",
      });
      queryClient.invalidateQueries({ queryKey: ['proposals'] });
      queryClient.invalidateQueries({ queryKey: ['deals'] });
      queryClient.invalidateQueries({ queryKey: ['my-jobs'] });
    }
  });
};

export const useRejectProposal = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (proposalId: string) => {
      console.log('Rejecting proposal:', proposalId);
      
      const { error } = await supabase
        .from('proposals')
        .update({ status: 'rejected' })
        .eq('id', proposalId);
      
      if (error) {
        console.error('Error rejecting proposal:', error);
        throw error;
      }
    },
    onSuccess: () => {
      toast({
        title: "Proposal Rejected",
        description: "The proposal has been rejected",
      });
      queryClient.invalidateQueries({ queryKey: ['proposals'] });
    }
  });
};

export const useCounterProposal = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ proposalId, newAmount, message }: { 
      proposalId: string; 
      newAmount: number; 
      message?: string 
    }) => {
      console.log('Creating counter proposal:', { proposalId, newAmount, message });
      
      // First, get the original proposal to get job_id and provider_id
      const { data: originalProposal, error: fetchError } = await supabase
        .from('proposals')
        .select('job_id, provider_id')
        .eq('id', proposalId)
        .single();
      
      if (fetchError) {
        console.error('Error fetching original proposal:', fetchError);
        throw fetchError;
      }
      
      // Update the original proposal status to 'countered'
      const { error: updateError } = await supabase
        .from('proposals')
        .update({ status: 'countered' })
        .eq('id', proposalId);
      
      if (updateError) {
        console.error('Error updating original proposal:', updateError);
        throw updateError;
      }
      
      // Create a new proposal with the counter offer
      const { data, error } = await supabase
        .from('proposals')
        .insert([{
          job_id: originalProposal.job_id,
          provider_id: originalProposal.provider_id,
          amount: newAmount,
          message: message ? `Counter offer: ${message}` : 'Counter offer',
          status: 'pending'
        }])
        .select()
        .single();
      
      if (error) {
        console.error('Error creating counter proposal:', error);
        throw error;
      }
      
      return data;
    },
    onSuccess: () => {
      toast({
        title: "Counter Proposal Sent!",
        description: "Your counter proposal has been sent to the provider",
      });
      queryClient.invalidateQueries({ queryKey: ['proposals'] });
    }
  });
};

export const useMarkDealCompleted = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (dealId: string) => {
      console.log('Marking deal as completed:', dealId);
      
      const { error } = await supabase
        .from('deals')
        .update({ 
          status: 'completed',
          completed_at: new Date().toISOString()
        })
        .eq('id', dealId);
      
      if (error) {
        console.error('Error completing deal:', error);
        throw error;
      }
    },
    onSuccess: () => {
      toast({
        title: "Deal Completed!",
        description: "The project has been marked as completed. Payment can now be processed.",
      });
      queryClient.invalidateQueries({ queryKey: ['deals'] });
    }
  });
};
