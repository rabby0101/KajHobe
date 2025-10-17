-- Quick fix: Add missing conversation_id column to deals table
-- This allows the Swift app to work while we resolve schema conflicts

-- Add conversation_id column to deals table (nullable, no foreign key for now)
ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS conversation_id uuid NULL;

-- Add other missing columns that the Swift code expects
ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS deal_offer_id uuid NULL,
ADD COLUMN IF NOT EXISTS agreed_terms text NULL,
ADD COLUMN IF NOT EXISTS timeline text NULL;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_deals_conversation_id ON public.deals(conversation_id);
CREATE INDEX IF NOT EXISTS idx_deals_deal_offer_id ON public.deals(deal_offer_id);

-- Verify the columns were added
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'deals' 
AND table_schema = 'public'
AND column_name IN ('conversation_id', 'deal_offer_id', 'agreed_terms', 'timeline')
ORDER BY column_name; 