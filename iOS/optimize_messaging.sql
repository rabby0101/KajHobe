-- Optimize Messaging Performance
-- This script creates optimized functions and views for faster message loading

-- 1. Create optimized view for conversations with all needed data
CREATE OR REPLACE VIEW conversation_details AS
SELECT 
    c.*,
    -- Job details
    j.title as job_title,
    j.description as job_description,
    j.budget as job_budget,
    -- Client profile
    cp.full_name as client_name,
    cp.avatar_url as client_avatar,
    -- Provider profile  
    pp.full_name as provider_name,
    pp.avatar_url as provider_avatar,
    -- Latest message
    lm.content as latest_message_content,
    lm.created_at as latest_message_time,
    lm.sender_id as latest_message_sender,
    -- Unread count for current user (will be calculated per user)
    0 as unread_count_placeholder
FROM conversations c
LEFT JOIN jobs j ON c.job_id = j.id
LEFT JOIN profiles cp ON c.client_id = cp.id  
LEFT JOIN profiles pp ON c.provider_id = pp.id
LEFT JOIN LATERAL (
    SELECT content, created_at, sender_id
    FROM messages m
    WHERE m.conversation_id = c.id
    ORDER BY m.created_at DESC
    LIMIT 1
) lm ON true;

-- 2. Create optimized function to get user conversations with all data in one query
CREATE OR REPLACE FUNCTION get_user_conversations_optimized(user_id uuid)
RETURNS TABLE(
    id uuid,
    job_id uuid,
    client_id uuid,
    provider_id uuid,
    status text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    job_title text,
    job_description text,
    job_budget integer,
    client_name text,
    client_avatar text,
    provider_name text,
    provider_avatar text,
    latest_message_content text,
    latest_message_time timestamp with time zone,
    latest_message_sender uuid,
    unread_count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cd.id,
        cd.job_id,
        cd.client_id,
        cd.provider_id,
        cd.status,
        cd.created_at,
        cd.updated_at,
        cd.job_title,
        cd.job_description,
        cd.job_budget,
        cd.client_name,
        cd.client_avatar,
        cd.provider_name,
        cd.provider_avatar,
        cd.latest_message_content,
        cd.latest_message_time,
        cd.latest_message_sender,
        -- Calculate unread count for this specific user
        COALESCE((
            SELECT COUNT(*)::bigint
            FROM messages m
            WHERE m.conversation_id = cd.id
            AND m.sender_id != user_id
            AND m.read_at IS NULL
        ), 0) as unread_count
    FROM conversation_details cd
    WHERE cd.client_id = user_id OR cd.provider_id = user_id
    ORDER BY GREATEST(cd.updated_at, cd.latest_message_time) DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create simple unread count function for tab badge
CREATE OR REPLACE FUNCTION get_total_unread_count(user_id uuid)
RETURNS bigint AS $$
BEGIN
    RETURN COALESCE((
        SELECT COUNT(*)
        FROM messages m
        JOIN conversations c ON m.conversation_id = c.id
        WHERE (c.client_id = user_id OR c.provider_id = user_id)
        AND m.sender_id != user_id
        AND m.read_at IS NULL
    ), 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_messages_conversation_unread 
ON messages(conversation_id, sender_id, read_at) 
WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_messages_conversation_latest 
ON messages(conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversations_user_updated 
ON conversations(client_id, provider_id, updated_at DESC);

-- 5. Grant permissions
GRANT SELECT ON conversation_details TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_conversations_optimized(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_total_unread_count(uuid) TO authenticated;

-- 6. Force schema cache reload
SELECT pg_notify('pgrst', 'reload schema');

-- 7. Test the functions
SELECT 'Messaging optimization complete!' as result;