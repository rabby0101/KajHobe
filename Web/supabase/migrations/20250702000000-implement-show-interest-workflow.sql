-- Drop the old proposals and bids tables (keeping data archived if needed)
-- You can comment these out if you want to keep the data
-- DROP TABLE IF EXISTS public.proposals CASCADE;
-- DROP TABLE IF EXISTS public.bids CASCADE;

-- Create notifications table for interest requests and offers
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type text NOT NULL, -- 'interest_request', 'offer_received'
  job_id uuid NOT NULL,
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
  message text NULL,
  offer_data jsonb NULL, -- For offer notifications: price, timeline, conditions
  actioned_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  CONSTRAINT notifications_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT notifications_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT notifications_status_check CHECK (status IN ('pending', 'accepted', 'rejected'))
);

-- Create indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_to_user_id ON public.notifications(to_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_job_id ON public.notifications(job_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);

-- Add offer_data to messages table for offer messages
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS offer_data jsonb NULL;

-- Update deals table to link with conversations
ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS conversation_id uuid NULL REFERENCES conversations(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS agreed_terms text NULL,
ADD COLUMN IF NOT EXISTS timeline text NULL;

-- Create a table to track user interests (to know if user already showed interest)
CREATE TABLE IF NOT EXISTS public.job_interests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT job_interests_pkey PRIMARY KEY (id),
  CONSTRAINT job_interests_unique UNIQUE (job_id, provider_id),
  CONSTRAINT job_interests_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  CONSTRAINT job_interests_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create RLS policies for notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = to_user_id);

CREATE POLICY "Users can create notifications" ON public.notifications
  FOR INSERT WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = to_user_id);

-- Create RLS policies for job_interests
ALTER TABLE public.job_interests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all interests" ON public.job_interests
  FOR SELECT USING (true);

CREATE POLICY "Users can create their own interests" ON public.job_interests
  FOR INSERT WITH CHECK (auth.uid() = provider_id);

-- Function to handle interest acceptance
CREATE OR REPLACE FUNCTION handle_interest_acceptance()
RETURNS TRIGGER AS $$
BEGIN
  -- When an interest is accepted, create a conversation
  IF NEW.type = 'interest_request' AND NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    -- Check if conversation already exists
    IF NOT EXISTS (
      SELECT 1 FROM conversations 
      WHERE job_id = NEW.job_id 
      AND client_id = NEW.to_user_id 
      AND provider_id = NEW.from_user_id
    ) THEN
      -- Create new conversation
      INSERT INTO conversations (job_id, client_id, provider_id, status)
      VALUES (NEW.job_id, NEW.to_user_id, NEW.from_user_id, 'active');
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for interest acceptance
CREATE TRIGGER on_interest_acceptance
AFTER UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION handle_interest_acceptance();

-- Function to handle offer acceptance
CREATE OR REPLACE FUNCTION handle_offer_acceptance()
RETURNS TRIGGER AS $$
DECLARE
  v_conversation_id uuid;
  v_offer_data jsonb;
BEGIN
  -- When an offer is accepted, create a deal
  IF NEW.type = 'offer_received' AND NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    -- Get conversation id
    SELECT id INTO v_conversation_id
    FROM conversations
    WHERE job_id = NEW.job_id 
    AND client_id = NEW.to_user_id 
    AND provider_id = NEW.from_user_id
    LIMIT 1;
    
    -- Get offer data
    v_offer_data := NEW.offer_data;
    
    -- Create deal
    INSERT INTO deals (
      job_id, 
      client_id, 
      provider_id, 
      conversation_id,
      agreed_amount, 
      agreed_terms,
      timeline,
      status
    )
    VALUES (
      NEW.job_id,
      NEW.to_user_id,
      NEW.from_user_id,
      v_conversation_id,
      (v_offer_data->>'amount')::integer,
      v_offer_data->>'terms',
      v_offer_data->>'timeline',
      'active'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for offer acceptance
CREATE TRIGGER on_offer_acceptance
AFTER UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION handle_offer_acceptance(); 