-- Force Schema Refresh in Supabase
-- Run this if columns exist but iOS app still shows errors

-- Method 1: Force PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- Method 2: Create a dummy change to trigger schema reload
DO $$
BEGIN
    -- Add a temporary column
    ALTER TABLE public.deals ADD COLUMN IF NOT EXISTS temp_refresh_column boolean DEFAULT false;
    
    -- Wait a moment
    PERFORM pg_sleep(1);
    
    -- Remove the temporary column
    ALTER TABLE public.deals DROP COLUMN IF EXISTS temp_refresh_column;
END $$;

-- Method 3: Verify columns are accessible
SELECT 
    'Testing column access' as test_type,
    n.deal_offer_id as notifications_deal_offer_id,
    d.conversation_id as deals_conversation_id,
    d.deal_offer_id as deals_deal_offer_id
FROM 
    (SELECT deal_offer_id FROM public.notifications LIMIT 1) n,
    (SELECT conversation_id, deal_offer_id FROM public.deals LIMIT 1) d;

-- Show final schema state
SELECT 
    'Final verification' as status,
    EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'deal_offer_id') as notifications_has_deal_offer_id,
    EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'conversation_id') as deals_has_conversation_id,
    EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'deal_offer_id') as deals_has_deal_offer_id; 