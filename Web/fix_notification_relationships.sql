-- Fix notifications table foreign key relationships
-- This resolves the "more than one relationship" error

-- First, let's check what foreign keys exist
-- SELECT constraint_name, table_name, column_name 
-- FROM information_schema.key_column_usage 
-- WHERE table_name = 'notifications' AND table_schema = 'public';

-- Remove the old foreign key constraint for related_job_id if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'notifications_related_job_id_fkey'
        AND table_name = 'notifications'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications DROP CONSTRAINT notifications_related_job_id_fkey;
        RAISE NOTICE 'Dropped notifications_related_job_id_fkey constraint';
    END IF;
END $$;

-- Ensure the correct foreign key for job_id exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'notifications_job_id_fkey'
        AND table_name = 'notifications'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD CONSTRAINT notifications_job_id_fkey 
        FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;
        RAISE NOTICE 'Added notifications_job_id_fkey constraint';
    END IF;
END $$;

-- Optional: If you want to keep related_job_id for legacy notifications,
-- you can make it nullable and remove the foreign key constraint
-- UPDATE public.notifications SET related_job_id = NULL WHERE related_job_id IS NOT NULL;

-- Verify the current foreign keys
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name = 'notifications'
    AND tc.table_schema = 'public'
ORDER BY tc.constraint_name; 