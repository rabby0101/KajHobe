-- Fix the notifications table constraints to support show interest workflow
-- This removes the NOT NULL constraint from user_id to allow new schema

-- Remove NOT NULL constraint from user_id column
ALTER TABLE public.notifications ALTER COLUMN user_id DROP NOT NULL;

-- Also make sure title and message can be null for new schema
ALTER TABLE public.notifications ALTER COLUMN title DROP NOT NULL;
ALTER TABLE public.notifications ALTER COLUMN message DROP NOT NULL;

-- Make sure the new columns allow NULL values as expected
ALTER TABLE public.notifications ALTER COLUMN type DROP NOT NULL;
ALTER TABLE public.notifications ALTER COLUMN job_id DROP NOT NULL;
ALTER TABLE public.notifications ALTER COLUMN from_user_id DROP NOT NULL;
ALTER TABLE public.notifications ALTER COLUMN to_user_id DROP NOT NULL;

-- Update the check constraint to be more flexible
DO $$
BEGIN
    -- Drop existing check constraint if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'notifications_status_check'
        AND table_name = 'notifications'
    ) THEN
        ALTER TABLE public.notifications DROP CONSTRAINT notifications_status_check;
    END IF;
    
    -- Add new flexible check constraint
    ALTER TABLE public.notifications 
    ADD CONSTRAINT notifications_status_check 
    CHECK (status IN ('pending', 'accepted', 'rejected') OR status IS NULL);
END $$;

-- Ensure the RLS policies work with both schemas
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can create notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;

-- Create flexible policies that handle both old and new schema
CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT USING (
    (user_id IS NOT NULL AND auth.uid() = user_id) OR  -- Old schema
    (to_user_id IS NOT NULL AND auth.uid() = to_user_id)  -- New schema
  );

CREATE POLICY "Users can create notifications" ON public.notifications
  FOR INSERT WITH CHECK (
    (user_id IS NOT NULL AND auth.uid() = user_id) OR  -- Old schema
    (from_user_id IS NOT NULL AND auth.uid() = from_user_id)  -- New schema
  );

CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE USING (
    (user_id IS NOT NULL AND auth.uid() = user_id) OR  -- Old schema
    (to_user_id IS NOT NULL AND auth.uid() = to_user_id)  -- New schema
  ); 