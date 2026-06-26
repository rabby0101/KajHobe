-- ============================================================================
-- Make the show-interest cooldown + reapply flow actually work on Web.
-- ----------------------------------------------------------------------------
-- The Web cooldown UI (JobCard "Interest Rejected" → CooldownTimer / "max
-- attempts" / "Show Interest Again") and the pure logic in
-- src/lib/interestCooldown.ts already exist, but never fire because:
--
--   1. The cooldown counts *rejected* `show_interest` notifications, but nothing
--      set their status to 'rejected' when an owner declined an interest. iOS
--      did this client-side (InterestCooldownManager.recordRejection); Web never
--      did, so attemptCount stayed 0 — no cooldown, no max-attempt cap.
--   2. `show_interest_in_job` raised "already shown interest" for ANY existing
--      job_interests row (even a rejected one), so reapply was impossible.
--
-- Everything below is scoped per (job_id, provider_id) — multiple distinct
-- providers on the same job are fully independent and never wait on each other.
--
-- iOS/Android are unaffected: they insert into job_interests directly and never
-- call show_interest_in_job. The trigger is compatible with iOS's existing
-- recordRejection (which then matches no pending row and no-ops).
--
-- Idempotent. Safe to apply to production.
-- ============================================================================

-- 1. Record the outcome of an interest on its show_interest notification -------
-- When a job_interests row is decided (rejected/accepted), stamp the latest
-- pending show_interest notification for that (job, provider) with the same
-- status + actioned_at. This is the single, cross-client source the cooldown
-- reads — fires no matter which app (web/iOS/Android/admin) did the rejecting.
CREATE OR REPLACE FUNCTION public.tg_sync_interest_outcome_to_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IN ('rejected', 'accepted')
     AND NEW.status IS DISTINCT FROM OLD.status THEN
    UPDATE public.notifications
       SET status = NEW.status,
           actioned_at = now()
     WHERE id = (
       SELECT id
         FROM public.notifications
        WHERE job_id = NEW.job_id
          AND from_user_id = NEW.provider_id
          AND type = 'show_interest'
          AND status = 'pending'
        ORDER BY created_at DESC
        LIMIT 1
     );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_interest_outcome_to_notification ON public.job_interests;
CREATE TRIGGER sync_interest_outcome_to_notification
  AFTER UPDATE OF status ON public.job_interests
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_sync_interest_outcome_to_notification();

-- 2. Allow reapply after rejection, capped at 2 attempts ----------------------
-- Replaces the blanket "already shown interest" guard with status-aware logic.
CREATE OR REPLACE FUNCTION public.show_interest_in_job(
  p_job_id  uuid,
  p_message text DEFAULT 'I''m interested in this job!'::text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_user_id         uuid;
  v_client_id       uuid;
  v_job_title       text;
  v_notification_id uuid;
  v_interest_id     uuid;
  v_existing_status text;
  v_rejected_count  int;
  c_max_attempts    constant int := 2;   -- mirrors MAX_ATTEMPTS in interestCooldown.ts
  result            json;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  SELECT client_id, title INTO v_client_id, v_job_title
    FROM public.jobs
   WHERE id = p_job_id;

  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Job not found';
  END IF;

  IF v_user_id = v_client_id THEN
    RAISE EXCEPTION 'You cannot show interest in your own job posting';
  END IF;

  -- Any existing interest for this (job, provider)?
  SELECT status INTO v_existing_status
    FROM public.job_interests
   WHERE job_id = p_job_id AND provider_id = v_user_id
   LIMIT 1;

  IF v_existing_status IN ('pending', 'accepted') THEN
    RAISE EXCEPTION 'You have already shown interest in this job';
  END IF;

  IF v_existing_status = 'rejected' THEN
    -- One show_interest notification per attempt; rejected ones = used attempts.
    SELECT count(*) INTO v_rejected_count
      FROM public.notifications
     WHERE job_id = p_job_id
       AND from_user_id = v_user_id
       AND type = 'show_interest'
       AND status = 'rejected';

    IF v_rejected_count >= c_max_attempts THEN
      RAISE EXCEPTION 'Maximum interest attempts reached for this job';
    END IF;

    -- Clear the stale rejected row so the fresh insert re-fires the
    -- interest_request notification and respects unique (job_id, provider_id).
    DELETE FROM public.job_interests
     WHERE job_id = p_job_id AND provider_id = v_user_id;
  END IF;

  -- Fresh interest (fires trigger_interest_notification -> interest_request).
  INSERT INTO public.job_interests (job_id, provider_id, status, message)
  VALUES (p_job_id, v_user_id, 'pending', p_message)
  RETURNING id INTO v_interest_id;

  -- show_interest notification: cooldown history + drives the legacy feed.
  INSERT INTO public.notifications (type, job_id, from_user_id, to_user_id, status, message)
  VALUES (
    'show_interest', p_job_id, v_user_id, v_client_id, 'pending',
    'Someone showed interest in your job: ' || v_job_title
  )
  RETURNING id INTO v_notification_id;

  result := json_build_object(
    'success', true,
    'interest_id', v_interest_id,
    'notification_id', v_notification_id,
    'message', 'Interest shown successfully'
  );
  RETURN result;

EXCEPTION WHEN others THEN
  result := json_build_object('success', false, 'error', SQLERRM);
  RETURN result;
END;
$function$;
