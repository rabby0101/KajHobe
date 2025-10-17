-- Fix Deal Schema Errors - Add missing columns for iOS app
-- Run this in your Supabase SQL Editor to fix the deal acceptance/rejection errors

-- 1. Add missing deal_offer_id column to notifications table
ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS deal_offer_id uuid NULL;

-- 2. Add missing columns to deals table that the iOS app expects
ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS conversation_id uuid NULL,
ADD COLUMN IF NOT EXISTS deal_offer_id uuid NULL,
ADD COLUMN IF NOT EXISTS agreed_terms text NULL,
ADD COLUMN IF NOT EXISTS timeline text NULL;

-- 3. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_notifications_deal_offer_id ON public.notifications(deal_offer_id);
CREATE INDEX IF NOT EXISTS idx_deals_conversation_id ON public.deals(conversation_id);
CREATE INDEX IF NOT EXISTS idx_deals_deal_offer_id ON public.deals(deal_offer_id);

-- 4. Verify the columns were added successfully
SELECT 
    'notifications' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'notifications' 
AND table_schema = 'public'
AND column_name = 'deal_offer_id'

UNION ALL

SELECT 
    'deals' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'deals' 
AND table_schema = 'public'
AND column_name IN ('conversation_id', 'deal_offer_id', 'agreed_terms', 'timeline')
ORDER BY table_name, column_name; 