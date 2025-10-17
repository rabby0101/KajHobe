-- ===================================================
-- Complete Show Interest Workflow Migration
-- ===================================================

-- 1. Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type text NOT NULL,
  job_id uuid NOT NULL,
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  message text NULL,
  offer_data jsonb NULL,
  actioned_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  CONSTRAINT notifications_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT notifications_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT notifications_status_check CHECK (status IN ('pending', 'accepted', 'rejected'))
);

-- 2. Create indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_to_user_id ON public.notifications(to_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_job_id ON public.notifications(job_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at);

-- 3. Create job_interests table
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

-- 4. Create indexes for job_interests
CREATE INDEX IF NOT EXISTS idx_job_interests_job_id ON public.job_interests(job_id);
CREATE INDEX IF NOT EXISTS idx_job_interests_provider_id ON public.job_interests(provider_id);

-- 5. Update existing tables
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS offer_data jsonb NULL;

ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS conversation_id uuid NULL,
ADD COLUMN IF NOT EXISTS agreed_terms text NULL,
ADD COLUMN IF NOT EXISTS timeline text NULL;

-- 6. Add foreign key constraint for deals.conversation_id (with check)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'deals_conversation_id_fkey'
        AND table_name = 'deals'
    ) THEN
        ALTER TABLE public.deals 
        ADD CONSTRAINT deals_conversation_id_fkey 
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 7. Enable RLS on new tables
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_interests ENABLE ROW LEVEL SECURITY;

-- 8. Create RLS policies for notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can create notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;

CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = to_user_id);

CREATE POLICY "Users can create notifications" ON public.notifications
  FOR INSERT WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = to_user_id);

-- 9. Create RLS policies for job_interests
DROP POLICY IF EXISTS "Users can view all interests" ON public.job_interests;
DROP POLICY IF EXISTS "Users can create their own interests" ON public.job_interests;

CREATE POLICY "Users can view all interests" ON public.job_interests
  FOR SELECT USING (true);

CREATE POLICY "Users can create their own interests" ON public.job_interests
  FOR INSERT WITH CHECK (auth.uid() = provider_id);

-- 10. Create functions
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

-- 11. Drop existing triggers if they exist
DROP TRIGGER IF EXISTS on_interest_acceptance ON notifications;
DROP TRIGGER IF EXISTS on_offer_acceptance ON notifications;

-- 12. Create triggers
CREATE TRIGGER on_interest_acceptance
AFTER UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION handle_interest_acceptance();

CREATE TRIGGER on_offer_acceptance
AFTER UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION handle_offer_acceptance(); 