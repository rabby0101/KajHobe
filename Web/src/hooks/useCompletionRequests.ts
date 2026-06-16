import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { isFunded, type EscrowState } from '@/lib/escrow';

export interface ActiveDeal {
  id: string;
  job_id: string;
  job_title: string;
  agreed_amount: number;
  status: string;
  completion_status: string | null;
  client_id: string;
  provider_id: string;
  counterpartyName: string;
  iAmClient: boolean;
  iRequestedCompletion: boolean;
}

export interface PendingCompletionRequest {
  id: string;
  deal_id: string;
  job_title: string;
  requester_type: string;
  requester_name: string;
  request_message: string | null;
  created_at: string;
}

const isDealCompleted = (status: string, completion: string | null) =>
  status === 'completed' || completion === 'completed';

/** Active (non-completed) deals the user is part of, with counterparty + request flags. */
export const useActiveDeals = () => {
  const { user } = useAuth();
  return useQuery({
    queryKey: ['active-deals', user?.id],
    queryFn: async (): Promise<ActiveDeal[]> => {
      if (!user?.id) return [];
      const { data, error } = await supabase
        .from('deals')
        .select(`
          id, job_id, agreed_amount, status, completion_status, client_id, provider_id,
          client_completion_requested, provider_completion_requested,
          jobs(title),
          client_profile:profiles!deals_client_id_fkey(full_name),
          provider_profile:profiles!deals_provider_id_fkey(full_name)
        `)
        .or(`client_id.eq.${user.id},provider_id.eq.${user.id}`)
        .order('created_at', { ascending: false });
      if (error) throw error;

      type Row = {
        id: string; job_id: string; agreed_amount: number; status: string;
        completion_status: string | null; client_id: string; provider_id: string;
        client_completion_requested: boolean | null; provider_completion_requested: boolean | null;
        jobs: { title: string } | null;
        client_profile: { full_name: string | null } | null;
        provider_profile: { full_name: string | null } | null;
      };

      return ((data ?? []) as unknown as Row[])
        .filter((d) => !isDealCompleted(d.status, d.completion_status))
        .map((d) => {
          const iAmClient = d.client_id === user.id;
          return {
            id: d.id,
            job_id: d.job_id,
            job_title: d.jobs?.title ?? 'Untitled job',
            agreed_amount: d.agreed_amount,
            status: d.status,
            completion_status: d.completion_status,
            client_id: d.client_id,
            provider_id: d.provider_id,
            counterpartyName:
              (iAmClient ? d.provider_profile?.full_name : d.client_profile?.full_name) ?? 'the other party',
            iAmClient,
            iRequestedCompletion: iAmClient
              ? !!d.client_completion_requested
              : !!d.provider_completion_requested,
          };
        });
    },
    enabled: !!user?.id,
    staleTime: 30000,
    refetchInterval: 30000,
  });
};

/** Completion requests awaiting the current user's approval (raised by the counterparty). */
export const usePendingCompletionRequests = () => {
  const { user } = useAuth();
  return useQuery({
    queryKey: ['completion-requests', user?.id],
    queryFn: async (): Promise<PendingCompletionRequest[]> => {
      if (!user?.id) return [];
      const { data, error } = await supabase
        .from('completion_requests')
        .select(`
          id, deal_id, requester_id, requester_type, request_message, status, created_at,
          deals!completion_requests_deal_id_fkey(client_id, provider_id, jobs(title)),
          requester:profiles!completion_requests_requester_id_fkey(full_name)
        `)
        .eq('status', 'pending')
        .order('created_at', { ascending: false });
      if (error) throw error;

      type Row = {
        id: string; deal_id: string; requester_id: string; requester_type: string;
        request_message: string | null; created_at: string;
        deals: { client_id: string; provider_id: string; jobs: { title: string } | null } | null;
        requester: { full_name: string | null } | null;
      };

      return ((data ?? []) as unknown as Row[])
        // Only requests on my deals that I didn't raise myself.
        .filter((r) => r.requester_id !== user.id &&
          (r.deals?.client_id === user.id || r.deals?.provider_id === user.id))
        .map((r) => ({
          id: r.id,
          deal_id: r.deal_id,
          job_title: r.deals?.jobs?.title ?? 'Untitled job',
          requester_type: r.requester_type,
          requester_name: r.requester?.full_name ?? 'Someone',
          request_message: r.request_message,
          created_at: r.created_at,
        }));
    },
    enabled: !!user?.id,
    staleTime: 15000,
    refetchInterval: 15000,
  });
};

export class CompletionError extends Error {}

/** Request task completion for a deal (parity with iOS requestTaskCompletion). */
export const useRequestCompletion = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();
  return useMutation({
    mutationFn: async ({ dealId, message }: { dealId: string; message?: string }) => {
      if (!user?.id) throw new CompletionError('Not signed in');
      const { data: deal, error: dealErr } = await supabase
        .from('deals')
        .select('client_id, provider_id')
        .eq('id', dealId)
        .single();
      if (dealErr || !deal) throw new CompletionError('Could not load the deal.');

      const requesterType =
        deal.client_id === user.id ? 'client' : deal.provider_id === user.id ? 'provider' : null;
      if (!requesterType) throw new CompletionError('You are not part of this deal.');

      const { error } = await supabase.from('completion_requests').insert({
        deal_id: dealId,
        requester_id: user.id,
        requester_type: requesterType,
        request_message: message ?? null,
      });
      if (error) {
        if (error.code === '23505') throw new CompletionError('A completion request is already pending for this deal.');
        throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['active-deals'] });
      queryClient.invalidateQueries({ queryKey: ['completion-requests'] });
    },
  });
};

/**
 * Respond to a completion request (parity with iOS respondToCompletionRequest).
 * Approving enforces the same guards: the deal must not be disputed and its escrow
 * must be funded; then the deal is marked completed.
 */
export const useRespondToCompletion = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ requestId, approve, message }: { requestId: string; approve: boolean; message?: string }) => {
      const now = new Date().toISOString();

      const { data: cr, error: crErr } = await supabase
        .from('completion_requests')
        .select('deal_id')
        .eq('id', requestId)
        .single();
      if (crErr || !cr) throw new CompletionError("Couldn't load this completion request.");
      const dealId = cr.deal_id;

      if (approve) {
        // Guard A1: a disputed deal must be settled by an admin.
        const { data: deal } = await supabase
          .from('deals')
          .select('completion_status, job_id')
          .eq('id', dealId)
          .single();
        if (deal?.completion_status === 'disputed') {
          throw new CompletionError("This deal is under dispute and can't be completed until an admin resolves it.");
        }
        // Guard A3/A4: payment must be collected into escrow before completion.
        const { data: escrow } = await supabase
          .from('escrow_transactions')
          .select('state')
          .eq('deal_id', dealId)
          .limit(1)
          .maybeSingle();
        if (!escrow || !isFunded(escrow.state as EscrowState)) {
          throw new CompletionError(
            "This deal can't be marked complete yet because the payment hasn't been collected into escrow."
          );
        }
      }

      const { error: updErr } = await supabase
        .from('completion_requests')
        .update({ status: approve ? 'approved' : 'rejected', responded_at: now, response_message: message ?? null })
        .eq('id', requestId);
      if (updErr) throw updErr;

      if (approve) {
        const { error: dealUpdErr } = await supabase
          .from('deals')
          .update({ status: 'completed', completed_at: now })
          .eq('id', dealId);
        if (dealUpdErr) throw dealUpdErr;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['active-deals'] });
      queryClient.invalidateQueries({ queryKey: ['completion-requests'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard-data'] });
    },
  });
};
