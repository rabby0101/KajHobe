-- Check current RLS policies for messages table
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    permissive,
    roles,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'messages'
ORDER BY cmd, policyname;

-- Check if RLS is enabled on messages table
SELECT 
    schemaname,
    tablename,
    rowsecurity,
    forcerowsecurity
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'messages';

-- Test query to see what the current user auth context looks like
SELECT 
    auth.uid() as current_user_id,
    current_user as current_database_user,
    current_setting('role') as current_role;