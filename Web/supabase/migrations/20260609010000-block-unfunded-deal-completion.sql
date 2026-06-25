-- ============================================================================
-- Integrity guard: a deal cannot be marked COMPLETED unless its payment was
-- actually collected into escrow (state held / released / paid_out).
--
-- Why: with pay-to-create, real deals are born funded — escrow_finalize_offer
-- inserts the deal and immediately marks its escrow 'held' in one transaction.
-- But a few paths can still produce an `active` deal whose escrow is 'pending'
-- (never paid):
--   * legacy / backfilled pre-escrow deals (see create-escrow-ledger §10),
--   * the dead-code direct-accept path (DealsNetworking.respondToDealOffer),
--   * any future/manual write that bypasses the bKash collection flow.
-- Completing such a deal silently misleads the provider: the UI shows
-- "Deal Completed", jobs.status flips to 'completed', yet the release trigger
-- (tg_deals_release_escrow) refuses to release a 'pending' escrow — so no money
-- was ever collected and none will ever be paid out.
--
-- This BEFORE UPDATE trigger refuses that transition outright. Note this is the
-- DELIBERATE OPPOSITE of the escrow side-effect triggers, which are wrapped in
-- EXCEPTION guards precisely so they can never abort a deal write. Here aborting
-- the write IS the goal — an unfunded deal must not be completable.
--
-- Enforcement point: we guard COMPLETION, not creation. We must NOT require a
-- funded escrow at deal INSERT, because pay-to-create legitimately creates the
-- deal first (escrow 'pending') and flips it to 'held' a step later within the
-- same finalize call; guarding creation would break every real payment.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.tg_deals_block_unfunded_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_state public.escrow_state;
BEGIN
  -- Only police the active -> completed transition.
  IF NEW.status = 'completed' AND NEW.status IS DISTINCT FROM OLD.status THEN
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

-- BEFORE UPDATE so it runs (and can abort) before the AFTER UPDATE release
-- trigger ever fires.
DROP TRIGGER IF EXISTS deals_block_unfunded_completion ON public.deals;
CREATE TRIGGER deals_block_unfunded_completion
  BEFORE UPDATE ON public.deals
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_deals_block_unfunded_completion();
