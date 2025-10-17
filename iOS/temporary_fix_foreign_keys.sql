-- Temporary Fix: Remove and Re-add Foreign Keys
-- This forces PostgREST to recognize the columns

-- Step 1: Drop the foreign key constraints temporarily
ALTER TABLE public.notifications 
DROP CONSTRAINT IF EXISTS notifications_deal_offer_id_fkey;

ALTER TABLE public.deals 
DROP CONSTRAINT IF EXISTS deals_conversation_id_fkey,
DROP CONSTRAINT IF EXISTS deals_deal_offer_id_fkey;

-- Step 2: Force schema reload
SELECT pg_notify('pgrst', 'reload schema');

-- Step 3: Wait a moment
SELECT pg_sleep(2);

-- Step 4: Re-add the foreign key constraints
ALTER TABLE public.notifications 
ADD CONSTRAINT notifications_deal_offer_id_fkey 
FOREIGN KEY (deal_offer_id) REFERENCES public.deal_offers(id) ON DELETE SET NULL;

ALTER TABLE public.deals 
ADD CONSTRAINT deals_conversation_id_fkey 
FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;

ALTER TABLE public.deals 
ADD CONSTRAINT deals_deal_offer_id_fkey 
FOREIGN KEY (deal_offer_id) REFERENCES public.deal_offers(id) ON DELETE SET NULL;

-- Step 5: Force another schema reload
SELECT pg_notify('pgrst', 'reload schema');

-- Step 6: Verify
SELECT 
    'Foreign keys re-added. Testing column access:' as status,
    (SELECT COUNT(*) FROM notifications WHERE deal_offer_id IS NOT NULL OR deal_offer_id IS NULL) as notifications_test,
    (SELECT COUNT(*) FROM deals WHERE conversation_id IS NOT NULL OR conversation_id IS NULL) as deals_conversation_test,
    (SELECT COUNT(*) FROM deals WHERE deal_offer_id IS NOT NULL OR deal_offer_id IS NULL) as deals_offer_test; 