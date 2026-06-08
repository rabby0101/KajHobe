-- ============================================================================
-- Escrow ledger for deal payments (bKash collect-then-payout model)
-- ----------------------------------------------------------------------------
-- One escrow_transactions row per deal. Money never moves in the DB; this is a
-- ledger + state machine. State transitions are driven by:
--   * DB triggers on `deals`  (pending on create, released on completion)
--   * SECURITY DEFINER RPCs    (held on collection, paid_out/refunded by admin)
--
-- SAFETY: the triggers attach to the LIVE `deals` table. Their bodies are wrapped
-- in EXCEPTION guards so an escrow failure can NEVER abort a real deal write.
-- All writes to escrow tables go through SECURITY DEFINER functions or
-- service_role; normal users get SELECT-only via RLS.
-- ============================================================================

-- 1. State enum -------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'escrow_state') THEN
    CREATE TYPE public.escrow_state AS ENUM
      ('pending', 'held', 'released', 'paid_out', 'refunded', 'failed');
  END IF;
END $$;

-- 2. Admin allowlist + helper ----------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_admins (
  user_id    uuid PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.app_admins ENABLE ROW LEVEL SECURITY;

-- SECURITY DEFINER so it can read app_admins regardless of caller RLS.
CREATE OR REPLACE FUNCTION public.is_admin(p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.app_admins WHERE user_id = p_uid);
$$;

-- Seed the project owner as admin (no-op if the profile isn't present).
INSERT INTO public.app_admins (user_id)
SELECT id FROM public.profiles WHERE lower(email) = 'fazlarabby53@gmail.com'
ON CONFLICT (user_id) DO NOTHING;

-- 3. Escrow ledger ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.escrow_transactions (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id              uuid NOT NULL UNIQUE REFERENCES public.deals(id) ON DELETE CASCADE,
  client_id            uuid NOT NULL,
  provider_id          uuid NOT NULL,
  amount               integer NOT NULL,             -- BDT, = deals.agreed_amount
  platform_fee         integer NOT NULL DEFAULT 0,   -- future commission (0 for now)
  provider_amount      integer NOT NULL,             -- amount - platform_fee
  state                public.escrow_state NOT NULL DEFAULT 'pending',
  currency             text NOT NULL DEFAULT 'BDT',
  -- bKash references (filled by collection / payout flows)
  collection_payment_id text,
  collection_trx_id     text,
  payout_trx_id         text,
  provider_msisdn       text,
  -- lifecycle timestamps + manual reconciliation
  held_at              timestamptz,
  released_at          timestamptz,
  paid_out_at          timestamptz,
  refunded_at          timestamptz,
  paid_out_by          uuid,
  notes                text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_escrow_tx_deal_id     ON public.escrow_transactions(deal_id);
CREATE INDEX IF NOT EXISTS idx_escrow_tx_client_id   ON public.escrow_transactions(client_id);
CREATE INDEX IF NOT EXISTS idx_escrow_tx_provider_id ON public.escrow_transactions(provider_id);
CREATE INDEX IF NOT EXISTS idx_escrow_tx_state       ON public.escrow_transactions(state);

-- 4. Append-only audit log --------------------------------------------------
CREATE TABLE IF NOT EXISTS public.escrow_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  escrow_id   uuid NOT NULL REFERENCES public.escrow_transactions(id) ON DELETE CASCADE,
  from_state  public.escrow_state,
  to_state    public.escrow_state NOT NULL,
  actor       uuid,
  meta        jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_escrow_events_escrow_id ON public.escrow_events(escrow_id);

-- 5. updated_at maintenance -------------------------------------------------
CREATE OR REPLACE FUNCTION public.tg_escrow_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS escrow_touch_updated_at ON public.escrow_transactions;
CREATE TRIGGER escrow_touch_updated_at
  BEFORE UPDATE ON public.escrow_transactions
  FOR EACH ROW EXECUTE FUNCTION public.tg_escrow_touch_updated_at();

-- 6. Deal triggers (exception-guarded; never block a deal write) -------------

-- 6a. Deal created -> create a pending escrow row.
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
        (deal_id, client_id, provider_id, amount, platform_fee, provider_amount, state)
      VALUES
        (NEW.id, NEW.client_id, NEW.provider_id, NEW.agreed_amount, v_fee,
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

DROP TRIGGER IF EXISTS deals_create_escrow ON public.deals;
CREATE TRIGGER deals_create_escrow
  AFTER INSERT ON public.deals
  FOR EACH ROW EXECUTE FUNCTION public.tg_deals_create_escrow();

-- 6b. Deal completed -> release held escrow (else flag).
CREATE OR REPLACE FUNCTION public.tg_deals_release_escrow()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_escrow public.escrow_transactions%ROWTYPE;
BEGIN
  BEGIN
    IF NEW.status = 'completed' AND NEW.status IS DISTINCT FROM OLD.status THEN
      SELECT * INTO v_escrow FROM public.escrow_transactions WHERE deal_id = NEW.id;
      IF NOT FOUND THEN
        RETURN NEW;
      END IF;

      IF v_escrow.state = 'held' THEN
        UPDATE public.escrow_transactions
          SET state = 'released', released_at = now()
          WHERE id = v_escrow.id;
        INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
        VALUES (v_escrow.id, 'held', 'released', NULL,
                jsonb_build_object('reason', 'deal_completed'));
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

DROP TRIGGER IF EXISTS deals_release_escrow ON public.deals;
CREATE TRIGGER deals_release_escrow
  AFTER UPDATE ON public.deals
  FOR EACH ROW EXECUTE FUNCTION public.tg_deals_release_escrow();

-- 7. State-transition RPCs (the only sanctioned write path) ------------------

-- 7a. Collection confirmed (called by the bKash collect/webhook Edge Function,
--     which uses the service_role key). Idempotent on payment id.
CREATE OR REPLACE FUNCTION public.escrow_mark_collected(
  p_deal_id     uuid,
  p_payment_id  text,
  p_trx_id      text
)
RETURNS public.escrow_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_escrow public.escrow_transactions%ROWTYPE;
BEGIN
  SELECT * INTO v_escrow FROM public.escrow_transactions WHERE deal_id = p_deal_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No escrow row for deal %', p_deal_id;
  END IF;

  -- Idempotent: already collected with the same payment -> return as-is.
  IF v_escrow.state = 'held' AND v_escrow.collection_payment_id IS NOT DISTINCT FROM p_payment_id THEN
    RETURN v_escrow;
  END IF;

  IF v_escrow.state <> 'pending' THEN
    RAISE EXCEPTION 'Escrow % not in pending state (is %)', v_escrow.id, v_escrow.state;
  END IF;

  UPDATE public.escrow_transactions
    SET state = 'held', held_at = now(),
        collection_payment_id = p_payment_id, collection_trx_id = p_trx_id
    WHERE id = v_escrow.id
    RETURNING * INTO v_escrow;

  INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
  VALUES (v_escrow.id, 'pending', 'held', NULL,
          jsonb_build_object('payment_id', p_payment_id, 'trx_id', p_trx_id));

  RETURN v_escrow;
END $$;

-- 7b. Admin marks provider paid out (manual bKash transfer until B2C is live).
CREATE OR REPLACE FUNCTION public.escrow_mark_paid_out(
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
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_escrow FROM public.escrow_transactions WHERE id = p_escrow_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Escrow % not found', p_escrow_id;
  END IF;
  IF v_escrow.state <> 'released' THEN
    RAISE EXCEPTION 'Escrow % not in released state (is %)', p_escrow_id, v_escrow.state;
  END IF;

  UPDATE public.escrow_transactions
    SET state = 'paid_out', paid_out_at = now(), paid_out_by = auth.uid(),
        payout_trx_id = p_trx_id,
        notes = CASE WHEN p_notes IS NULL THEN notes
                     ELSE COALESCE(notes || ' | ', '') || p_notes END
    WHERE id = v_escrow.id
    RETURNING * INTO v_escrow;

  INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
  VALUES (v_escrow.id, 'released', 'paid_out', auth.uid(),
          jsonb_build_object('trx_id', p_trx_id, 'notes', p_notes));

  RETURN v_escrow;
END $$;

-- 7c. Admin marks escrow refunded to buyer.
CREATE OR REPLACE FUNCTION public.escrow_mark_refunded(
  p_escrow_id uuid,
  p_notes     text DEFAULT NULL
)
RETURNS public.escrow_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_escrow public.escrow_transactions%ROWTYPE;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_escrow FROM public.escrow_transactions WHERE id = p_escrow_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Escrow % not found', p_escrow_id;
  END IF;
  IF v_escrow.state NOT IN ('held', 'released') THEN
    RAISE EXCEPTION 'Escrow % cannot be refunded from state %', p_escrow_id, v_escrow.state;
  END IF;

  UPDATE public.escrow_transactions
    SET state = 'refunded', refunded_at = now(),
        notes = CASE WHEN p_notes IS NULL THEN notes
                     ELSE COALESCE(notes || ' | ', '') || p_notes END
    WHERE id = v_escrow.id
    RETURNING * INTO v_escrow;

  INSERT INTO public.escrow_events (escrow_id, from_state, to_state, actor, meta)
  VALUES (v_escrow.id, v_escrow.state, 'refunded', auth.uid(),
          jsonb_build_object('notes', p_notes));

  RETURN v_escrow;
END $$;

-- 8. RLS --------------------------------------------------------------------
ALTER TABLE public.escrow_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escrow_events       ENABLE ROW LEVEL SECURITY;

-- SELECT only; all writes flow through SECURITY DEFINER RPCs / service_role.
DROP POLICY IF EXISTS "escrow participants or admin can read" ON public.escrow_transactions;
CREATE POLICY "escrow participants or admin can read" ON public.escrow_transactions
  FOR SELECT USING (
    auth.uid() = client_id OR auth.uid() = provider_id OR public.is_admin(auth.uid())
  );

DROP POLICY IF EXISTS "escrow events readable by participants or admin" ON public.escrow_events;
CREATE POLICY "escrow events readable by participants or admin" ON public.escrow_events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.escrow_transactions e
      WHERE e.id = escrow_events.escrow_id
        AND (auth.uid() = e.client_id OR auth.uid() = e.provider_id OR public.is_admin(auth.uid()))
    )
  );

DROP POLICY IF EXISTS "admins can read admin list" ON public.app_admins;
CREATE POLICY "admins can read admin list" ON public.app_admins
  FOR SELECT USING (public.is_admin(auth.uid()));

-- 9. Function grants --------------------------------------------------------
REVOKE ALL ON FUNCTION public.escrow_mark_collected(uuid, text, text) FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.escrow_mark_collected(uuid, text, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.escrow_mark_paid_out(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.escrow_mark_refunded(uuid, text)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid)                         TO authenticated, service_role;

-- 10. Backfill escrow rows for pre-existing deals ---------------------------
-- Legacy deals predate escrow and had no payment, so they start 'pending'
-- (completed legacy deals are NOT auto-released — no money ever moved).
INSERT INTO public.escrow_transactions
  (deal_id, client_id, provider_id, amount, platform_fee, provider_amount, state, notes)
SELECT d.id, d.client_id, d.provider_id, d.agreed_amount, 0,
       GREATEST(d.agreed_amount, 0), 'pending', 'backfilled pre-escrow deal'
FROM public.deals d
LEFT JOIN public.escrow_transactions e ON e.deal_id = d.id
WHERE e.id IS NULL;
