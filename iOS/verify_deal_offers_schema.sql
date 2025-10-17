-- Verification script to check if all required columns exist for deal offers functionality
-- Run this after applying deal_offers_migration.sql

-- Check if profiles table has all required columns
SELECT 
    'profiles' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'profiles' AND table_schema = 'public'
AND column_name IN ('user_type', 'bio', 'website', 'is_service_provider')
ORDER BY column_name;

-- Check if deal_offers table exists and has all required columns
SELECT 
    'deal_offers' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'deal_offers' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if deals table has the required new columns
SELECT 
    'deals' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'deals' AND table_schema = 'public'
AND column_name IN ('deal_offer_id', 'conversation_id', 'agreed_terms', 'timeline')
ORDER BY column_name;

-- Check if notifications table has the required column
SELECT 
    'notifications' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'notifications' AND table_schema = 'public'
AND column_name IN ('deal_offer_id')
ORDER BY column_name;

-- Check if proposals table has correct data types
SELECT 
    'proposals' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'proposals' AND table_schema = 'public'
AND column_name IN ('job_id', 'provider_id')
ORDER BY column_name;

-- Verify all required tables exist
SELECT 
    table_name,
    'Table exists' as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('profiles', 'proposals', 'deal_offers', 'deals', 'notifications', 'conversations', 'messages')
ORDER BY table_name;

-- Check constraint on profiles.user_type
SELECT 
    constraint_name,
    check_clause
FROM information_schema.check_constraints 
WHERE constraint_name LIKE '%user_type%' 
AND constraint_schema = 'public';

-- Check foreign key constraints for deal_offers
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name = 'deal_offers'
    AND tc.table_schema = 'public'
ORDER BY tc.constraint_name;

-- Check if messages table has the deal_offer_id column
SELECT 
    'messages' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'messages' AND table_schema = 'public'
AND column_name = 'deal_offer_id';

-- Check if all required indexes exist
SELECT 
    indexname,
    tablename
FROM pg_indexes 
WHERE tablename IN ('deal_offers', 'deals', 'notifications', 'messages')
AND indexname LIKE '%deal_offer%' OR indexname LIKE '%conversation_id%'
ORDER BY tablename, indexname;

-- Check if the trigger functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name IN ('handle_deal_offer_created', 'handle_deal_offer_responded', 'get_deal_count');

-- Check if the triggers exist
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers 
WHERE trigger_schema = 'public'
AND trigger_name IN ('on_deal_offer_created', 'on_deal_offer_responded'); 