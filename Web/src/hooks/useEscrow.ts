import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import type { EscrowState } from '@/lib/escrow';

export interface EscrowTransaction {
  id: string;
  deal_id: string;
  deal_offer_id: string | null;
  client_id: string;
  provider_id: string;
  amount: number;
  currency: string;
  state: EscrowState;
  platform_fee: number;
  provider_amount: number;
  created_at: string;
  held_at: string | null;
  released_at: string | null;
  paid_out_at: string | null;
  refunded_at: string | null;
  notes: string | null;
}

/** The escrow row for a deal (null if none yet). */
export const useEscrow = (dealId: string | undefined) =>
  useQuery({
    queryKey: ['escrow', dealId],
    queryFn: async (): Promise<EscrowTransaction | null> => {
      if (!dealId) return null;
      const { data, error } = await supabase
        .from('escrow_transactions')
        .select('*')
        .eq('deal_id', dealId)
        .limit(1)
        .maybeSingle();
      if (error) {
        console.error('Error fetching escrow:', error);
        throw error;
      }
      return (data as EscrowTransaction) ?? null;
    },
    enabled: !!dealId,
    staleTime: 15000,
  });

/** Whether the signed-in user is in the app_admins allowlist. */
export const useIsAdmin = () => {
  const { user } = useAuth();
  return useQuery({
    queryKey: ['is-admin', user?.id],
    queryFn: async (): Promise<boolean> => {
      if (!user?.id) return false;
      const { data, error } = await supabase.rpc('is_admin', { p_uid: user.id });
      if (error) {
        console.error('is_admin check failed:', error);
        return false;
      }
      return !!data;
    },
    enabled: !!user?.id,
    staleTime: 300000,
  });
};

/** The current user's payout (bKash) number, or null. */
export const useMyPayoutNumber = () => {
  const { user } = useAuth();
  return useQuery({
    queryKey: ['payout-number', user?.id],
    queryFn: async (): Promise<string | null> => {
      if (!user?.id) return null;
      const { data, error } = await supabase
        .from('provider_payout_accounts')
        .select('bkash_number')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();
      if (error) {
        console.error('Error fetching payout number:', error);
        return null;
      }
      return data?.bkash_number ?? null;
    },
    enabled: !!user?.id,
  });
};

/** Create/update the current user's payout (bKash) number. */
export const useUpsertPayoutNumber = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();
  return useMutation({
    mutationFn: async (bkashNumber: string) => {
      if (!user?.id) throw new Error('Must be signed in');
      const { error } = await supabase
        .from('provider_payout_accounts')
        .upsert({ user_id: user.id, bkash_number: bkashNumber.trim() }, { onConflict: 'user_id' });
      if (error) throw error;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['payout-number', user?.id] }),
  });
};

/**
 * Start a bKash sandbox checkout for a deal OFFER. Returns the checkout URL to
 * redirect to; the webhook creates the deal + holds escrow on capture.
 */
export const useStartCollection = () =>
  useMutation({
    mutationFn: async (dealOfferId: string): Promise<string> => {
      const { data, error } = await supabase.functions.invoke('bkash-collect', {
        body: { deal_offer_id: dealOfferId },
      });
      if (error) throw error;
      const url = (data as { bkash_url?: string })?.bkash_url;
      if (!url) throw new Error('bKash did not return a checkout URL.');
      return url;
    },
  });

/** Admin: mark a released escrow as paid out / refund a held escrow. */
export const useAdminEscrowAction = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({
      escrowId,
      action,
      note,
    }: {
      escrowId: string;
      action: 'payout' | 'refund';
      note?: string;
    }) => {
      const fn = action === 'payout' ? 'escrow_mark_paid_out' : 'escrow_mark_refunded';
      const { error } = await supabase.rpc(fn, { p_escrow_id: escrowId, p_notes: note ?? null });
      if (error) throw error;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['escrow'] }),
  });
};
