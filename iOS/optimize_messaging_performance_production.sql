-- Production version: Optimize messaging performance with concurrent index creation
-- ⚠️ IMPORTANT: Run these statements ONE AT A TIME in separate transactions
-- Do not run this entire script at once - it will fail due to CONCURRENTLY restrictions

-- Step 1: Create the RPC functions first (can be run together)
-- =====================================================

-- Function to get the latest message for multiple conversations in a single query
CREATE OR REPLACE FUNCTION get_latest_messages_for_conversations(conversation_ids text[])
RETURNS TABLE (
    id text,
    conversation_id text,
    sender_id text,
    content text,
    message_type text,
    attachment_url text,
    read_at timestamp with time zone,
    created_at timestamp with time zone,
    negotiation_data jsonb,
    original_proposal_id text
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (m.conversation_id)
        m.id,
        m.conversation_id,
        m.sender_id,
        m.content,
        m.message_type,
        m.attachment_url,
        m.read_at,
        m.created_at,
        m.negotiation_data,
        m.original_proposal_id
    FROM messages m
    WHERE m.conversation_id = ANY(conversation_ids)
    ORDER BY m.conversation_id, m.created_at DESC;
END;
$$;

-- Function to get unread message counts for multiple conversations in a single query
CREATE OR REPLACE FUNCTION get_unread_counts_for_conversations(conversation_ids text[], user_id text)
RETURNS TABLE (
    conversation_id text,
    unread_count bigint
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.conversation_id,
        COUNT(*)::bigint as unread_count
    FROM messages m
    WHERE m.conversation_id = ANY(conversation_ids)
        AND m.sender_id != user_id
        AND m.read_at IS NULL
    GROUP BY m.conversation_id;
END;
$$;

-- Step 2: Create indexes ONE AT A TIME (run each statement separately)
-- ===================================================================

-- Run this first:
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_conversation_created_at ON messages (conversation_id, created_at DESC);

-- Then run this:
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_conversation_sender_read ON messages (conversation_id, sender_id, read_at);

-- Then run this:
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_sender_read_at ON messages (sender_id, read_at) WHERE read_at IS NULL;

-- Then run this:
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_participants ON conversations (client_id, provider_id);

-- Finally run this:
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_updated_at ON conversations (updated_at DESC);

-- Step 3: Add comments
-- ===================
COMMENT ON FUNCTION get_latest_messages_for_conversations(text[]) IS 
'Optimized function to get latest message for multiple conversations in a single query, replacing N+1 query pattern';

COMMENT ON FUNCTION get_unread_counts_for_conversations(text[], text) IS 
'Optimized function to get unread message counts for multiple conversations in a single query, replacing N+1 query pattern';

-- Instructions for Step 2:
-- 1. Copy each CREATE INDEX CONCURRENTLY statement above
-- 2. Remove the comment markers (--)
-- 3. Run each statement individually in the SQL editor
-- 4. Wait for each to complete before running the next one
-- 5. CONCURRENTLY allows the index to be built without blocking other operations 