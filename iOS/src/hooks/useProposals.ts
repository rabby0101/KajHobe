
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

export interface Proposal {
  id: string;
  job_id: string;
  provider_id: string;
  amount: number;
  message: string | null;
  status: string;
  created_at: string;
  updated_at: string;
}

export const useCreateProposal = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  return useMutation({
    mutationFn: async (proposalData: { job_id: string; amount: number; message?: string }) => {
      if (!user) throw new Error('Must be logged in to send a proposal');
      
      console.log('Creating proposal with data:', proposalData);
      
      const { data, error } = await supabase
        .from('proposals')
        .insert([{ 
          ...proposalData, 
          provider_id: user.id,
          status: 'pending'
        }])
        .select()
        .single();
      
      if (error) {
        console.error('Error creating proposal:', error);
        throw error;
      }
      
      console.log('Proposal created successfully:', data);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['proposals'] });
    }
  });
};

export const useJobProposals = (jobId: string) => {
  return useQuery({
    queryKey: ['proposals', jobId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('proposals')
        .select(`
          *,
          profiles!proposals_provider_id_fkey(full_name, user_type)
        `)
        .eq('job_id', jobId)
        .order('created_at', { ascending: false });
      
      if (error) {
        console.error('Error fetching proposals:', error);
        throw error;
      }
      
      return data;
    }
  });
};
