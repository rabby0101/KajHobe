-- Force PostgREST Schema Reload
-- Run this to force Supabase to recognize the columns

-- Method 1: Direct notification
SELECT pg_notify('pgrst', 'reload schema');
SELECT pg_notify('pgrst', 'reload config');

-- Method 2: Force a schema change to trigger reload
DO $$
DECLARE
    dummy_exists boolean;
BEGIN
    -- Check if dummy column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'deals' 
        AND column_name = '_force_refresh_' 
        AND table_schema = 'public'
    ) INTO dummy_exists;
    
    IF dummy_exists THEN
        -- Drop it if it exists
        ALTER TABLE public.deals DROP COLUMN _force_refresh_;
    ELSE
        -- Add it if it doesn't exist
        ALTER TABLE public.deals ADD COLUMN _force_refresh_ boolean DEFAULT false;
        -- Then immediately drop it
        ALTER TABLE public.deals DROP COLUMN _force_refresh_;
    END IF;
END $$;

-- Method 3: Update a RLS policy to force reload
DROP POLICY IF EXISTS "temp_force_refresh" ON public.deals;
CREATE POLICY "temp_force_refresh" ON public.deals FOR SELECT USING (true);
DROP POLICY "temp_force_refresh" ON public.deals;

-- Method 4: Touch the schema_migrations table if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'schema_migrations' 
        AND table_schema = 'public'
    ) THEN
        -- Insert a dummy migration record
        INSERT INTO schema_migrations (version) 
        VALUES ('force_refresh_' || extract(epoch from now())::text)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- Verify the columns are queryable
DO $$
DECLARE
    test_result record;
BEGIN
    -- Test querying the columns
    SELECT 
        deal_offer_id IS NOT NULL as has_deal_offer_id
    INTO test_result
    FROM public.notifications 
    LIMIT 1;
    
    RAISE NOTICE 'Notifications table deal_offer_id column is accessible';
    
    SELECT 
        conversation_id IS NOT NULL as has_conversation_id,
        deal_offer_id IS NOT NULL as has_deal_offer_id
    INTO test_result
    FROM public.deals 
    LIMIT 1;
    
    RAISE NOTICE 'Deals table new columns are accessible';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error testing columns: %', SQLERRM;
END $$;

-- Final check
SELECT 
    'Schema reload attempted. Columns status:' as message,
    EXISTS(SELECT deal_offer_id FROM notifications LIMIT 1) as can_query_notifications_deal_offer_id,
    EXISTS(SELECT conversation_id FROM deals LIMIT 1) as can_query_deals_conversation_id,
    EXISTS(SELECT deal_offer_id FROM deals LIMIT 1) as can_query_deals_deal_offer_id; 