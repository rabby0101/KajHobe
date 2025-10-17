-- Fix conflicting RLS policies for messages table
-- Drop existing policies that might be conflicting
DROP POLICY IF EXISTS "Users can insert messages in conversations they are part of" ON public.messages;
DROP POLICY IF EXISTS "Users can send messages in their conversations" ON public.messages;

-- Create a single, clear policy for inserting messages
CREATE POLICY "Users can send messages in conversations they are part of" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM public.conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.client_id = auth.uid() OR conversations.provider_id = auth.uid())
    )
  );

-- Also ensure the conversation_id is properly handled as UUID
-- Add a function to help with conversation lookups
CREATE OR REPLACE FUNCTION check_user_in_conversation(conversation_uuid uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.conversations 
    WHERE id = conversation_uuid 
    AND (client_id = auth.uid() OR provider_id = auth.uid())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 