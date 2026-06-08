-- ============================================================================
-- Pay-to-create-deal: payment at offer acceptance gates deal creation.
--
-- Before: client accepts offer -> deal_offers.status='accepted' -> trigger
--   handle_deal_offer_responded() inserts the deal -> deals_create_escrow makes
--   a pending escrow. Payment was a separate, optional step.
--
-- After: the client pays at acceptance. Only on a confirmed bKash capture does
--   escrow_finalize_offer() flip the offer to 'accepted' (which creates the deal)
--   and mark that deal's escrow 'held'. No payment -> offer stays pending -> no
--   deal. The deal-creation trigger is reused unchanged; we only control WHEN it
--   fires, and we stamp deal_offer_id so the offer->deal->escrow chain links.
-- ============================================================================

-- 1. Link escrow rows back to the originating offer ------------------------
ALTER TABLE public.escrow_transactions
  ADD COLUMN IF NOT EXISTS deal_offer_id uuid
  REFERENCES public.deal_offers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_escrow_tx_deal_offer_id
  ON public.escrow_transactions(deal_offer_id);

-- 2. Make the deal-creation trigger stamp deal_offer_id on the new deal -----
--    (live version omitted it, which broke offer->deal linkage). Behaviour is
--    otherwise identical: one deal per pending->accepted transition.
CREATE OR REPLACE FUNCTION public.handle_deal_offer_responded()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    INSERT INTO public.deals (
      job_id, client_id, provider_id, conversation_id, deal_offer_id,
      agreed_amount, agreed_terms, timeline, status
    ) VALUES (
      NEW.job_id, NEW.client_id, NEW.provider_id, NEW.conversation_id, NEW.id,
      NEW.amount, NEW.terms, NEW.timeline, 'active'
    );
  END IF;
  RETURN NEW;
END;
$function$;

-- 3. Escrow auto-create trigger also records deal_offer_id ------------------
CREATE OR REPLACE FUNCTION public.tg_deals_create_escrow()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fee integer := 0;
  v_escrow_id uuid;
BEGIN
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.escrow_transactions WHERE deal_id = NEW.id) THEN
      INSERT INTO public.escrow_transactions
        (deal_id, deal_offer_id, client_id, provider_id, amount, platform_fee, provider_amount, state)
      VALUES
        (NEW.id, NEW.deal_offer_id, NEW.client_id, NEW.provider_id, NEW.agreed_amount, v_fee,
         GREATEST(NEW.agreed_amount - v_fee, 0), 'pending')
      RETURNING id INTO v_escrow_id;

      INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
      VALUES (v_escrow_id, NULL, 'pending', NULL,
              jsonb_build_object('reason', 'deal_created', 'deal_id', NEW.id));
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'tg_deals_create_escrow failed for deal %: %', NEW.id, SQLERRM;
  END;
  RETURN NEW;
END $$;

-- 4. Atomic finalize: paid offer -> accepted -> deal -> held escrow --------
--    Called only by the bKash webhook (service_role) after a confirmed capture.
CREATE OR REPLACE FUNCTION public.escrow_finalize_offer(
  p_deal_offer_id uuid,
  p_payment_id    text,
  p_trx_id        text
)
RETURNS public.escrow_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_offer  public.deal_offers%ROWTYPE;
  v_deal   public.deals%ROWTYPE;
  v_escrow public.escrow_transactions%ROWTYPE;
BEGIN
  SELECT * INTO v_offer FROM public.deal_offers WHERE id = p_deal_offer_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'deal_offer % not found', p_deal_offer_id;
  END IF;

  -- Idempotent replay: already finalized.
  IF v_offer.status = 'accepted' THEN
    SELECT * INTO v_escrow FROM public.escrow_transactions WHERE deal_offer_id = p_deal_offer_id;
    IF FOUND THEN
      RETURN v_escrow;
    END IF;
    RAISE EXCEPTION 'offer % already accepted but no escrow linked', p_deal_offer_id;
  END IF;

  IF v_offer.status <> 'pending' THEN
    RAISE EXCEPTION 'offer % is % (expected pending)', p_deal_offer_id, v_offer.status;
  END IF;

  -- Flip to accepted -> fires handle_deal_offer_responded -> inserts deal
  -- (with deal_offer_id) -> fires deals_create_escrow -> pending escrow row.
  UPDATE public.deal_offers
    SET status = 'accepted', responded_at = now()
    WHERE id = p_deal_offer_id;

  SELECT * INTO v_deal FROM public.deals WHERE deal_offer_id = p_deal_offer_id
    ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'deal was not created for offer %', p_deal_offer_id;
  END IF;

  -- Move that deal's escrow pending -> held with the bKash payment refs.
  v_escrow := public.escrow_mark_collected(v_deal.id, p_payment_id, p_trx_id);
  RETURN v_escrow;
END $$;

-- 5. Grants: webhook (service_role) only -----------------------------------
REVOKE ALL ON FUNCTION public.escrow_finalize_offer(uuid, text, text) FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.escrow_finalize_offer(uuid, text, text) TO service_role;
