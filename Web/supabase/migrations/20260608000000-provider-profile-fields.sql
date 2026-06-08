-- Provider profile fields: profession, tagline, experience, hourly/team pricing.
--
-- These are provider-editable fields that power the redesigned public provider
-- profile screen (PublicProfileDetailView). Source of truth is `profiles`; they
-- are materialized into `public_profiles` by refresh_public_profile() and the
-- initial-insert trigger, both updated below. The existing
-- trigger_refresh_public_profile (on profiles UPDATE) propagates edits, so no
-- trigger wiring changes are needed.
--
-- Additive + idempotent. Safe to apply to production.

-- 1. Columns on the source table -------------------------------------------------
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS profession        text,
    ADD COLUMN IF NOT EXISTS tagline           text,
    ADD COLUMN IF NOT EXISTS experience_years  integer,
    ADD COLUMN IF NOT EXISTS hourly_rate       numeric,
    ADD COLUMN IF NOT EXISTS team_rate         numeric,
    ADD COLUMN IF NOT EXISTS team_hours_label  text;

-- 2. Mirror columns on the materialized table ------------------------------------
ALTER TABLE public.public_profiles
    ADD COLUMN IF NOT EXISTS profession        text,
    ADD COLUMN IF NOT EXISTS tagline           text,
    ADD COLUMN IF NOT EXISTS experience_years  integer,
    ADD COLUMN IF NOT EXISTS hourly_rate       numeric,
    ADD COLUMN IF NOT EXISTS team_rate         numeric,
    ADD COLUMN IF NOT EXISTS team_hours_label  text;

-- 3. Full recompute function: carry the new fields through -----------------------
CREATE OR REPLACE FUNCTION public.refresh_public_profile(user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    profile_record RECORD;
    deals_stats RECORD;
    reviews_stats RECORD;
    computed_trust_level TEXT;
    computed_categories JSONB;
BEGIN
    -- Get basic profile info (now including provider detail fields)
    SELECT
        id, full_name, avatar_url, bio, location, website, is_service_provider,
        created_at, is_online, last_seen_at, average_response_time_minutes,
        profession, tagline, experience_years, hourly_rate, team_rate, team_hours_label
    INTO profile_record
    FROM profiles
    WHERE id = user_id;

    -- If profile doesn't exist, exit
    IF profile_record IS NULL THEN
        RETURN;
    END IF;

    -- Calculate deals statistics
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

    -- Calculate reviews statistics
    SELECT
        COUNT(*) as review_count,
        COALESCE(AVG(rating::DECIMAL), 0.00)::DECIMAL(3,2) as avg_rating
    INTO reviews_stats
    FROM reviews
    WHERE reviewed_id = user_id;

    -- Compute trust level based on completed jobs and rating
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

    -- Prepare service categories (ensure it's never null)
    computed_categories := COALESCE(deals_stats.categories, '[]'::jsonb);

    -- Insert or update public_profiles
    INSERT INTO public_profiles (
        id, full_name, avatar_url, bio, location, website, is_service_provider,
        created_at, completed_jobs, avg_job_value, total_earnings, avg_rating,
        review_count, is_online, last_seen_at, average_response_time_minutes,
        service_categories, trust_level, last_updated,
        profession, tagline, experience_years, hourly_rate, team_rate, team_hours_label
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
        profile_record.team_rate, profile_record.team_hours_label
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
        team_hours_label = EXCLUDED.team_hours_label;

END;
$function$;

-- 4. Initial-insert trigger: seed the new fields on profile creation -------------
CREATE OR REPLACE FUNCTION public.trigger_create_initial_public_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Only create if the user is a service provider or might become one
    INSERT INTO public_profiles (
        id, full_name, avatar_url, bio, location, website, is_service_provider,
        created_at, is_online, last_seen_at, average_response_time_minutes,
        service_categories, trust_level, last_updated,
        profession, tagline, experience_years, hourly_rate, team_rate, team_hours_label
    ) VALUES (
        NEW.id, NEW.full_name, NEW.avatar_url, NEW.bio, NEW.location,
        NEW.website, COALESCE(NEW.is_service_provider, false),
        NEW.created_at, COALESCE(NEW.is_online, false), NEW.last_seen_at,
        NEW.average_response_time_minutes, '[]'::jsonb, 'unverified',
        timezone('utc'::text, now()),
        NEW.profession, NEW.tagline, NEW.experience_years,
        NEW.hourly_rate, NEW.team_rate, NEW.team_hours_label
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$function$;

-- 5. Backfill existing public_profiles rows with any values already on profiles ---
SELECT public.refresh_all_public_profiles();
