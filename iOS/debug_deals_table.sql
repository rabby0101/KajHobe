-- Debug script: Check the current state of the deals table
-- Run this to see what's actually in your database

-- 1. Check if deals table exists
SELECT 
    table_name,
    table_schema
FROM information_schema.tables 
WHERE table_name = 'deals' 
AND table_schema = 'public';

-- 2. If deals table exists, show all its columns
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'deals' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check if conversations table exists
SELECT 
    table_name,
    table_schema
FROM information_schema.tables 
WHERE table_name = 'conversations' 
AND table_schema = 'public';

-- 4. Show all tables in public schema
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name; 