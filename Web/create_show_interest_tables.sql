-- Simple script to create the required tables for Show Interest functionality
-- Run this in your Supabase SQL Editor

-- Create job_interests table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.job_interests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT job_interests_pkey PRIMARY KEY (id),
  CONSTRAINT job_interests_unique UNIQUE (job_id, provider_id)
);

-- Add foreign key constraints for job_interests if they don't exist
DO $$
BEGIN
    -- Add job_id foreign key
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'job_interests_job_id_fkey'
        AND table_name = 'job_interests'
    ) THEN
        ALTER TABLE public.job_interests 
        ADD CONSTRAINT job_interests_job_id_fkey 
        FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;
    END IF;
    
    -- Add provider_id foreign key
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'job_interests_provider_id_fkey'
        AND table_name = 'job_interests'
    ) THEN
        ALTER TABLE public.job_interests 
        ADD CONSTRAINT job_interests_provider_id_fkey 
        FOREIGN KEY (provider_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Create indexes for job_interests
CREATE INDEX IF NOT EXISTS idx_job_interests_job_id ON public.job_interests(job_id);
CREATE INDEX IF NOT EXISTS idx_job_interests_provider_id ON public.job_interests(provider_id);

-- Enable RLS on job_interests
ALTER TABLE public.job_interests ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for job_interests
DROP POLICY IF EXISTS "Users can view all interests" ON public.job_interests;
DROP POLICY IF EXISTS "Users can create their own interests" ON public.job_interests;

CREATE POLICY "Users can view all interests" ON public.job_interests
  FOR SELECT USING (true);

CREATE POLICY "Users can create their own interests" ON public.job_interests
  FOR INSERT WITH CHECK (auth.uid() = provider_id);

-- Create the correct notifications table for show interest
-- Check if the current notifications table has the new schema
DO $$
BEGIN
    -- Check if the notifications table has the new schema (type, job_id, from_user_id, to_user_id)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'from_user_id'
        AND table_schema = 'public'
    ) THEN
        -- The table doesn't have the new schema, so rename it and create new one
        
        -- Rename old notifications table if it exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications' AND table_schema = 'public') THEN
            ALTER TABLE public.notifications RENAME TO notifications_old_backup;
        END IF;
        
        -- Create new notifications table with correct schema
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
          created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
          CONSTRAINT notifications_pkey PRIMARY KEY (id),
          CONSTRAINT notifications_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
          CONSTRAINT notifications_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
          CONSTRAINT notifications_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
          CONSTRAINT notifications_status_check CHECK (status IN ('pending', 'accepted', 'rejected'))
        );
        
        -- Create indexes for notifications
        CREATE INDEX idx_notifications_to_user_id ON public.notifications(to_user_id);
        CREATE INDEX idx_notifications_job_id ON public.notifications(job_id);
        CREATE INDEX idx_notifications_status ON public.notifications(status);
        CREATE INDEX idx_notifications_created_at ON public.notifications(created_at);
        
        -- Enable RLS
        ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
        
        -- Create RLS policies for notifications
        CREATE POLICY "Users can view their own notifications" ON public.notifications
          FOR SELECT USING (auth.uid() = to_user_id);
        
        CREATE POLICY "Users can create notifications" ON public.notifications
          FOR INSERT WITH CHECK (auth.uid() = from_user_id);
        
        CREATE POLICY "Users can update their own notifications" ON public.notifications
          FOR UPDATE USING (auth.uid() = to_user_id);
          
    END IF;
END $$; 