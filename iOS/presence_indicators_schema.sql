-- Presence Indicators Database Schema
-- Add presence fields to profiles table

-- Add presence columns to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS average_response_time_minutes INTEGER DEFAULT NULL;

-- Create index for performance on presence queries
CREATE INDEX IF NOT EXISTS idx_profiles_is_online ON public.profiles(is_online);
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen_at ON public.profiles(last_seen_at);

-- Create function to update last_seen_at automatically
CREATE OR REPLACE FUNCTION update_last_seen()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_seen_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update last_seen_at when user becomes offline
CREATE OR REPLACE TRIGGER trigger_update_last_seen
    BEFORE UPDATE OF is_online ON public.profiles
    FOR EACH ROW
    WHEN (OLD.is_online = TRUE AND NEW.is_online = FALSE)
    EXECUTE FUNCTION update_last_seen();

-- Create function to calculate average response time
CREATE OR REPLACE FUNCTION calculate_average_response_time(user_id_param UUID)
RETURNS INTEGER AS $$
DECLARE
    avg_minutes INTEGER;
BEGIN
    WITH user_conversations AS (
        SELECT DISTINCT conversation_id
        FROM messages
        WHERE sender_id = user_id_param
        AND created_at >= NOW() - INTERVAL '30 days'  -- Only recent conversations
    ),
    message_pairs AS (
        SELECT 
            m1.id as msg1_id,
            m1.sender_id as sender1,
            m1.created_at as time1,
            m2.id as msg2_id,
            m2.sender_id as sender2,
            m2.created_at as time2,
            EXTRACT(EPOCH FROM (m2.created_at - m1.created_at))/60 as response_minutes
        FROM messages m1
        JOIN messages m2 ON m1.conversation_id = m2.conversation_id
        WHERE m1.conversation_id IN (SELECT conversation_id FROM user_conversations)
        AND m2.created_at > m1.created_at
        AND m1.sender_id != m2.sender_id
        AND m2.sender_id = user_id_param
        AND m2.created_at >= NOW() - INTERVAL '30 days'
        ORDER BY m1.conversation_id, m1.created_at
    ),
    response_times AS (
        SELECT DISTINCT ON (msg1_id) response_minutes
        FROM message_pairs
        WHERE response_minutes > 0 AND response_minutes < 1440  -- Between 0 and 24 hours
        ORDER BY msg1_id, time2
    )
    SELECT ROUND(AVG(response_minutes))::INTEGER
    INTO avg_minutes
    FROM response_times;
    
    RETURN avg_minutes;
END;
$$ LANGUAGE plpgsql;

-- Create function to update user response time
CREATE OR REPLACE FUNCTION update_user_response_time(user_id_param UUID)
RETURNS VOID AS $$
DECLARE
    calculated_time INTEGER;
BEGIN
    SELECT calculate_average_response_time(user_id_param) INTO calculated_time;
    
    UPDATE public.profiles
    SET average_response_time_minutes = calculated_time
    WHERE id = user_id_param;
END;
$$ LANGUAGE plpgsql;

-- Create stored procedure to clean up old presence data
CREATE OR REPLACE FUNCTION cleanup_stale_presence()
RETURNS VOID AS $$
BEGIN
    -- Mark users as offline if they haven't been seen for more than 10 minutes
    UPDATE public.profiles
    SET is_online = FALSE,
        last_seen_at = CASE 
            WHEN last_seen_at IS NULL THEN NOW() - INTERVAL '10 minutes'
            ELSE last_seen_at 
        END
    WHERE is_online = TRUE 
    AND (last_seen_at IS NULL OR last_seen_at < NOW() - INTERVAL '10 minutes');
    
    RAISE NOTICE 'Cleaned up stale presence data';
END;
$$ LANGUAGE plpgsql;

-- Add RLS (Row Level Security) policies if needed
-- Enable RLS on profiles if not already enabled
-- ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create policy for users to update their own presence
-- CREATE POLICY "Users can update own presence" ON public.profiles
--     FOR UPDATE USING (auth.uid() = id);

-- Create policy for users to view others' presence 
-- CREATE POLICY "Users can view others' presence" ON public.profiles
--     FOR SELECT USING (true);

-- Add comments to document the new columns
COMMENT ON COLUMN public.profiles.is_online IS 'Indicates if the user is currently online and active';
COMMENT ON COLUMN public.profiles.last_seen_at IS 'Timestamp of when the user was last seen online';
COMMENT ON COLUMN public.profiles.average_response_time_minutes IS 'Average response time in minutes calculated from recent conversations';

-- Example usage to test the functions:
-- SELECT calculate_average_response_time('your-user-id-here'::UUID);
-- SELECT update_user_response_time('your-user-id-here'::UUID);
-- SELECT cleanup_stale_presence();