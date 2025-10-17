-- Fix Supabase Realtime "payload_missing" error
-- Only set replica identity since the table is already in realtime publication

-- 1. Set replica identity to FULL for the messages table
-- This is the main fix for the "payload_missing" error
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- 2. Verify the replica identity setting was applied
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN c.relreplident = 'd' THEN 'default'
        WHEN c.relreplident = 'n' THEN 'nothing'
        WHEN c.relreplident = 'f' THEN 'full'
        WHEN c.relreplident = 'i' THEN 'index'
    END as replica_identity_before,
    'Should now be: full' as expected_result
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public' 
AND t.tablename = 'messages';

-- 3. Confirm the table is in realtime publication (should already be there)
SELECT 
    'messages table is in realtime publication: ' || 
    CASE WHEN EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'messages'
    ) THEN 'YES ✅' ELSE 'NO ❌' END as publication_status;

-- 4. Force a schema reload to apply changes
SELECT pg_notify('pgrst', 'reload schema');

-- 5. Show final status
SELECT 
    'Replica identity set to FULL - payload_missing error should be resolved!' as status;