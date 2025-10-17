-- Supabase Realtime Setup for KajHobe Chat App
-- Run these commands in your Supabase SQL Editor

-- 1. Enable Realtime for the messages table (following the tutorial)
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- 2. Check if RLS is enabled on messages table (should already be enabled)
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'messages';

-- 3. Verify that the messages table structure matches expectations
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'messages'
ORDER BY ordinal_position;

-- 4. Check existing RLS policies on messages table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'messages';

-- 5. If you need to create basic RLS policies for messages (only run if they don't exist):

-- Allow authenticated users to read messages from conversations they participate in
-- CREATE POLICY "Users can read messages from their conversations" ON messages
-- FOR SELECT USING (
--     EXISTS (
--         SELECT 1 FROM conversations 
--         WHERE conversations.id = messages.conversation_id 
--         AND (conversations.client_id = auth.uid()::text OR conversations.provider_id = auth.uid()::text)
--     )
-- );

-- Allow authenticated users to insert messages into conversations they participate in
-- CREATE POLICY "Users can insert messages into their conversations" ON messages
-- FOR INSERT WITH CHECK (
--     EXISTS (
--         SELECT 1 FROM conversations 
--         WHERE conversations.id = messages.conversation_id 
--         AND (conversations.client_id = auth.uid()::text OR conversations.provider_id = auth.uid()::text)
--     )
--     AND messages.sender_id = auth.uid()::text
-- );

-- 6. Test query to check recent messages (run this to test basic access)
SELECT 
    id, 
    conversation_id,
    sender_id,
    content,
    message_type,
    created_at
FROM messages 
ORDER BY created_at DESC 
LIMIT 10;

-- 7. Check realtime publications
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';

-- 8. Verify the auth context works
SELECT auth.uid() as current_user_id;

-- If you see errors, make sure:
-- 1. You're logged in to Supabase with proper authentication
-- 2. RLS policies allow your user to access the messages
-- 3. The messages table exists with the expected structure
-- 4. Realtime is enabled for your Supabase project (check in Supabase Dashboard > API > Realtime)