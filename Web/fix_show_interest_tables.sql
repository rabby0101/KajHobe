-- Fix Show Interest Database Schema
-- Run this script in your Supabase SQL editor to fix the 404 error

-- First, drop the old notifications table if it exists (backup first if needed)
-- DROP TABLE IF EXISTS public.notifications CASCADE;

-- Create the new notifications table for show interest workflow
CREATE TABLE IF NOT EXISTS public.notifications_new (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type text NOT NULL,
  job_id uuid NOT NULL,
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  message text NULL,
  offer_data jsonb NULL,
  actioned_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT notifications_new_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_new_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  CONSTRAINT notifications_new_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT notifications_new_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT notifications_new_status_check CHECK (status IN ('pending', 'accepted', 'rejected'))
);

-- Create job_interests table
CREATE TABLE IF NOT EXISTS public.job_interests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT job_interests_pkey PRIMARY KEY (id),
  CONSTRAINT job_interests_unique UNIQUE (job_id, provider_id),
  CONSTRAINT job_interests_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  CONSTRAINT job_interests_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_notifications_new_to_user_id ON public.notifications_new(to_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_new_job_id ON public.notifications_new(job_id);
CREATE INDEX IF NOT EXISTS idx_notifications_new_status ON public.notifications_new(status);
CREATE INDEX IF NOT EXISTS idx_notifications_new_created_at ON public.notifications_new(created_at);
CREATE INDEX IF NOT EXISTS idx_job_interests_job_id ON public.job_interests(job_id);
CREATE INDEX IF NOT EXISTS idx_job_interests_provider_id ON public.job_interests(provider_id);

-- Enable RLS
ALTER TABLE public.notifications_new ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_interests ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for notifications_new
CREATE POLICY "Users can view their own notifications" ON public.notifications_new
  FOR SELECT USING (auth.uid() = to_user_id);

CREATE POLICY "Users can create notifications" ON public.notifications_new
  FOR INSERT WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Users can update their own notifications" ON public.notifications_new
  FOR UPDATE USING (auth.uid() = to_user_id);

-- Create RLS policies for job_interests
CREATE POLICY "Users can view all interests" ON public.job_interests
  FOR SELECT USING (true);

CREATE POLICY "Users can create their own interests" ON public.job_interests
  FOR INSERT WITH CHECK (auth.uid() = provider_id);

-- After creating the new table, you can:
-- 1. Rename the old notifications table: ALTER TABLE public.notifications RENAME TO notifications_old;
-- 2. Rename the new table: ALTER TABLE public.notifications_new RENAME TO notifications;
-- 3. Update any foreign key references if needed

-- Or if you want to replace immediately (CAREFUL - this will delete existing notifications):
-- DROP TABLE IF EXISTS public.notifications CASCADE;
-- ALTER TABLE public.notifications_new RENAME TO notifications;

-- Add the required columns to existing tables if they don't exist
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS offer_data jsonb NULL;

ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS conversation_id uuid NULL,
ADD COLUMN IF NOT EXISTS agreed_terms text NULL,
ADD COLUMN IF NOT EXISTS timeline text NULL;

-- Add foreign key constraint for deals.conversation_id if conversations table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'conversations' AND table_schema = 'public') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'deals_conversation_id_fkey'
            AND table_name = 'deals'
        ) THEN
            ALTER TABLE public.deals 
            ADD CONSTRAINT deals_conversation_id_fkey 
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

-- Functions and triggers
CREATE OR REPLACE FUNCTION handle_interest_acceptance()
RETURNS TRIGGER AS $$
BEGIN
  -- When an interest is accepted, create a conversation
  IF NEW.type = 'interest_request' AND NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    -- Check if conversation already exists
    IF NOT EXISTS (
      SELECT 1 FROM conversations 
      WHERE job_id = NEW.job_id 
      AND client_id = NEW.to_user_id 
      AND provider_id = NEW.from_user_id
    ) THEN
      -- Create new conversation
      INSERT INTO conversations (job_id, client_id, provider_id, status)
      VALUES (NEW.job_id, NEW.to_user_id, NEW.from_user_id, 'active');
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: The triggers will need to be created on the actual notifications table
-- after you rename notifications_new to notifications 