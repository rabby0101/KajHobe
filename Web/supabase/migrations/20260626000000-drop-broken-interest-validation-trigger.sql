-- ============================================================================
-- Fix: showing interest in a job silently fails on Web — the job owner never
-- gets a notification, yet the UI reports "Interest Shown".
-- ----------------------------------------------------------------------------
-- Root cause: an out-of-band, never-tracked anti-abuse layer was applied
-- directly to production:
--
--   * trigger `interest_validation_trigger`  BEFORE INSERT ON notifications
--   * function `validate_interest_insertion()` (the trigger body)
--   * function `validate_interest_attempt(uuid,uuid)` (cooldown/rate-limit check)
--
-- For every notification with `type = 'show_interest'`, the trigger logs to a
-- table `interest_validation_violations` that DOES NOT EXIST (it was never
-- created). Both the validation-failed branch and the EXCEPTION handler insert
-- into that missing table, so the insert always raises
-- `relation "interest_validation_violations" does not exist`.
--
-- `public.show_interest_in_job()` inserts the job_interests row AND a
-- `show_interest` notification in one transaction, so the failing notification
-- insert rolls back the whole call: no interest, no notification. The function
-- swallows the error into `{success:false}`, and the Web client only checked the
-- PostgREST `error` (which is null), so it showed a false "Interest Shown".
--
-- Mobile (iOS/Android) is unaffected: it inserts only into `job_interests` and
-- relies on `trigger_interest_notification` to create an `interest_request`
-- notification (type <> 'show_interest'), which the validation trigger ignores.
--
-- The trigger provides zero working protection today (it can only ever throw),
-- and the cooldown/rate-limit it was meant to enforce is already implemented
-- client-side (Web `useInterestCooldown` + `lib/interestCooldown`) and guarded by
-- `show_interest_in_job`'s own duplicate-interest check. So we remove the broken
-- layer entirely.
--
-- Idempotent. Safe to apply to production.
-- ============================================================================

DROP TRIGGER IF EXISTS interest_validation_trigger ON public.notifications;
DROP FUNCTION IF EXISTS public.validate_interest_insertion();
DROP FUNCTION IF EXISTS public.validate_interest_attempt(uuid, uuid);
