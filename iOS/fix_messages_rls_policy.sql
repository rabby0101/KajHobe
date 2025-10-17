-- Fix RLS policy for messages table to include sender_id validation
-- This fixes the "new row violates row-level security policy" error

-- Drop the existing policy that's missing sender_id check
DROP POLICY IF EXISTS "Users can insert messages in their conversations" ON public.messages;

-- Create corrected policy with sender_id validation
CREATE POLICY "Users can insert messages in their conversations" 
  ON public.messages 
  FOR INSERT 
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.client_id = auth.uid() OR conversations.provider_id = auth.uid())
    )
  );

-- Also fix the UPDATE policy to include sender_id check
DROP POLICY IF EXISTS "Users can update messages in their conversations" ON public.messages;
CREATE POLICY "Users can update messages in their conversations" 
  ON public.messages 
  FOR UPDATE 
  USING (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.client_id = auth.uid() OR conversations.provider_id = auth.uid())
    )
  );

-- Verify policies are in place
SELECT schemaname, tablename, policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'messages';