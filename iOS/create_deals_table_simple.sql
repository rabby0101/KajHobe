-- Simple script: Create deals table with all required columns
-- This will create the table if it doesn't exist or add missing columns if it does

-- Create deals table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.deals (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id bigint NOT NULL,
  client_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  proposal_id uuid NULL,
  conversation_id uuid NULL,
  deal_offer_id uuid NULL,
  agreed_amount integer NOT NULL,
  agreed_terms text NULL,
  timeline text NULL,
  status text NOT NULL DEFAULT 'active',
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  completed_at timestamp with time zone NULL
);

-- Add missing columns if table already exists
ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS conversation_id uuid NULL,
ADD COLUMN IF NOT EXISTS deal_offer_id uuid NULL,
ADD COLUMN IF NOT EXISTS agreed_terms text NULL,
ADD COLUMN IF NOT EXISTS timeline text NULL;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_deals_job_id ON public.deals(job_id);
CREATE INDEX IF NOT EXISTS idx_deals_client_id ON public.deals(client_id);
CREATE INDEX IF NOT EXISTS idx_deals_provider_id ON public.deals(provider_id);
CREATE INDEX IF NOT EXISTS idx_deals_conversation_id ON public.deals(conversation_id);
CREATE INDEX IF NOT EXISTS idx_deals_deal_offer_id ON public.deals(deal_offer_id);

-- Enable RLS
ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;

-- Create basic RLS policies
DROP POLICY IF EXISTS "Users can view deals they are part of" ON public.deals;
CREATE POLICY "Users can view deals they are part of" 
  ON public.deals 
  FOR SELECT 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

DROP POLICY IF EXISTS "Users can insert deals" ON public.deals;  
CREATE POLICY "Users can insert deals" 
  ON public.deals 
  FOR INSERT 
  WITH CHECK (auth.uid() = client_id OR auth.uid() = provider_id);

DROP POLICY IF EXISTS "Users can update deals they are part of" ON public.deals;
CREATE POLICY "Users can update deals they are part of" 
  ON public.deals 
  FOR UPDATE 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- Verify the table was created/updated
SELECT 'Deals table setup complete!' as result; 