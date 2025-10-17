
-- Create notifications table to store notification records
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL, -- 'proposal_received', 'proposal_accepted', 'proposal_rejected', 'job_completed', etc.
  read boolean NOT NULL DEFAULT false,
  related_job_id uuid REFERENCES public.jobs(id) ON DELETE CASCADE,
  related_proposal_id uuid REFERENCES public.proposals(id) ON DELETE CASCADE,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Enable RLS on notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notifications
CREATE POLICY "Users can view their own notifications" 
  ON public.notifications 
  FOR SELECT 
  USING (auth.uid() = user_id);

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update their own notifications" 
  ON public.notifications 
  FOR UPDATE 
  USING (auth.uid() = user_id);

-- Enable realtime for notifications table
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER publication supabase_realtime ADD TABLE public.notifications;

-- Create function to create notifications
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id uuid,
  p_title text,
  p_message text,
  p_type text,
  p_related_job_id uuid DEFAULT NULL,
  p_related_proposal_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  notification_id uuid;
BEGIN
  INSERT INTO public.notifications (user_id, title, message, type, related_job_id, related_proposal_id)
  VALUES (p_user_id, p_title, p_message, p_type, p_related_job_id, p_related_proposal_id)
  RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$;

-- Create trigger function for when proposals are created
CREATE OR REPLACE FUNCTION public.handle_new_proposal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  job_title text;
  job_owner_id uuid;
  provider_name text;
BEGIN
  -- Get job details and owner
  SELECT j.title, j.client_id INTO job_title, job_owner_id
  FROM public.jobs j
  WHERE j.id = NEW.job_id;
  
  -- Get provider name
  SELECT COALESCE(p.full_name, 'Someone') INTO provider_name
  FROM public.profiles p
  WHERE p.id = NEW.provider_id;
  
  -- Create notification for job owner
  PERFORM public.create_notification(
    job_owner_id,
    'New Proposal Received',
    provider_name || ' sent a proposal for "' || job_title || '" with bid amount ৳' || NEW.amount::text,
    'proposal_received',
    NEW.job_id,
    NEW.id
  );
  
  RETURN NEW;
END;
$$;

-- Create trigger for new proposals
CREATE TRIGGER on_proposal_created
  AFTER INSERT ON public.proposals
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_proposal();

-- Create trigger function for when proposal status changes
CREATE OR REPLACE FUNCTION public.handle_proposal_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  job_title text;
  client_name text;
BEGIN
  -- Only proceed if status actually changed
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;
  
  -- Get job title
  SELECT j.title INTO job_title
  FROM public.jobs j
  WHERE j.id = NEW.job_id;
  
  -- Get client name
  SELECT COALESCE(p.full_name, 'Client') INTO client_name
  FROM public.profiles p
  INNER JOIN public.jobs j ON p.id = j.client_id
  WHERE j.id = NEW.job_id;
  
  -- Create notification for proposal owner based on status change
  IF NEW.status = 'accepted' THEN
    PERFORM public.create_notification(
      NEW.provider_id,
      'Proposal Accepted!',
      'Congratulations! ' || client_name || ' accepted your proposal for "' || job_title || '"',
      'proposal_accepted',
      NEW.job_id,
      NEW.id
    );
  ELSIF NEW.status = 'rejected' THEN
    PERFORM public.create_notification(
      NEW.provider_id,
      'Proposal Update',
      client_name || ' declined your proposal for "' || job_title || '"',
      'proposal_rejected',
      NEW.job_id,
      NEW.id
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for proposal status changes
CREATE TRIGGER on_proposal_status_changed
  AFTER UPDATE ON public.proposals
  FOR EACH ROW EXECUTE FUNCTION public.handle_proposal_status_change();
