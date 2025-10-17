-- Fix Supabase Realtime "payload_missing" error
-- This error occurs when the table doesn't have proper replica identity configured

-- 1. Set replica identity to FULL for the messages table
-- This ensures all column values are included in the realtime payload
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- 2. Also ensure realtime is enabled for the messages table
-- (This should already be done, but let's make sure)
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- 3. Verify the replica identity setting
SELECT 
    schemaname,
    tablename,
    rowsecurity,
    -- Get replica identity info
    CASE 
        WHEN c.relreplident = 'd' THEN 'default'
        WHEN c.relreplident = 'n' THEN 'nothing'
        WHEN c.relreplident = 'f' THEN 'full'
        WHEN c.relreplident = 'i' THEN 'index'
    END as replica_identity
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public' 
AND t.tablename = 'messages';

-- 4. Check if the table is in the realtime publication
SELECT 
    pubname,
    schemaname,
    tablename
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename = 'messages';

-- 5. Force a schema reload to apply changes
SELECT pg_notify('pgrst', 'reload schema');

-- 6. Verify everything is working
SELECT 'Realtime configuration updated for messages table' as status;