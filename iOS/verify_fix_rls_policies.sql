-- URGENT: Fix RLS Security Vulnerability in Conversations Table
-- Run this script in your Supabase SQL Editor immediately

-- 1. Check current RLS status
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'conversations';

-- 2. Ensure RLS is enabled
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

-- 3. Check existing policies
SELECT policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'conversations';

-- 4. Drop potentially conflicting policies and recreate clean ones
DROP POLICY IF EXISTS "Users can view conversations they are part of" ON public.conversations;
DROP POLICY IF EXISTS "Users can insert conversations" ON public.conversations;  
DROP POLICY IF EXISTS "Users can update conversations they are part of" ON public.conversations;

-- 5. Create correct RLS policies
CREATE POLICY "Users can view conversations they are part of" 
  ON public.conversations 
  FOR SELECT 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

CREATE POLICY "Users can insert conversations they are part of" 
  ON public.conversations 
  FOR INSERT 
  WITH CHECK (auth.uid() = client_id OR auth.uid() = provider_id);

CREATE POLICY "Users can update conversations they are part of" 
  ON public.conversations 
  FOR UPDATE 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- 6. Test the policies with current user
SELECT 
  'Testing RLS...' as status,
  auth.uid() as current_user_id,
  COUNT(*) as accessible_conversations
FROM public.conversations;

-- 7. If you still see many conversations, there might be an issue with auth.uid()
-- Check if auth context is working:
SELECT 
  auth.uid() as current_auth_uid,
  auth.jwt() ->> 'sub' as jwt_subject;

-- 8. Double-check that no policies allow broader access
SELECT 
  policyname,
  cmd,
  qual as using_clause,
  with_check
FROM pg_policies 
WHERE tablename = 'conversations'
  AND schemaname = 'public';

-- 9. Verify RLS is working by checking if unfiltered query returns only user's conversations
-- This should only return conversations where you are client or provider
SELECT id, client_id, provider_id 
FROM public.conversations 
LIMIT 5;

COMMENT ON TABLE public.conversations IS 'RLS policies updated to prevent users from accessing other users conversations'; 