-- Final Fix for Deal Schema Issues
-- This resolves the "conversation_id" and "deal_offer_id" column errors

-- Step 1: Add missing conversation_id column to deals table
DO $$
BEGIN
    -- Check if conversation_id column exists in deals table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'deals' 
        AND column_name = 'conversation_id' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.deals 
        ADD COLUMN conversation_id uuid NULL;
        
        -- Create index for performance
        CREATE INDEX idx_deals_conversation_id ON public.deals(conversation_id);
        
        -- Add foreign key constraint if conversations table exists
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'conversations' 
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE public.deals 
            ADD CONSTRAINT deals_conversation_id_fkey 
            FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;
        END IF;
        
        RAISE NOTICE 'Added conversation_id column to deals table';
    ELSE
        RAISE NOTICE 'conversation_id column already exists in deals table';
    END IF;
END $$;

-- Step 2: Add missing deal_offer_id column to notifications table
DO $$
BEGIN
    -- Check if deal_offer_id column exists in notifications table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'deal_offer_id' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN deal_offer_id uuid NULL;
        
        -- Create index for performance
        CREATE INDEX idx_notifications_deal_offer_id ON public.notifications(deal_offer_id);
        
        -- Add foreign key constraint if deal_offers table exists
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'deal_offers' 
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE public.notifications 
            ADD CONSTRAINT notifications_deal_offer_id_fkey 
            FOREIGN KEY (deal_offer_id) REFERENCES public.deal_offers(id) ON DELETE SET NULL;
        END IF;
        
        RAISE NOTICE 'Added deal_offer_id column to notifications table';
    ELSE
        RAISE NOTICE 'deal_offer_id column already exists in notifications table';
    END IF;
END $$;

-- Step 3: Add missing deal_offer_id column to deals table (for reference)
DO $$
BEGIN
    -- Check if deal_offer_id column exists in deals table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'deals' 
        AND column_name = 'deal_offer_id' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.deals 
        ADD COLUMN deal_offer_id uuid NULL;
        
        -- Create index for performance
        CREATE INDEX idx_deals_deal_offer_id ON public.deals(deal_offer_id);
        
        -- Add foreign key constraint if deal_offers table exists
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'deal_offers' 
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE public.deals 
            ADD CONSTRAINT deals_deal_offer_id_fkey 
            FOREIGN KEY (deal_offer_id) REFERENCES public.deal_offers(id) ON DELETE SET NULL;
        END IF;
        
        RAISE NOTICE 'Added deal_offer_id column to deals table';
    ELSE
        RAISE NOTICE 'deal_offer_id column already exists in deals table';
    END IF;
END $$;

-- Step 4: Ensure deal_offers table exists with proper structure
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'deal_offers' 
        AND table_schema = 'public'
    ) THEN
        -- Create deal_offers table if it doesn't exist
        CREATE TABLE public.deal_offers (
            id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
            conversation_id uuid NOT NULL,
            provider_id uuid NOT NULL,
            client_id uuid NOT NULL,
            job_id uuid NOT NULL,
            amount integer NOT NULL,
            terms text NULL,
            timeline text NULL,
            status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
            created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
            responded_at timestamp with time zone NULL
        );
        
        -- Create indexes
        CREATE INDEX idx_deal_offers_conversation_id ON public.deal_offers(conversation_id);
        CREATE INDEX idx_deal_offers_job_id ON public.deal_offers(job_id);
        CREATE INDEX idx_deal_offers_provider_id ON public.deal_offers(provider_id);
        CREATE INDEX idx_deal_offers_client_id ON public.deal_offers(client_id);
        CREATE INDEX idx_deal_offers_status ON public.deal_offers(status);
        
        -- Enable RLS
        ALTER TABLE public.deal_offers ENABLE ROW LEVEL SECURITY;
        
        -- Create RLS policies
        CREATE POLICY "Users can view deal offers they are part of" 
            ON public.deal_offers 
            FOR SELECT 
            USING (auth.uid() = client_id OR auth.uid() = provider_id);
        
        CREATE POLICY "Providers can create deal offers" 
            ON public.deal_offers 
            FOR INSERT 
            WITH CHECK (auth.uid() = provider_id);
        
        CREATE POLICY "Clients can update deal offers" 
            ON public.deal_offers 
            FOR UPDATE 
            USING (auth.uid() = client_id);
            
        RAISE NOTICE 'Created deal_offers table';
    ELSE
        RAISE NOTICE 'deal_offers table already exists';
    END IF;
END $$;

-- Step 5: Update DealInsert model to include conversation_id
-- This step is a reminder to update the Swift code - the iOS app's DealInsert model
-- should include conversation_id field to match the database schema

-- Step 6: Force schema cache reload
SELECT pg_notify('pgrst', 'reload schema');

-- Step 7: Verify the fix
SELECT 
    'Column verification:' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'deals' 
            AND column_name = 'conversation_id' 
            AND table_schema = 'public'
        ) THEN '✅ deals.conversation_id exists'
        ELSE '❌ deals.conversation_id MISSING'
    END as deals_conversation_id,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'deals' 
            AND column_name = 'deal_offer_id' 
            AND table_schema = 'public'
        ) THEN '✅ deals.deal_offer_id exists'
        ELSE '❌ deals.deal_offer_id MISSING'
    END as deals_deal_offer_id,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'notifications' 
            AND column_name = 'deal_offer_id' 
            AND table_schema = 'public'
        ) THEN '✅ notifications.deal_offer_id exists'
        ELSE '❌ notifications.deal_offer_id MISSING'
    END as notifications_deal_offer_id;

-- Step 8: Show current deals table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'deals' 
AND table_schema = 'public'
ORDER BY ordinal_position;