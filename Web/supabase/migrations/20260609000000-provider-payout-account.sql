-- ============================================================================
-- Provider payout accounts + service-role payout RPC
-- ----------------------------------------------------------------------------
-- The "release to provider" leg of the escrow flow needs to know WHERE to send
-- a provider's money. That destination is a personal bKash number which must
-- stay PRIVATE: only the provider, an admin, or the service role may ever read
-- it. It is deliberately kept OUT of `profiles` / `public_profiles` (which are
-- readable by other users) and lives in its own RLS-locked table.
--
-- This migration:
--   A1. provider_payout_accounts table (+ RLS, + format check)
--   A2. CREATE OR REPLACE tg_deals_release_escrow() to stamp the provider's
--       current bkash_number onto escrow_transactions.provider_msisdn at release
--       (a frozen audit snapshot of who was owed) — best-effort, exception-guarded.
--   A3. escrow_service_mark_paid_out() — a service_role-only twin of
--       escrow_mark_paid_out() so the no-login localhost admin panel can confirm
--       a manual payout without an authenticated admin JWT.
--
-- Additive + idempotent. Safe to apply to production.
-- ============================================================================

-- A1. Private payout-account table ------------------------------------------
CREATE TABLE IF NOT EXISTS public.provider_payout_accounts (
  user_id      uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  bkash_number text NOT NULL,            -- BD mobile, 01XXXXXXXXX (11 digits)
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- Format guard: 11-digit Bangladeshi mobile starting 01. Added idempotently.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'provider_payout_accounts_bkash_number_format'
  ) THEN
    ALTER TABLE public.provider_payout_accounts
      ADD CONSTRAINT provider_payout_accounts_bkash_number_format
      CHECK (bkash_number ~ '^01[0-9]{9}$');
  END IF;
END $$;

-- keep updated_at fresh on edits
CREATE OR REPLACE FUNCTION public.tg_payout_account_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS payout_account_touch_updated_at ON public.provider_payout_accounts;
CREATE TRIGGER payout_account_touch_updated_at
  BEFORE UPDATE ON public.provider_payout_accounts
  FOR EACH ROW EXECUTE FUNCTION public.tg_payout_account_touch_updated_at();

-- RLS: privacy is the whole point. Owner manages own row; admin may read.
-- Service role bypasses RLS entirely (used by the localhost admin server).
ALTER TABLE public.provider_payout_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owner or admin can read payout account" ON public.provider_payout_accounts;
CREATE POLICY "owner or admin can read payout account" ON public.provider_payout_accounts
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "owner can insert own payout account" ON public.provider_payout_accounts;
CREATE POLICY "owner can insert own payout account" ON public.provider_payout_accounts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "owner can update own payout account" ON public.provider_payout_accounts;
CREATE POLICY "owner can update own payout account" ON public.provider_payout_accounts
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- A2. Stamp provider_msisdn onto the escrow at release ----------------------
-- Same body as the original tg_deals_release_escrow (20260607000000) with one
-- addition: when we flip held -> released, copy the provider's CURRENT payout
-- number onto the escrow row as a frozen record. Still fully exception-guarded
-- so an escrow/lookup failure can never abort a real deal write.
CREATE OR REPLACE FUNCTION public.tg_deals_release_escrow()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_escrow public.escrow_transactions%ROWTYPE;
  v_msisdn text;
BEGIN
  BEGIN
    IF NEW.status = 'completed' AND NEW.status IS DISTINCT FROM OLD.status THEN
      SELECT * INTO v_escrow FROM public.escrow_transactions WHERE deal_id = NEW.id;
      IF NOT FOUND THEN
        RETURN NEW;
      END IF;

      IF v_escrow.state = 'held' THEN
        -- best-effort: provider may not have set a payout number yet
        SELECT bkash_number INTO v_msisdn
          FROM public.provider_payout_accounts
          WHERE user_id = v_escrow.provider_id;

        UPDATE public.escrow_transactions
          SET state = 'released',
              released_at = now(),
              provider_msisdn = COALESCE(v_msisdn, provider_msisdn)
          WHERE id = v_escrow.id;
        INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
        VALUES (v_escrow.id, 'held', 'released', NULL,
                jsonb_build_object('reason', 'deal_completed',
                                   'provider_msisdn_present', v_msisdn IS NOT NULL));
      ELSIF v_escrow.state = 'pending' THEN
        -- Deal marked complete before the buyer ever paid. Don't auto-release;
        -- just annotate so an admin can reconcile.
        UPDATE public.escrow_transactions
          SET notes = COALESCE(notes || ' | ', '')
                      || 'deal completed while payment still pending @ ' || now()
          WHERE id = v_escrow.id;
        INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
        VALUES (v_escrow.id, 'pending', 'pending', NULL,
                jsonb_build_object('reason', 'completed_without_collection'));
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'tg_deals_release_escrow failed for deal %: %', NEW.id, SQLERRM;
  END;
  RETURN NEW;
END $$;

-- trigger binding is unchanged (still AFTER UPDATE ON deals); recreate defensively
DROP TRIGGER IF EXISTS deals_release_escrow ON public.deals;
CREATE TRIGGER deals_release_escrow
  AFTER UPDATE ON public.deals
  FOR EACH ROW EXECUTE FUNCTION public.tg_deals_release_escrow();

-- A3. Service-role payout RPC -----------------------------------------------
-- Twin of escrow_mark_paid_out() WITHOUT the is_admin(auth.uid()) gate, because
-- the localhost admin panel calls in as service_role (no user JWT). service_role
-- is inherently trusted and bypasses RLS, so the only guard needed is the state
-- check (must be 'released'). Writes still flow through a SECURITY DEFINER RPC.
CREATE OR REPLACE FUNCTION public.escrow_service_mark_paid_out(
  p_escrow_id uuid,
  p_notes     text DEFAULT NULL,
  p_trx_id    text DEFAULT NULL
)
RETURNS public.escrow_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_escrow public.escrow_transactions%ROWTYPE;
BEGIN
  SELECT * INTO v_escrow FROM public.escrow_transactions WHERE id = p_escrow_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Escrow % not found', p_escrow_id;
  END IF;

  -- Idempotent: already paid out with the same trx -> return as-is.
  IF v_escrow.state = 'paid_out' AND v_escrow.payout_trx_id IS NOT DISTINCT FROM p_trx_id THEN
    RETURN v_escrow;
  END IF;

  IF v_escrow.state <> 'released' THEN
    RAISE EXCEPTION 'Escrow % not in released state (is %)', p_escrow_id, v_escrow.state;
  END IF;

  UPDATE public.escrow_transactions
    SET state = 'paid_out', paid_out_at = now(),
        payout_trx_id = p_trx_id,
        notes = CASE WHEN p_notes IS NULL THEN notes
                     ELSE COALESCE(notes || ' | ', '') || p_notes END
    WHERE id = v_escrow.id
    RETURNING * INTO v_escrow;

  INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
  VALUES (v_escrow.id, 'released', 'paid_out', NULL,
          jsonb_build_object('trx_id', p_trx_id, 'notes', p_notes, 'via', 'service_role_admin_panel'));

  RETURN v_escrow;
END $$;

REVOKE ALL ON FUNCTION public.escrow_service_mark_paid_out(uuid, text, text)
  FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.escrow_service_mark_paid_out(uuid, text, text)
  TO service_role;
