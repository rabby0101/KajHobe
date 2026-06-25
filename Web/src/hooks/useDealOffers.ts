import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

/**
 * Deal-offer flow — parity with iOS (`MessagesNetworking.createDealOffer` /
 * `respondToDealOffer`) and Android (`MessagesRepository`). A deal offer is a real
 * row in `deal_offers` (the source of truth for status + bKash escrow) plus a
 * `deal_offer` chat message that links to it via `deal_offer_id`.
 *
 * Accepting is NOT done here: the client pays into escrow via `AcceptAndPayButton`
 * → `bkash-collect` → `bkash-webhook`, which flips `deal_offers.status` to
 * 'accepted' atomically with creating the deal. Web must never write 'accepted'.
 */

export interface SendDealOfferInput {
  conversationId: string;
  jobId: string;
  clientId: string;
  providerId: string;
  amount: number;
  terms?: string;
  timeline?: string;
  additionalMessage?: string;
}

/** Provider sends a deal offer: insert the `deal_offers` row, then the chat message. */
export const useSendDealOffer = () => {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  return useMutation({
    mutationFn: async (input: SendDealOfferInput): Promise<string> => {
      if (!user) throw new Error('Must be signed in to send an offer');

      const { conversationId, jobId, clientId, providerId, amount } = input;
      const terms = input.terms?.trim() || null;
      const timeline = input.timeline?.trim() || null;
      const additionalMessage = input.additionalMessage?.trim() || null;

      // 1. Create the deal_offers row (source of truth for status + payment).
      const { data: offer, error: offerErr } = await supabase
        .from('deal_offers')
        .insert({
          conversation_id: conversationId,
          provider_id: providerId,
          client_id: clientId,
          job_id: jobId,
          amount,
          terms,
          timeline,
          status: 'pending',
        })
        .select('id')
        .single();
      if (offerErr) throw offerErr;
      const dealOfferId = (offer as { id: string }).id;

      // 2. Create the linked chat message (mobile `deal_offer` shape).
      const negotiation_data: Record<string, unknown> = { amount, deal_offer_id: dealOfferId };
      if (terms) negotiation_data.terms = terms;
      if (timeline) negotiation_data.timeline = timeline;
      if (additionalMessage) negotiation_data.additional_message = additionalMessage;

      const { error: msgErr } = await supabase.from('messages').insert([
        {
          conversation_id: conversationId,
          sender_id: user.id,
          content: `💰 Deal Offer: ৳${amount}`,
          message_type: 'deal_offer',
          deal_offer_id: dealOfferId,
          negotiation_data,
        },
      ]);
      if (msgErr) throw msgErr;

      return dealOfferId;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['messages'] });
      queryClient.invalidateQueries({ queryKey: ['conversations'] });
      queryClient.invalidateQueries({ queryKey: ['deal-offer-statuses'] });
    },
  });
};

/**
 * Live status for the deal offers referenced by the current chat. The webhook
 * flips status to 'accepted' out of band, so the UI must read it from the table
 * (mirrors Android's `dealStatuses` map), not from the message payload.
 */
export const useDealOfferStatuses = (dealOfferIds: string[]) => {
  // Stable key regardless of ordering.
  const ids = Array.from(new Set(dealOfferIds.filter(Boolean))).sort();

  return useQuery({
    queryKey: ['deal-offer-statuses', ids],
    queryFn: async (): Promise<Record<string, string>> => {
      if (ids.length === 0) return {};
      const { data, error } = await supabase
        .from('deal_offers')
        .select('id, status')
        .in('id', ids);
      if (error) {
        console.error('Error fetching deal offer statuses:', error);
        return {};
      }
      const map: Record<string, string> = {};
      for (const row of (data ?? []) as { id: string; status: string }[]) {
        map[row.id] = row.status;
      }
      return map;
    },
    enabled: ids.length > 0,
    staleTime: 5000,
    refetchInterval: 8000,
    refetchOnWindowFocus: true,
  });
};

/** Client rejects a deal offer (mirrors mobile reject — accept goes through bKash). */
export const useRejectDealOffer = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (dealOfferId: string) => {
      const { error } = await supabase
        .from('deal_offers')
        .update({ status: 'rejected', responded_at: new Date().toISOString() })
        .eq('id', dealOfferId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deal-offer-statuses'] });
      queryClient.invalidateQueries({ queryKey: ['messages'] });
    },
  });
};
