-- Fix messaging system for job applications and negotiations (Final Version)

-- Add is_service_provider field to profiles if it doesn't exist
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_service_provider boolean DEFAULT false;

-- Add images field to jobs table for job images
ALTER TABLE public.jobs
ADD COLUMN IF NOT EXISTS images text[] DEFAULT '{}';

-- Create conversations table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id bigint NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create indexes for conversations if they don't exist
CREATE INDEX IF NOT EXISTS idx_conversations_job_id ON public.conversations USING btree (job_id);
CREATE INDEX IF NOT EXISTS idx_conversations_client_id ON public.conversations USING btree (client_id);
CREATE INDEX IF NOT EXISTS idx_conversations_provider_id ON public.conversations USING btree (provider_id);

-- Create messages table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  message_type text NOT NULL DEFAULT 'text',
  attachment_url text NULL,
  read_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create indexes for messages if they don't exist
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages USING btree (conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages USING btree (sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages USING btree (created_at ASC);

-- Now add the new columns for offers support
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS offer_data jsonb NULL,
ADD COLUMN IF NOT EXISTS offer_status text NULL CHECK (offer_status IN ('pending', 'accepted', 'rejected', 'countered')),
ADD COLUMN IF NOT EXISTS is_offer boolean DEFAULT false;

-- Create offers table for tracking negotiation history
CREATE TABLE IF NOT EXISTS public.offers (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  description text,
  timeline text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'countered')),
  parent_offer_id uuid REFERENCES public.offers(id) ON DELETE SET NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create index for offers
CREATE INDEX IF NOT EXISTS idx_offers_conversation_id ON public.offers USING btree (conversation_id);
CREATE INDEX IF NOT EXISTS idx_offers_status ON public.offers USING btree (status);

-- Update conversations table to track accepted offer
ALTER TABLE public.conversations
ADD COLUMN IF NOT EXISTS accepted_offer_id uuid REFERENCES public.offers(id) ON DELETE SET NULL;

-- Enable RLS on all relevant tables
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and recreate them
-- Conversations policies
DROP POLICY IF EXISTS "Users can view conversations they are part of" ON public.conversations;
CREATE POLICY "Users can view conversations they are part of" 
  ON public.conversations 
  FOR SELECT 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

DROP POLICY IF EXISTS "Users can insert conversations" ON public.conversations;
CREATE POLICY "Users can insert conversations" 
  ON public.conversations 
  FOR INSERT 
  WITH CHECK (auth.uid() = client_id OR auth.uid() = provider_id);

DROP POLICY IF EXISTS "Users can update conversations they are part of" ON public.conversations;
CREATE POLICY "Users can update conversations they are part of" 
  ON public.conversations 
  FOR UPDATE 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- Messages policies
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Users can view messages in their conversations" 
  ON public.messages 
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.client_id = auth.uid() OR conversations.provider_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can insert messages in their conversations" ON public.messages;
CREATE POLICY "Users can insert messages in their conversations" 
  ON public.messages 
  FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.client_id = auth.uid() OR conversations.provider_id = auth.uid())
    )
  );

-- Offers policies
DROP POLICY IF EXISTS "Users can view offers in their conversations" ON public.offers;
CREATE POLICY "Users can view offers in their conversations" 
  ON public.offers 
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = offers.conversation_id 
      AND (conversations.client_id = auth.uid() OR conversations.provider_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can create offers in their conversations" ON public.offers;
CREATE POLICY "Users can create offers in their conversations" 
  ON public.offers 
  FOR INSERT 
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = offers.conversation_id 
      AND (conversations.client_id = auth.uid() OR conversations.provider_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Job owners can update offer status" ON public.offers;
CREATE POLICY "Job owners can update offer status" 
  ON public.offers 
  FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      JOIN jobs j ON c.job_id = j.id
      WHERE c.id = offers.conversation_id 
      AND j.client_id = auth.uid()
    )
  );

-- Function to create conversation when provider applies for job
CREATE OR REPLACE FUNCTION public.apply_for_job(
  p_job_id bigint,
  p_provider_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_client_id uuid;
  v_conversation_id uuid;
  v_job_title text;
  v_provider_name text;
BEGIN
  -- Check if user is a service provider
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = p_provider_id 
    AND is_service_provider = true
  ) THEN
    RAISE EXCEPTION 'Only service providers can apply for jobs';
  END IF;

  -- Get job details
  SELECT client_id, title INTO v_client_id, v_job_title
  FROM jobs 
  WHERE id = p_job_id;

  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Job not found';
  END IF;

  -- Check if conversation already exists
  SELECT id INTO v_conversation_id
  FROM conversations
  WHERE job_id = p_job_id 
  AND provider_id = p_provider_id;

  IF v_conversation_id IS NULL THEN
    -- Create new conversation
    INSERT INTO conversations (job_id, client_id, provider_id, status)
    VALUES (p_job_id, v_client_id, p_provider_id, 'active')
    RETURNING id INTO v_conversation_id;

    -- Get provider name
    SELECT COALESCE(full_name, 'A service provider') INTO v_provider_name
    FROM profiles
    WHERE id = p_provider_id;

    -- Create notification for job owner if notifications table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
      INSERT INTO notifications (user_id, title, message, type, related_job_id)
      VALUES (
        v_client_id,
        'New Application',
        v_provider_name || ' has applied for your job: ' || v_job_title,
        'job_application',
        p_job_id
      );
    END IF;
  END IF;

  RETURN v_conversation_id;
END;
$$;

-- Function to send offer in conversation
CREATE OR REPLACE FUNCTION public.send_offer(
  p_conversation_id uuid,
  p_amount numeric,
  p_description text,
  p_timeline text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_offer_id uuid;
  v_sender_id uuid;
  v_message_id uuid;
BEGIN
  v_sender_id := auth.uid();

  -- Verify user is part of conversation
  IF NOT EXISTS (
    SELECT 1 FROM conversations 
    WHERE id = p_conversation_id 
    AND (client_id = v_sender_id OR provider_id = v_sender_id)
  ) THEN
    RAISE EXCEPTION 'You are not part of this conversation';
  END IF;

  -- Create offer
  INSERT INTO offers (conversation_id, sender_id, amount, description, timeline, status)
  VALUES (p_conversation_id, v_sender_id, p_amount, p_description, p_timeline, 'pending')
  RETURNING id INTO v_offer_id;

  -- Create message with offer
  INSERT INTO messages (
    conversation_id, 
    sender_id, 
    content, 
    message_type,
    is_offer,
    offer_data
  )
  VALUES (
    p_conversation_id, 
    v_sender_id, 
    'Sent an offer for ৳' || p_amount::text,
    'offer',
    true,
    jsonb_build_object(
      'offer_id', v_offer_id,
      'amount', p_amount,
      'description', p_description,
      'timeline', p_timeline,
      'status', 'pending'
    )
  )
  RETURNING id INTO v_message_id;

  RETURN v_offer_id;
END;
$$;

-- Function to accept offer (only job owner can accept)
CREATE OR REPLACE FUNCTION public.accept_offer(
  p_offer_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id uuid;
  v_job_id bigint;
  v_client_id uuid;
BEGIN
  -- Get conversation and job details
  SELECT o.conversation_id, c.job_id, j.client_id 
  INTO v_conversation_id, v_job_id, v_client_id
  FROM offers o
  JOIN conversations c ON o.conversation_id = c.id
  JOIN jobs j ON c.job_id = j.id
  WHERE o.id = p_offer_id;

  -- Verify the current user is the job owner
  IF v_client_id != auth.uid() THEN
    RAISE EXCEPTION 'Only the job owner can accept offers';
  END IF;

  -- Update offer status
  UPDATE offers 
  SET status = 'accepted', updated_at = now()
  WHERE id = p_offer_id;

  -- Update conversation with accepted offer
  UPDATE conversations
  SET accepted_offer_id = p_offer_id, status = 'accepted'
  WHERE id = v_conversation_id;

  -- Create system message
  INSERT INTO messages (
    conversation_id, 
    sender_id, 
    content, 
    message_type
  )
  VALUES (
    v_conversation_id, 
    auth.uid(), 
    'Offer accepted! The deal has been finalized.',
    'system'
  );

  -- Update job status
  UPDATE jobs
  SET status = 'in_progress'
  WHERE id = v_job_id;

  RETURN true;
END;
$$;

-- Update RLS policies for jobs
DROP POLICY IF EXISTS "Anyone can view jobs" ON public.jobs;
DROP POLICY IF EXISTS "Anyone can view open jobs" ON public.jobs;

CREATE POLICY "Anyone can view open jobs" ON public.jobs
  FOR SELECT USING (status = 'open' OR client_id = auth.uid());

-- Add helpful indexes
CREATE INDEX IF NOT EXISTS idx_profiles_is_service_provider ON public.profiles USING btree (is_service_provider);
CREATE INDEX IF NOT EXISTS idx_messages_is_offer ON public.messages USING btree (is_offer);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON public.messages USING btree (conversation_id, created_at);

-- Enable realtime for offers table
ALTER TABLE public.offers REPLICA IDENTITY FULL;

-- Check if publication exists before adding table
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.offers;
  END IF;
END $$; 