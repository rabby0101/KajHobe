-- ============================================================================
-- Fix: pin search_path on SECURITY DEFINER trigger/helper functions
-- ----------------------------------------------------------------------------
-- Signup started failing with HTTP 500 "Database error saving new user":
--   relation "public_profiles" does not exist (SQLSTATE 42P01)
--
-- Root cause: these SECURITY DEFINER functions referenced public.* objects
-- UNQUALIFIED and had no `search_path` pinned. When GoTrue inserts the new
-- auth.users row during signup, the trigger chain runs with GoTrue's restricted
-- search_path (which excludes `public`), so `public_profiles` (and friends)
-- could not be resolved. (Surfaced after a GoTrue upgrade tightened search_path.)
--
-- Fix: pin `search_path = public` on every affected SECURITY DEFINER function.
-- Idempotent and safe to re-run.
-- ============================================================================

ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.trigger_create_initial_public_profile() SET search_path = public;
ALTER FUNCTION public.trigger_refresh_public_profile() SET search_path = public;
ALTER FUNCTION public.refresh_public_profile(uuid) SET search_path = public;
ALTER FUNCTION public.refresh_all_public_profiles() SET search_path = public;
ALTER FUNCTION public.handle_negotiation_message() SET search_path = public;
ALTER FUNCTION public.handle_new_message() SET search_path = public;
ALTER FUNCTION public.handle_new_proposal() SET search_path = public;
ALTER FUNCTION public.handle_proposal_status_change() SET search_path = public;
