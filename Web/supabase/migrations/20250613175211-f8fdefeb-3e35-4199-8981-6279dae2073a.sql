-- Create trigger function for message notifications
CREATE OR REPLACE FUNCTION public.handle_new_message()
RETURNS TRIGGER AS $$
DECLARE
  conversation_data RECORD;
  sender_name text;
  recipient_id uuid;
BEGIN
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
  
  -- Create notification for the recipient
  PERFORM public.create_notification(
    recipient_id,
    'New Message',
    sender_name || ' sent you a message about "' || conversation_data.job_title || '"',
    'message_received',
    conversation_data.job_id,
    NULL
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for message notifications
CREATE TRIGGER on_message_received
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION handle_new_message();