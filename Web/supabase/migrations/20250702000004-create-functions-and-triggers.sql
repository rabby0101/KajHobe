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

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS on_interest_acceptance ON notifications;
DROP TRIGGER IF EXISTS on_offer_acceptance ON notifications;

-- Create triggers
CREATE TRIGGER on_interest_acceptance
AFTER UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION handle_interest_acceptance();

CREATE TRIGGER on_offer_acceptance
AFTER UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION handle_offer_acceptance(); 