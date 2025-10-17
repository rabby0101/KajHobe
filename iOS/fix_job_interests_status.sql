-- Add status column to job_interests table for proper interest tracking
-- This fixes the issue where interest status is not properly tracked

-- First, add the status column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'job_interests' 
        AND column_name = 'status'
    ) THEN
        ALTER TABLE public.job_interests 
        ADD COLUMN status text DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected'));
        
        -- Update existing records to have 'pending' status
        UPDATE public.job_interests SET status = 'pending' WHERE status IS NULL;
        
        RAISE NOTICE 'Added status column to job_interests table';
    ELSE
        RAISE NOTICE 'Status column already exists in job_interests table';
    END IF;
END $$;

-- Also add actioned_at column for job_interests table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'job_interests' 
        AND column_name = 'actioned_at'
    ) THEN
        ALTER TABLE public.job_interests 
        ADD COLUMN actioned_at timestamp with time zone;
        
        RAISE NOTICE 'Added actioned_at column to job_interests table';
    ELSE
        RAISE NOTICE 'actioned_at column already exists in job_interests table';
    END IF;
END $$;

-- Create index on status for better query performance
CREATE INDEX IF NOT EXISTS idx_job_interests_status ON public.job_interests(status);

-- Create composite index for common queries (job_id, provider_id, status)
CREATE INDEX IF NOT EXISTS idx_job_interests_job_provider_status 
ON public.job_interests(job_id, provider_id, status);

-- Update RLS policies to handle status column
DROP POLICY IF EXISTS "Users can update interests status" ON public.job_interests;

CREATE POLICY "Users can update interests status" ON public.job_interests
  FOR UPDATE USING (
    -- Job owners can update status of interests on their jobs
    auth.uid() IN (
      SELECT client_id FROM jobs WHERE id = job_id
    )
    OR 
    -- Providers can view but not change their own interests
    auth.uid() = provider_id
  );

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON public.job_interests TO authenticated;