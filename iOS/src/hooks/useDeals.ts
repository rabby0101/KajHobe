
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

export interface Deal {
  id: string;
  job_id: string;
  client_id: string;
  provider_id: string;
  proposal_id: string;
  agreed_amount: number;
  status: string;
  created_at: string;
  completed_at: string | null;
  jobs?: any;
  profiles?: any;
}

export const useMyDeals = () => {
  const { user } = useAuth();

  return useQuery({
    queryKey: ['deals', user?.id],
    queryFn: async () => {
      if (!user) return [];
      
      console.log('Fetching deals for user:', user.id);
      
      const { data, error } = await supabase
        .from('deals')
        .select(`
          *,
          jobs(*),
          profiles!deals_provider_id_fkey(full_name, user_type)
        `)
        .or(`client_id.eq.${user.id},provider_id.eq.${user.id}`)
        .order('created_at', { ascending: false });
      
      if (error) {
        console.error('Error fetching deals:', error);
        throw error;
      }
      
      console.log('Deals fetched:', data);
      return data as Deal[];
    },
    enabled: !!user
  });
};

export const useDealById = (dealId: string) => {
  return useQuery({
    queryKey: ['deal', dealId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('deals')
        .select(`
          *,
          jobs(*),
          profiles!deals_provider_id_fkey(full_name, user_type, email, phone)
        `)
        .eq('id', dealId)
        .single();
      
      if (error) {
        console.error('Error fetching deal:', error);
        throw error;
      }
      
      return data as Deal;
    },
    enabled: !!dealId
  });
};
