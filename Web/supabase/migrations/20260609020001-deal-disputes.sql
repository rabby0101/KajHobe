-- ============================================================================
-- A1 (part 2/2): Deal disputes with admin-resolved partial split.
--
-- Lets either deal participant open a dispute on a funded, active deal. The deal
-- freezes (completion_status='disputed') and normal completion is blocked. An
-- admin then resolves it from the localhost payout panel, splitting the held
-- amount between a buyer refund and a provider payout (partial allowed). The
-- escrow lands in the terminal 'resolved' state (added in part 1) with both legs
-- recorded; both parties are notified.
--
-- Money never moves in the DB — this is a ledger. The admin performs up to two
-- manual bKash transfers and records the trx ids.
-- ============================================================================

-- 1. Escrow: split columns ---------------------------------------------------
ALTER TABLE public.escrow_transactions
  ADD COLUMN IF NOT EXISTS refund_amount integer,   -- BDT returned to the buyer
  ADD COLUMN IF NOT EXISTS payout_amount integer,   -- BDT paid to the provider
  ADD COLUMN IF NOT EXISTS resolved_at   timestamptz,
  ADD COLUMN IF NOT EXISTS refund_trx_id text;      -- payout leg reuses payout_trx_id

-- 2. Deal: allow the 'resolved' completion_status ----------------------------
ALTER TABLE public.deals DROP CONSTRAINT IF EXISTS deals_completion_status_check;
ALTER TABLE public.deals
  ADD CONSTRAINT deals_completion_status_check
  CHECK (completion_status = ANY (ARRAY[
    'in_progress','pending_approval','completed','disputed','resolved']));

-- 3. deal_disputes table (audit + what the admin panel lists) ----------------
CREATE TABLE IF NOT EXISTS public.deal_disputes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     uuid NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
  raised_by   uuid NOT NULL,
  reason      text,
  status      text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved')),
  resolution  jsonb,
  resolved_by uuid,
  created_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_deal_disputes_deal_id ON public.deal_disputes(deal_id);
CREATE INDEX IF NOT EXISTS idx_deal_disputes_status  ON public.deal_disputes(status);
-- at most one OPEN dispute per deal
CREATE UNIQUE INDEX IF NOT EXISTS uq_deal_disputes_one_open
  ON public.deal_disputes(deal_id) WHERE status = 'open';

ALTER TABLE public.deal_disputes ENABLE ROW LEVEL SECURITY;
-- Read-only for participants/admin; all writes go through the SECURITY DEFINER
-- RPCs below (which bypass RLS) or service_role. No INSERT/UPDATE policy.
DROP POLICY IF EXISTS "dispute participants or admin can read" ON public.deal_disputes;
CREATE POLICY "dispute participants or admin can read" ON public.deal_disputes
  FOR SELECT USING (
    public.is_admin(auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.deals d
      WHERE d.id = deal_disputes.deal_id
        AND (auth.uid() = d.client_id OR auth.uid() = d.provider_id)
    )
  );

-- 4. Raise a dispute (authenticated participant) -----------------------------
CREATE OR REPLACE FUNCTION public.deal_open_dispute(p_deal_id uuid, p_reason text)
RETURNS public.deal_disputes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_deal    public.deals%ROWTYPE;
  v_escrow  public.escrow_transactions%ROWTYPE;
  v_other   uuid;
  v_dispute public.deal_disputes%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_deal FROM public.deals WHERE id = p_deal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal % not found', p_deal_id; END IF;

  IF v_uid <> v_deal.client_id AND v_uid <> v_deal.provider_id THEN
    RAISE EXCEPTION 'Only a deal participant can open a dispute';
  END IF;
  IF v_deal.status <> 'active' THEN
    RAISE EXCEPTION 'Only an active deal can be disputed (deal is %)', v_deal.status;
  END IF;

  SELECT * INTO v_escrow FROM public.escrow_transactions WHERE deal_id = p_deal_id;
  IF NOT FOUND OR v_escrow.state <> 'held' THEN
    RAISE EXCEPTION 'Deal % has no funds held in escrow to dispute', p_deal_id;
  END IF;

  IF EXISTS (SELECT 1 FROM public.deal_disputes WHERE deal_id = p_deal_id AND status = 'open') THEN
    RAISE EXCEPTION 'A dispute is already open for this deal';
  END IF;

  -- Freeze the deal. (status stays 'active', so neither the completion guard nor
  -- the release trigger — both keyed on status='completed' — react here.)
  UPDATE public.deals SET completion_status = 'disputed' WHERE id = p_deal_id;

  INSERT INTO public.deal_disputes (deal_id, raised_by, reason)
  VALUES (p_deal_id, v_uid, p_reason)
  RETURNING * INTO v_dispute;

  INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
  VALUES (v_escrow.id, v_escrow.state, v_escrow.state, v_uid,
          jsonb_build_object('reason', 'dispute_opened', 'dispute_id', v_dispute.id));

  -- Notify the other party (best-effort; never abort the dispute on notify error).
  v_other := CASE WHEN v_uid = v_deal.client_id THEN v_deal.provider_id ELSE v_deal.client_id END;
  BEGIN
    INSERT INTO public.notifications (type, title, message, job_id, from_user_id, to_user_id, status)
    VALUES ('dispute_opened', 'Deal disputed',
            'The other party opened a dispute on your deal. An admin will review it.',
            v_deal.job_id, v_uid, v_other, 'pending');
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'dispute_opened notification failed: %', SQLERRM;
  END;

  RETURN v_dispute;
END $$;

REVOKE ALL ON FUNCTION public.deal_open_dispute(uuid, text) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.deal_open_dispute(uuid, text) TO authenticated;

-- 5. Resolve a dispute (service_role only — localhost admin panel) ------------
--    Mirrors escrow_service_mark_paid_out: no is_admin(auth.uid()) gate because
--    service_role is inherently trusted and bypasses RLS.
CREATE OR REPLACE FUNCTION public.escrow_service_resolve_dispute(
  p_escrow_id     uuid,
  p_refund_amount integer,
  p_payout_amount integer,
  p_refund_trx    text DEFAULT NULL,
  p_payout_trx    text DEFAULT NULL,
  p_notes         text DEFAULT NULL
)
RETURNS public.escrow_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_escrow public.escrow_transactions%ROWTYPE;
  v_deal   public.deals%ROWTYPE;
  v_msisdn text;
BEGIN
  SELECT * INTO v_escrow FROM public.escrow_transactions WHERE id = p_escrow_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Escrow % not found', p_escrow_id; END IF;
  IF v_escrow.state <> 'held' THEN
    RAISE EXCEPTION 'Escrow % must be held to resolve a dispute (is %)', p_escrow_id, v_escrow.state;
  END IF;

  IF p_refund_amount IS NULL OR p_payout_amount IS NULL
     OR p_refund_amount < 0 OR p_payout_amount < 0 THEN
    RAISE EXCEPTION 'refund and payout amounts must both be >= 0';
  END IF;
  IF p_refund_amount + p_payout_amount > v_escrow.amount THEN
    RAISE EXCEPTION 'refund (%) + payout (%) exceeds escrow amount (%)',
      p_refund_amount, p_payout_amount, v_escrow.amount;
  END IF;

  SELECT * INTO v_deal FROM public.deals WHERE id = v_escrow.deal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal for escrow % not found', p_escrow_id; END IF;
  IF v_deal.completion_status <> 'disputed' THEN
    RAISE EXCEPTION 'Deal % is not disputed (is %)', v_deal.id, v_deal.completion_status;
  END IF;

  IF p_payout_amount > 0 THEN
    SELECT bkash_number INTO v_msisdn FROM public.provider_payout_accounts
      WHERE user_id = v_escrow.provider_id;
  END IF;

  -- Settle the escrow FIRST so the deal write below sees a non-held escrow
  -- (keeps the release trigger a no-op and satisfies the completion guard).
  UPDATE public.escrow_transactions
    SET state           = 'resolved',
        refund_amount   = p_refund_amount,
        payout_amount   = p_payout_amount,
        refund_trx_id   = p_refund_trx,
        payout_trx_id   = COALESCE(p_payout_trx, payout_trx_id),
        provider_msisdn = COALESCE(v_msisdn, provider_msisdn),
        resolved_at     = now(),
        notes = CASE WHEN p_notes IS NULL THEN notes
                     ELSE COALESCE(notes || ' | ', '') || p_notes END
    WHERE id = v_escrow.id
    RETURNING * INTO v_escrow;

  INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
  VALUES (v_escrow.id, 'held', 'resolved', NULL,
          jsonb_build_object('refund_amount', p_refund_amount, 'payout_amount', p_payout_amount,
                             'refund_trx', p_refund_trx, 'payout_trx', p_payout_trx,
                             'via', 'service_role_admin_panel'));

  UPDATE public.deal_disputes
    SET status = 'resolved', resolved_at = now(),
        resolution = jsonb_build_object('refund_amount', p_refund_amount,
                                        'payout_amount', p_payout_amount, 'notes', p_notes)
    WHERE deal_id = v_deal.id AND status = 'open';

  -- Close the deal out. completion_status='resolved' (not 'disputed') so the
  -- completion guard's anti-dispute rule allows it.
  UPDATE public.deals
    SET completion_status = 'resolved', status = 'completed', completed_at = now()
    WHERE id = v_deal.id;

  BEGIN
    INSERT INTO public.notifications (type, title, message, job_id, from_user_id, to_user_id, status)
    VALUES
      ('dispute_resolved', 'Dispute resolved',
       'An admin resolved the dispute on your deal.', v_deal.job_id, NULL, v_deal.client_id, 'pending'),
      ('dispute_resolved', 'Dispute resolved',
       'An admin resolved the dispute on your deal.', v_deal.job_id, NULL, v_deal.provider_id, 'pending');
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'dispute_resolved notification failed: %', SQLERRM;
  END;

  RETURN v_escrow;
END $$;

REVOKE ALL ON FUNCTION public.escrow_service_resolve_dispute(uuid, integer, integer, text, text, text)
  FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.escrow_service_resolve_dispute(uuid, integer, integer, text, text, text)
  TO service_role;

-- 6. Extend the completion guard --------------------------------------------
--    (a) allow 'resolved' escrow as a funded terminal state, so dispute
--        resolution can flip the deal to completed; (b) refuse to complete a
--        deal that is still 'disputed' via the normal completion path.
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
    IF NEW.completion_status = 'disputed' THEN
      RAISE EXCEPTION 'Deal % cannot be completed while a dispute is open.', NEW.id
        USING ERRCODE = 'check_violation';
    END IF;

    SELECT state INTO v_state
      FROM public.escrow_transactions
     WHERE deal_id = NEW.id;

    IF v_state IS NULL OR v_state NOT IN ('held', 'released', 'paid_out', 'resolved') THEN
      RAISE EXCEPTION
        'Deal % cannot be completed: payment not collected into escrow (state %).',
        NEW.id, COALESCE(v_state::text, 'none')
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
