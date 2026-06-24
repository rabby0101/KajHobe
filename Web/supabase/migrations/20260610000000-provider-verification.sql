-- ============================================================================
-- Provider verification: NID + phone + certificates + work demos, manually
-- approved by an admin before a "Verified" badge is granted.
-- ----------------------------------------------------------------------------
-- Today anyone becomes a provider by flipping profiles.is_service_provider — an
-- instant, unchecked self-serve toggle. This migration adds a real gate:
--
--   1. provider_verifications  — one row per applicant; holds NID number + the
--      Storage paths of NID/certificate images, a verified phone, and a list of
--      external work-demo video URLs. RLS mirrors provider_payout_accounts:
--      owner manages own row (until approved), admins may read all.
--   2. profiles.is_verified_provider / verified_at — the SINGLE source of truth
--      for the Verified badge. Mirrored into public_profiles so public profile
--      screens can show the badge without a join. (Distinct from the auto
--      trust_level, which stays computed from job history.)
--   3. Two private Storage buckets (provider-nid, provider-certificates) with
--      per-user folder RLS; demo videos are URLs only (no storage).
--   4. approve_/reject_provider_verification() — service_role RPCs for the
--      no-login localhost admin panel (twins of the escrow_service_* pattern).
--
-- Additive + idempotent. Safe to apply to production.
-- ============================================================================

-- 1. Verification table ------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.provider_verifications (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  status            text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'approved', 'rejected')),
  nid_number        text,
  nid_front_path    text,          -- object path in the provider-nid bucket
  nid_back_path     text,
  phone             text,          -- the (verified) contact number, 01XXXXXXXXX
  phone_verified    boolean NOT NULL DEFAULT false,
  certificate_paths jsonb NOT NULL DEFAULT '[]'::jsonb,  -- provider-certificates paths
  demo_video_urls   jsonb NOT NULL DEFAULT '[]'::jsonb,  -- external (YouTube/FB/Drive) URLs
  submitted_at      timestamptz,
  reviewed_at       timestamptz,
  reviewed_by       uuid,
  rejection_reason  text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_provider_verifications_status
  ON public.provider_verifications(status);

-- Phone format guard (BD mobile), added idempotently and only when present.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'provider_verifications_phone_format'
  ) THEN
    ALTER TABLE public.provider_verifications
      ADD CONSTRAINT provider_verifications_phone_format
      CHECK (phone IS NULL OR phone ~ '^01[0-9]{9}$');
  END IF;
END $$;

-- keep updated_at fresh
CREATE OR REPLACE FUNCTION public.tg_provider_verification_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS provider_verification_touch_updated_at ON public.provider_verifications;
CREATE TRIGGER provider_verification_touch_updated_at
  BEFORE UPDATE ON public.provider_verifications
  FOR EACH ROW EXECUTE FUNCTION public.tg_provider_verification_touch_updated_at();

-- RLS: NID is PII. Owner manages own row while it is not yet approved; admins
-- may read all. service_role (admin panel) bypasses RLS entirely.
ALTER TABLE public.provider_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owner or admin can read verification" ON public.provider_verifications;
CREATE POLICY "owner or admin can read verification" ON public.provider_verifications
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "owner can insert own verification" ON public.provider_verifications;
CREATE POLICY "owner can insert own verification" ON public.provider_verifications
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Owner may edit (e.g. resubmit) only while not approved; approval is final and
-- can only be undone by an admin via the service-role RPCs below.
DROP POLICY IF EXISTS "owner can update own pending verification" ON public.provider_verifications;
CREATE POLICY "owner can update own pending verification" ON public.provider_verifications
  FOR UPDATE USING (auth.uid() = user_id AND status <> 'approved')
            WITH CHECK (auth.uid() = user_id AND status <> 'approved');

-- 2. Verified-provider flag on profiles + public_profiles --------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_verified_provider boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verified_at          timestamptz;

ALTER TABLE public.public_profiles
  ADD COLUMN IF NOT EXISTS is_verified_provider boolean NOT NULL DEFAULT false;

-- 2a. Carry is_verified_provider through the full recompute -------------------
CREATE OR REPLACE FUNCTION public.refresh_public_profile(user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public
AS $function$
DECLARE
    profile_record RECORD;
    deals_stats RECORD;
    reviews_stats RECORD;
    computed_trust_level TEXT;
    computed_categories JSONB;
BEGIN
    SELECT
        id, full_name, avatar_url, bio, location, website, is_service_provider,
        created_at, is_online, last_seen_at, average_response_time_minutes,
        profession, tagline, experience_years, hourly_rate, team_rate, team_hours_label,
        is_verified_provider
    INTO profile_record
    FROM profiles
    WHERE id = user_id;

    IF profile_record IS NULL THEN
        RETURN;
    END IF;

    SELECT
        COUNT(*) as completed_jobs,
        COALESCE(AVG(agreed_amount), 0)::DECIMAL(10,2) as avg_job_value,
        COALESCE(SUM(agreed_amount), 0)::DECIMAL(12,2) as total_earnings,
        jsonb_agg(DISTINCT j.category) FILTER (WHERE j.category IS NOT NULL) as categories
    INTO deals_stats
    FROM deals d
    LEFT JOIN jobs j ON d.job_id = j.id
    WHERE d.provider_id = user_id
        AND (d.completion_status = 'completed' OR d.status = 'completed');

    SELECT
        COUNT(*) as review_count,
        COALESCE(AVG(rating::DECIMAL), 0.00)::DECIMAL(3,2) as avg_rating
    INTO reviews_stats
    FROM reviews
    WHERE reviewed_id = user_id;

    IF deals_stats.completed_jobs >= 20 AND reviews_stats.avg_rating >= 4.5 THEN
        computed_trust_level := 'expert';
    ELSIF deals_stats.completed_jobs >= 10 AND reviews_stats.avg_rating >= 4.0 THEN
        computed_trust_level := 'experienced';
    ELSIF deals_stats.completed_jobs >= 5 AND reviews_stats.avg_rating >= 3.5 THEN
        computed_trust_level := 'established';
    ELSIF deals_stats.completed_jobs >= 1 THEN
        computed_trust_level := 'newcomer';
    ELSE
        computed_trust_level := 'unverified';
    END IF;

    computed_categories := COALESCE(deals_stats.categories, '[]'::jsonb);

    INSERT INTO public_profiles (
        id, full_name, avatar_url, bio, location, website, is_service_provider,
        created_at, completed_jobs, avg_job_value, total_earnings, avg_rating,
        review_count, is_online, last_seen_at, average_response_time_minutes,
        service_categories, trust_level, last_updated,
        profession, tagline, experience_years, hourly_rate, team_rate, team_hours_label,
        is_verified_provider
    ) VALUES (
        profile_record.id, profile_record.full_name, profile_record.avatar_url,
        profile_record.bio, profile_record.location, profile_record.website,
        profile_record.is_service_provider, profile_record.created_at,
        COALESCE(deals_stats.completed_jobs, 0),
        COALESCE(deals_stats.avg_job_value, 0.00),
        COALESCE(deals_stats.total_earnings, 0.00),
        COALESCE(reviews_stats.avg_rating, 0.00),
        COALESCE(reviews_stats.review_count, 0),
        profile_record.is_online, profile_record.last_seen_at,
        profile_record.average_response_time_minutes,
        computed_categories, computed_trust_level,
        timezone('utc'::text, now()),
        profile_record.profession, profile_record.tagline,
        profile_record.experience_years, profile_record.hourly_rate,
        profile_record.team_rate, profile_record.team_hours_label,
        COALESCE(profile_record.is_verified_provider, false)
    )
    ON CONFLICT (id)
    DO UPDATE SET
        full_name = EXCLUDED.full_name,
        avatar_url = EXCLUDED.avatar_url,
        bio = EXCLUDED.bio,
        location = EXCLUDED.location,
        website = EXCLUDED.website,
        is_service_provider = EXCLUDED.is_service_provider,
        completed_jobs = EXCLUDED.completed_jobs,
        avg_job_value = EXCLUDED.avg_job_value,
        total_earnings = EXCLUDED.total_earnings,
        avg_rating = EXCLUDED.avg_rating,
        review_count = EXCLUDED.review_count,
        is_online = EXCLUDED.is_online,
        last_seen_at = EXCLUDED.last_seen_at,
        average_response_time_minutes = EXCLUDED.average_response_time_minutes,
        service_categories = EXCLUDED.service_categories,
        trust_level = EXCLUDED.trust_level,
        last_updated = EXCLUDED.last_updated,
        profession = EXCLUDED.profession,
        tagline = EXCLUDED.tagline,
        experience_years = EXCLUDED.experience_years,
        hourly_rate = EXCLUDED.hourly_rate,
        team_rate = EXCLUDED.team_rate,
        team_hours_label = EXCLUDED.team_hours_label,
        is_verified_provider = EXCLUDED.is_verified_provider;
END;
$function$;

-- 2b. Seed the flag on initial public-profile creation -----------------------
CREATE OR REPLACE FUNCTION public.trigger_create_initial_public_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public
AS $function$
BEGIN
    INSERT INTO public_profiles (
        id, full_name, avatar_url, bio, location, website, is_service_provider,
        created_at, is_online, last_seen_at, average_response_time_minutes,
        service_categories, trust_level, last_updated,
        profession, tagline, experience_years, hourly_rate, team_rate, team_hours_label,
        is_verified_provider
    ) VALUES (
        NEW.id, NEW.full_name, NEW.avatar_url, NEW.bio, NEW.location,
        NEW.website, COALESCE(NEW.is_service_provider, false),
        NEW.created_at, COALESCE(NEW.is_online, false), NEW.last_seen_at,
        NEW.average_response_time_minutes, '[]'::jsonb, 'unverified',
        timezone('utc'::text, now()),
        NEW.profession, NEW.tagline, NEW.experience_years,
        NEW.hourly_rate, NEW.team_rate, NEW.team_hours_label,
        COALESCE(NEW.is_verified_provider, false)
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$function$;

-- Backfill the new public_profiles column from existing profiles.
SELECT public.refresh_all_public_profiles();

-- 3. Private Storage buckets + per-user folder RLS ---------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('provider-nid', 'provider-nid', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('provider-certificates', 'provider-certificates', false)
ON CONFLICT (id) DO NOTHING;

-- Convention: objects live under `{auth.uid()}/...`. A user may only touch their
-- own folder; admins may read all; service_role bypasses RLS.
DROP POLICY IF EXISTS "provider docs: owner read own" ON storage.objects;
CREATE POLICY "provider docs: owner read own" ON storage.objects
  FOR SELECT USING (
    bucket_id IN ('provider-nid', 'provider-certificates')
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_admin(auth.uid())
    )
  );

DROP POLICY IF EXISTS "provider docs: owner insert own" ON storage.objects;
CREATE POLICY "provider docs: owner insert own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id IN ('provider-nid', 'provider-certificates')
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "provider docs: owner update own" ON storage.objects;
CREATE POLICY "provider docs: owner update own" ON storage.objects
  FOR UPDATE USING (
    bucket_id IN ('provider-nid', 'provider-certificates')
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "provider docs: owner delete own" ON storage.objects;
CREATE POLICY "provider docs: owner delete own" ON storage.objects
  FOR DELETE USING (
    bucket_id IN ('provider-nid', 'provider-certificates')
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4. Service-role review RPCs (called by the localhost admin panel) ----------
-- No is_admin(auth.uid()) gate: the panel calls in as service_role (no user
-- JWT), which is inherently trusted and bypasses RLS.
CREATE OR REPLACE FUNCTION public.approve_provider_verification(
  p_user_id  uuid,
  p_reviewer uuid DEFAULT NULL
)
RETURNS public.provider_verifications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.provider_verifications%ROWTYPE;
BEGIN
  UPDATE public.provider_verifications
    SET status = 'approved',
        reviewed_at = now(),
        reviewed_by = p_reviewer,
        rejection_reason = NULL
    WHERE user_id = p_user_id
    RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No verification request for user %', p_user_id;
  END IF;

  UPDATE public.profiles
    SET is_verified_provider = true,
        verified_at = now(),
        is_service_provider = true
    WHERE id = p_user_id;

  PERFORM public.refresh_public_profile(p_user_id);
  RETURN v_row;
END $$;

REVOKE ALL ON FUNCTION public.approve_provider_verification(uuid, uuid)
  FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.approve_provider_verification(uuid, uuid)
  TO service_role;

CREATE OR REPLACE FUNCTION public.reject_provider_verification(
  p_user_id  uuid,
  p_reason   text DEFAULT NULL,
  p_reviewer uuid DEFAULT NULL
)
RETURNS public.provider_verifications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.provider_verifications%ROWTYPE;
BEGIN
  UPDATE public.provider_verifications
    SET status = 'rejected',
        reviewed_at = now(),
        reviewed_by = p_reviewer,
        rejection_reason = p_reason
    WHERE user_id = p_user_id
    RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No verification request for user %', p_user_id;
  END IF;

  UPDATE public.profiles
    SET is_verified_provider = false,
        verified_at = NULL
    WHERE id = p_user_id;

  PERFORM public.refresh_public_profile(p_user_id);
  RETURN v_row;
END $$;

REVOKE ALL ON FUNCTION public.reject_provider_verification(uuid, text, uuid)
  FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.reject_provider_verification(uuid, text, uuid)
  TO service_role;
