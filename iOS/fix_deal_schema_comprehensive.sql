-- Comprehensive Deal Schema Fix
-- Run this in your Supabase SQL Editor to fix deal acceptance/rejection errors

-- Step 1: First check if deal_offers table exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'deal_offers' AND table_schema = 'public') THEN
        -- Create deal_offers table if it doesn't exist
        CREATE TABLE public.deal_offers (
            id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
            conversation_id uuid NOT NULL,
            provider_id uuid NOT NULL,
            client_id uuid NOT NULL,
            job_id bigint NOT NULL,
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
    END IF;
END $$;

-- Step 2: Add missing columns to notifications table
DO $$
BEGIN
    -- Check if deal_offer_id column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'deal_offer_id' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN deal_offer_id uuid NULL;
    END IF;
END $$;

-- Step 3: Add missing columns to deals table
DO $$
BEGIN
    -- Add conversation_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'deals' 
        AND column_name = 'conversation_id' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.deals 
        ADD COLUMN conversation_id uuid NULL;
    END IF;
    
    -- Add deal_offer_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'deals' 
        AND column_name = 'deal_offer_id' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.deals 
        ADD COLUMN deal_offer_id uuid NULL;
    END IF;
    
    -- Add agreed_terms if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'deals' 
        AND column_name = 'agreed_terms' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.deals 
        ADD COLUMN agreed_terms text NULL;
    END IF;
    
    -- Add timeline if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'deals' 
        AND column_name = 'timeline' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.deals 
        ADD COLUMN timeline text NULL;
    END IF;
END $$;

-- Step 4: Create indexes only if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_notifications_deal_offer_id') THEN
        CREATE INDEX idx_notifications_deal_offer_id ON public.notifications(deal_offer_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_deals_conversation_id') THEN
        CREATE INDEX idx_deals_conversation_id ON public.deals(conversation_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_deals_deal_offer_id') THEN
        CREATE INDEX idx_deals_deal_offer_id ON public.deals(deal_offer_id);
    END IF;
END $$;

-- Step 5: Add foreign key constraints only if they don't exist
DO $$
BEGIN
    -- Add foreign key for notifications.deal_offer_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'notifications_deal_offer_id_fkey'
        AND table_name = 'notifications'
    ) THEN
        ALTER TABLE public.notifications 
        ADD CONSTRAINT notifications_deal_offer_id_fkey 
        FOREIGN KEY (deal_offer_id) REFERENCES public.deal_offers(id) ON DELETE SET NULL;
    END IF;
    
    -- Add foreign key for deals.conversation_id
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'conversations' AND table_schema = 'public') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'deals_conversation_id_fkey'
            AND table_name = 'deals'
        ) THEN
            ALTER TABLE public.deals 
            ADD CONSTRAINT deals_conversation_id_fkey 
            FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;
        END IF;
    END IF;
    
    -- Add foreign key for deals.deal_offer_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'deals_deal_offer_id_fkey'
        AND table_name = 'deals'
    ) THEN
        ALTER TABLE public.deals 
        ADD CONSTRAINT deals_deal_offer_id_fkey 
        FOREIGN KEY (deal_offer_id) REFERENCES public.deal_offers(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Step 6: Refresh schema cache
-- This forces Supabase to reload the schema
SELECT pg_notify('pgrst', 'reload schema');

-- Step 7: Verify all columns exist
SELECT 
    t.table_name,
    t.column_name,
    t.data_type,
    t.is_nullable,
    CASE 
        WHEN t.column_name = ANY(ARRAY['deal_offer_id', 'conversation_id', 'agreed_terms', 'timeline']) 
        THEN '✅ Required column'
        ELSE '✓ Column exists'
    END as status
FROM (
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
    
    UNION ALL
    
    SELECT 
        'deal_offers' as table_name,
        column_name,
        data_type,
        is_nullable
    FROM information_schema.columns 
    WHERE table_name = 'deal_offers' 
    AND table_schema = 'public'
    AND column_name IN ('id', 'conversation_id', 'status')
) t
ORDER BY t.table_name, t.column_name;

-- Step 8: Show current table structures
SELECT 
    'Current schema status:' as message,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'deal_offers' AND table_schema = 'public') as deal_offers_columns,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'deals' AND table_schema = 'public' AND column_name IN ('conversation_id', 'deal_offer_id')) as deals_new_columns,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'notifications' AND table_schema = 'public' AND column_name = 'deal_offer_id') as notifications_new_columns; 