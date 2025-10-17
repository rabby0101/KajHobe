-- Create function to handle negotiation message notifications
CREATE OR REPLACE FUNCTION public.handle_negotiation_message()
RETURNS TRIGGER AS $$
DECLARE
  conversation_data RECORD;
  sender_name text;
  recipient_id uuid;
  job_title text;
  negotiation_type text;
  amount_text text;
BEGIN
  -- Only handle negotiation type messages
  IF NEW.message_type != 'negotiation' THEN
    RETURN NEW;
  END IF;
  
  -- Get conversation details including job and participants
  SELECT c.*, j.title as job_title
  INTO conversation_data
  FROM public.conversations c
  JOIN public.jobs j ON c.job_id = j.id
  WHERE c.id = NEW.conversation_id;
  
  -- Get sender name
  SELECT COALESCE(p.full_name, 'Someone') INTO sender_name
  FROM public.profiles p
  WHERE p.id = NEW.sender_id;
  
  -- Determine who should receive the notification (the other participant)
  IF NEW.sender_id = conversation_data.client_id THEN
    recipient_id := conversation_data.provider_id;
  ELSE
    recipient_id := conversation_data.client_id;
  END IF;
  
  -- Extract negotiation data
  negotiation_type := NEW.negotiation_data->>'type';
  amount_text := '৳' || (NEW.negotiation_data->>'amount');
  
  -- Create appropriate notification based on negotiation type
  IF negotiation_type = 'counter_offer' THEN
    PERFORM public.create_notification(
      recipient_id,
      'Counter Offer Received',
      sender_name || ' sent a counter offer of ' || amount_text || ' for "' || conversation_data.job_title || '"',
      'counter_proposal',
      conversation_data.job_id,
      (NEW.negotiation_data->>'proposalId')::uuid
    );
  ELSIF negotiation_type = 'proposal' THEN
    PERFORM public.create_notification(
      recipient_id,
      'New Proposal Received',
      sender_name || ' sent a proposal of ' || amount_text || ' for "' || conversation_data.job_title || '"',
      'proposal_received',
      conversation_data.job_id,
      (NEW.negotiation_data->>'proposalId')::uuid
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for negotiation messages
DROP TRIGGER IF EXISTS trigger_handle_negotiation_message ON public.messages;
CREATE TRIGGER trigger_handle_negotiation_message
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_negotiation_message();