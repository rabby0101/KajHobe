-- Diagnostic Script: Check Current Database Schema
-- Run this FIRST to see what's actually in your database

-- 1. Check if tables exist
SELECT 
    table_name,
    CASE 
        WHEN table_name IS NOT NULL THEN '✅ Table exists'
        ELSE '❌ Table missing'
    END as status
FROM (
    SELECT 'deal_offers' as expected_table
    UNION ALL SELECT 'deals'
    UNION ALL SELECT 'notifications'
    UNION ALL SELECT 'conversations'
    UNION ALL SELECT 'messages'
) expected
LEFT JOIN information_schema.tables actual
    ON actual.table_name = expected.expected_table
    AND actual.table_schema = 'public'
ORDER BY expected.expected_table;

-- 2. Check deal_offers table structure (if it exists)
SELECT 
    '=== DEAL_OFFERS TABLE ===' as section,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'deal_offers' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check notifications table structure
SELECT 
    '=== NOTIFICATIONS TABLE ===' as section,
    column_name,
    data_type,
    is_nullable,
    CASE 
        WHEN column_name = 'deal_offer_id' THEN '⚠️ REQUIRED COLUMN'
        ELSE ''
    END as note
FROM information_schema.columns 
WHERE table_name = 'notifications' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Check deals table structure
SELECT 
    '=== DEALS TABLE ===' as section,
    column_name,
    data_type,
    is_nullable,
    CASE 
        WHEN column_name IN ('conversation_id', 'deal_offer_id', 'agreed_terms', 'timeline') 
        THEN '⚠️ REQUIRED COLUMN'
        ELSE ''
    END as note
FROM information_schema.columns 
WHERE table_name = 'deals' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 5. Check if required columns are missing
SELECT 
    'Missing columns check:' as check_type,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'notifications' 
            AND column_name = 'deal_offer_id' 
            AND table_schema = 'public'
        ) THEN '❌ notifications.deal_offer_id is MISSING'
        ELSE '✅ notifications.deal_offer_id exists'
    END as notifications_check,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'deals' 
            AND column_name = 'conversation_id' 
            AND table_schema = 'public'
        ) THEN '❌ deals.conversation_id is MISSING'
        ELSE '✅ deals.conversation_id exists'
    END as deals_conversation_check,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'deals' 
            AND column_name = 'deal_offer_id' 
            AND table_schema = 'public'
        ) THEN '❌ deals.deal_offer_id is MISSING'
        ELSE '✅ deals.deal_offer_id exists'
    END as deals_offer_check;

-- 6. Check foreign key constraints
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'public'
AND tc.table_name IN ('deals', 'notifications', 'deal_offers')
AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, tc.constraint_name; 