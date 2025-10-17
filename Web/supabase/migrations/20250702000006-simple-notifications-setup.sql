-- Simple migration: Just create the tables first
-- Run this first, then run the policies separately

-- 1. Create notifications table
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type text NOT NULL,
  job_id uuid NOT NULL,
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  message text NULL,
  offer_data jsonb NULL,
  actioned_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Add primary key
ALTER TABLE public.notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);

-- 3. Add foreign keys
ALTER TABLE public.notifications ADD CONSTRAINT notifications_job_id_fkey 
FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;

ALTER TABLE public.notifications ADD CONSTRAINT notifications_from_user_id_fkey 
FOREIGN KEY (from_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.notifications ADD CONSTRAINT notifications_to_user_id_fkey 
FOREIGN KEY (to_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 4. Add check constraint
ALTER TABLE public.notifications ADD CONSTRAINT notifications_status_check 
CHECK (status IN ('pending', 'accepted', 'rejected'));

-- 5. Create job_interests table
CREATE TABLE public.job_interests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 6. Add constraints for job_interests
ALTER TABLE public.job_interests ADD CONSTRAINT job_interests_pkey PRIMARY KEY (id);
ALTER TABLE public.job_interests ADD CONSTRAINT job_interests_unique UNIQUE (job_id, provider_id);
ALTER TABLE public.job_interests ADD CONSTRAINT job_interests_job_id_fkey 
FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;
ALTER TABLE public.job_interests ADD CONSTRAINT job_interests_provider_id_fkey 
FOREIGN KEY (provider_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 7. Add new columns to existing tables
ALTER TABLE public.messages ADD COLUMN offer_data jsonb NULL;
ALTER TABLE public.deals ADD COLUMN conversation_id uuid NULL;
ALTER TABLE public.deals ADD COLUMN agreed_terms text NULL;
ALTER TABLE public.deals ADD COLUMN timeline text NULL; 