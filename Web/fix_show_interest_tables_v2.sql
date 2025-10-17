-- Fixed script to create the required tables for Show Interest functionality
-- This version handles existing constraints properly

-- First, create job_interests table if it doesn't exist
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

-- Now handle the notifications table more carefully
DO $$
BEGIN
    -- Check if the notifications table has the required columns for show interest
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'from_user_id'
        AND table_schema = 'public'
    ) THEN
        
        -- The current notifications table doesn't have the show interest schema
        -- We need to add the missing columns to the existing table
        
        -- Add missing columns to existing notifications table
        ALTER TABLE public.notifications 
        ADD COLUMN IF NOT EXISTS type text,
        ADD COLUMN IF NOT EXISTS job_id uuid,
        ADD COLUMN IF NOT EXISTS from_user_id uuid,
        ADD COLUMN IF NOT EXISTS to_user_id uuid,
        ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending',
        ADD COLUMN IF NOT EXISTS offer_data jsonb,
        ADD COLUMN IF NOT EXISTS actioned_at timestamp with time zone;
        
        -- Add constraints if they don't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'notifications_status_check'
            AND table_name = 'notifications'
        ) THEN
            ALTER TABLE public.notifications 
            ADD CONSTRAINT notifications_status_check 
            CHECK (status IN ('pending', 'accepted', 'rejected') OR status IS NULL);
        END IF;
        
        -- Add foreign key constraints if they don't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'notifications_job_id_fkey'
            AND table_name = 'notifications'
        ) THEN
            -- Only add if jobs table exists and job_id is not null
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'jobs' AND table_schema = 'public') THEN
                ALTER TABLE public.notifications 
                ADD CONSTRAINT notifications_job_id_fkey 
                FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;
            END IF;
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'notifications_from_user_id_fkey'
            AND table_name = 'notifications'
        ) THEN
            ALTER TABLE public.notifications 
            ADD CONSTRAINT notifications_from_user_id_fkey 
            FOREIGN KEY (from_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'notifications_to_user_id_fkey'
            AND table_name = 'notifications'
        ) THEN
            ALTER TABLE public.notifications 
            ADD CONSTRAINT notifications_to_user_id_fkey 
            FOREIGN KEY (to_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
        END IF;
        
    END IF;
END $$;

-- Create additional indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_notifications_to_user_id ON public.notifications(to_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_job_id ON public.notifications(job_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);

-- Ensure RLS is enabled on notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Update RLS policies for notifications to handle both old and new schema
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can create notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;

-- Create policies that work with both old and new schema
CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT USING (
    auth.uid() = user_id OR  -- Old schema
    auth.uid() = to_user_id  -- New schema
  );

CREATE POLICY "Users can create notifications" ON public.notifications
  FOR INSERT WITH CHECK (
    auth.uid() = user_id OR  -- Old schema
    auth.uid() = from_user_id  -- New schema
  );

CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE USING (
    auth.uid() = user_id OR  -- Old schema
    auth.uid() = to_user_id  -- New schema
  );

-- Create a function to handle interest acceptance (if conversations table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'conversations' AND table_schema = 'public') THEN
        
        CREATE OR REPLACE FUNCTION handle_interest_acceptance()
        RETURNS TRIGGER AS $trigger$
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
        $trigger$ LANGUAGE plpgsql;
        
        -- Create trigger if it doesn't exist
        DROP TRIGGER IF EXISTS on_interest_acceptance ON notifications;
        CREATE TRIGGER on_interest_acceptance
        AFTER UPDATE ON notifications
        FOR EACH ROW
        EXECUTE FUNCTION handle_interest_acceptance();
        
    END IF;
END $$; 