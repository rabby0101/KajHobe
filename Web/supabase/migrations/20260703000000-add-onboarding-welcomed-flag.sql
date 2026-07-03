ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_welcomed_at timestamptz;
