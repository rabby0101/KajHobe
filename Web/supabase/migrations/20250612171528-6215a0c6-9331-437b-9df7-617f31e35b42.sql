
-- Create deals table
CREATE TABLE public.deals (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  proposal_id UUID NOT NULL REFERENCES public.proposals(id) ON DELETE CASCADE,
  agreed_amount INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
  completed_at TIMESTAMP WITH TIME ZONE NULL
);

-- Enable RLS
ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;

-- RLS policies for deals
CREATE POLICY "Users can view deals they are part of" 
  ON public.deals 
  FOR SELECT 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

CREATE POLICY "Clients can create deals" 
  ON public.deals 
  FOR INSERT 
  WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can update deals they are part of" 
  ON public.deals 
  FOR UPDATE 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- Create notification triggers for deals
CREATE OR REPLACE FUNCTION create_deal_notifications()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify provider when deal is created
  INSERT INTO public.notifications (user_id, title, message, type, related_job_id)
  VALUES (
    NEW.provider_id,
    'Deal Created!',
    'A new deal has been created for your proposal.',
    'deal_created',
    NEW.job_id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_deal_notifications()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify both parties when deal is completed
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    INSERT INTO public.notifications (user_id, title, message, type, related_job_id)
    VALUES 
    (NEW.client_id, 'Deal Completed!', 'Your deal has been marked as completed.', 'deal_completed', NEW.job_id),
    (NEW.provider_id, 'Deal Completed!', 'Your deal has been marked as completed.', 'deal_completed', NEW.job_id);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER on_deal_created
  AFTER INSERT ON public.deals
  FOR EACH ROW EXECUTE FUNCTION create_deal_notifications();

CREATE TRIGGER on_deal_updated
  AFTER UPDATE ON public.deals
  FOR EACH ROW EXECUTE FUNCTION update_deal_notifications();
