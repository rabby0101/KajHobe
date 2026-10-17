-- ============================================================================
-- Cash-only deals: accept in chat without paying through the gateway.
--
-- Why: the platform is going cash-only for now. Client and provider settle
-- directly, in cash, after the work. KajHobe is not a party to the payment and
-- has no gateway account yet (that waits on the trade licence).
--
-- Before: the ONLY way to accept an offer was SSLCommerz -> webhook ->
--   escrow_finalize_offer(), which flipped the offer to 'accepted' (creating
--   the deal via handle_deal_offer_responded) and marked escrow 'held'.
--
-- After: a 'cash' offer can be accepted directly by the client. The existing
--   pending->accepted trigger creates the deal unchanged; we only mark the
--   deal as cash so the escrow machinery knows to stand aside.
--
-- Deliberately NOT done: removing the escrow path. Every escrow function,
-- trigger and guard below still behaves exactly as before for
-- payment_method='escrow'. When the gateway returns, flipping the default back
-- is the whole change.
--
-- The trap this migration exists to avoid: tg_deals_block_unfunded_completion
-- refuses to complete any deal whose escrow is not held/released/paid_out. A
-- cash deal never has one. Without the exemption below, every cash deal would
-- be accepted happily and then be impossible to complete — and the failure
-- would only surface after the work was already done.
-- ============================================================================

-- 1. Carry the payment method on both the offer and the deal ----------------
--    'cash' is the default for now because that is the only flow the clients
--    currently offer. Change this default (not the code) to go back to escrow.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method') THEN
    CREATE TYPE public.payment_method AS ENUM ('cash', 'escrow');
  END IF;
END $$;

ALTER TABLE public.deal_offers
  ADD COLUMN IF NOT EXISTS payment_method public.payment_method NOT NULL DEFAULT 'cash';

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS payment_method public.payment_method NOT NULL DEFAULT 'cash';

-- Backfill: anything that actually went through the gateway must stay 'escrow',
-- so the completion guard keeps policing it exactly as before.
--
-- Checked against production before writing this (17 Oct 2026): 0 deals and
-- 0 escrow_transactions exist, so this update matches nothing today. It is here
-- for correctness if the migration is ever replayed against a database that does
-- have funded deals.
UPDATE public.deals d SET payment_method = 'escrow'
 WHERE EXISTS (SELECT 1 FROM public.escrow_transactions e WHERE e.deal_id = d.id);

-- Deliberately NOT backfilling deal_offers to 'escrow'. The only offer in the
-- table is still pending and was never paid; marking it 'escrow' would make it
-- accept into an uncompletable deal. Leaving it 'cash' lets it behave like every
-- offer made from now on.

-- 2. Deal creation copies the method off the offer --------------------------
--    Same trigger as before, one column added, so the offer->deal->escrow
--    chain is unchanged for escrow deals.
CREATE OR REPLACE FUNCTION public.handle_deal_offer_responded()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    INSERT INTO public.deals (
      job_id, client_id, provider_id, conversation_id, deal_offer_id,
      agreed_amount, agreed_terms, timeline, status, payment_method
    ) VALUES (
      NEW.job_id, NEW.client_id, NEW.provider_id, NEW.conversation_id, NEW.id,
      NEW.amount, NEW.terms, NEW.timeline, 'active', NEW.payment_method
    );
  END IF;
  RETURN NEW;
END;
$function$;

-- 3. No escrow row for a cash deal ------------------------------------------
--    Creating a 'pending' escrow for a deal nobody will ever pay through the
--    platform leaves a permanently stuck ledger row that looks like an unpaid
--    debt in every escrow report. Skip it instead.
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
  IF NEW.payment_method = 'cash' THEN
    RETURN NEW;
  END IF;

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

-- 4. The completion guard exempts cash deals, and nothing else --------------
--    This is the point of the whole migration. The guard is otherwise intact:
--    an escrow deal still cannot be completed without a funded escrow, which is
--    what stops a provider being told "Deal Completed" for money that was never
--    collected. A cash deal has no escrow by design, so the check is simply not
--    applicable — it is exempted explicitly rather than by weakening the rule.
CREATE OR REPLACE FUNCTION public.tg_deals_block_unfunded_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_state public.escrow_state;
BEGIN
  IF NEW.status = 'completed' AND NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.payment_method = 'cash' THEN
      RETURN NEW;
    END IF;

    SELECT state INTO v_state
      FROM public.escrow_transactions
     WHERE deal_id = NEW.id;

    IF v_state IS NULL OR v_state NOT IN ('held', 'released', 'paid_out') THEN
      RAISE EXCEPTION
        'Deal % cannot be completed: payment not collected into escrow (state %).',
        NEW.id, COALESCE(v_state::text, 'none')
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END $$;

-- The trigger itself is unchanged and already attached (BEFORE UPDATE, so it
-- still runs before the AFTER UPDATE release trigger); only the function body
-- above gains the cash exemption.
