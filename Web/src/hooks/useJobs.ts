import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

export interface Job {
  id: string;
  title: string;
  description: string;
  category: string;
  budget: number;
  location: string;
  status: string;
  urgent: boolean;
  created_at: string;
  client_id: string;
  profiles?: {
    full_name: string;
    location: string;
  };
}

export const useJobs = () => {
  return useQuery({
    queryKey: ['jobs'],
    queryFn: async () => {
      try {
        console.log('Fetching jobs...');
        
        // Try to fetch jobs from the jobs table
        const { data: jobs, error } = await supabase
          .from('jobs')
          .select('*')
          .in('status', ['open', 'active'])
          .order('created_at', { ascending: false })
          .limit(10);
        
        if (error) {
          console.error('Error fetching jobs:', error);
          // Return empty array instead of throwing error
          return [] as Job[];
        }
        
        console.log('Jobs fetched successfully:', jobs);
        return (jobs || []) as Job[];
      } catch (error) {
        console.error('Error in useJobs:', error);
        // Return empty array on any error
        return [] as Job[];
      }
    },
    retry: 1,
    staleTime: 60000, // 1 minute
    refetchInterval: 60000, // Refetch every 1 minute
    refetchOnWindowFocus: true,
  });
};

export const useCreateJob = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  return useMutation({
    mutationFn: async (jobData: Omit<Job, 'id' | 'created_at' | 'client_id' | 'profiles'>) => {
      if (!user) throw new Error('Must be logged in to create a job');
      
      console.log('Creating job with data:', jobData);
      
      const { data, error } = await supabase
        .from('jobs')
        .insert([{ ...jobData, client_id: user.id }])
        .select()
        .single();
      
      if (error) {
        console.error('Error creating job:', error);
        throw error;
      }
      
      console.log('Job created successfully:', data);
      return data;
    },
    onSuccess: () => {
      console.log('Invalidating jobs query...');
      queryClient.invalidateQueries({ queryKey: ['jobs'] });
    }
  });
};
