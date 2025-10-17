-- Optimize messaging performance by replacing N+1 queries with efficient batch operations

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

-- Add indexes to improve performance of message queries
-- Note: Using regular CREATE INDEX (not CONCURRENTLY) to avoid transaction block issues
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_at 
ON messages (conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_sender_read 
ON messages (conversation_id, sender_id, read_at);

CREATE INDEX IF NOT EXISTS idx_messages_sender_read_at 
ON messages (sender_id, read_at) WHERE read_at IS NULL;

-- Add index for conversations table
CREATE INDEX IF NOT EXISTS idx_conversations_participants 
ON conversations (client_id, provider_id);

CREATE INDEX IF NOT EXISTS idx_conversations_updated_at 
ON conversations (updated_at DESC);

-- Comment explaining the optimization
COMMENT ON FUNCTION get_latest_messages_for_conversations(text[]) IS 
'Optimized function to get latest message for multiple conversations in a single query, replacing N+1 query pattern';

COMMENT ON FUNCTION get_unread_counts_for_conversations(text[], text) IS 
'Optimized function to get unread message counts for multiple conversations in a single query, replacing N+1 query pattern'; 