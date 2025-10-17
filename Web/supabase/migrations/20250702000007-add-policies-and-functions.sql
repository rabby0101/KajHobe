-- Run this AFTER running the first migration (20250702000006-simple-notifications-setup.sql)

-- 1. Create indexes
CREATE INDEX idx_notifications_to_user_id ON public.notifications(to_user_id);
CREATE INDEX idx_notifications_job_id ON public.notifications(job_id);
CREATE INDEX idx_notifications_status ON public.notifications(status);
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at);
CREATE INDEX idx_job_interests_job_id ON public.job_interests(job_id);
CREATE INDEX idx_job_interests_provider_id ON public.job_interests(provider_id);

-- 2. Add foreign key for deals.conversation_id
ALTER TABLE public.deals ADD CONSTRAINT deals_conversation_id_fkey 
FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;

-- 3. Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_interests ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies for notifications
CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = to_user_id);

CREATE POLICY "Users can create notifications" ON public.notifications
  FOR INSERT WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = to_user_id);

-- 5. Create RLS policies for job_interests
CREATE POLICY "Users can view all interests" ON public.job_interests
  FOR SELECT USING (true);

CREATE POLICY "Users can create their own interests" ON public.job_interests
  FOR INSERT WITH CHECK (auth.uid() = provider_id);

-- 6. Create functions
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

-- 7. Create triggers
CREATE TRIGGER on_interest_acceptance
AFTER UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION handle_interest_acceptance();

CREATE TRIGGER on_offer_acceptance
AFTER UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION handle_offer_acceptance(); 