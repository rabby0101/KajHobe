-- Add notification badge functionality
-- This script adds functions and triggers to keep notification counts updated

-- Function to count pending notifications for a user
CREATE OR REPLACE FUNCTION get_pending_notification_count(user_uuid uuid)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    notification_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO notification_count
    FROM notifications
    WHERE to_user_id = user_uuid
    AND status = 'pending'
    AND type IN ('interest_request', 'offer_received');
    
    RETURN COALESCE(notification_count, 0);
END;
$$;

-- Function to create real-time notification for new interest requests
CREATE OR REPLACE FUNCTION notify_new_interest_request()
RETURNS TRIGGER AS $$
BEGIN
    -- Only for new interest requests
    IF NEW.type = 'interest_request' AND NEW.status = 'pending' THEN
        -- This will be picked up by real-time subscriptions
        PERFORM pg_notify('notification_channel', json_build_object(
            'type', 'new_interest',
            'to_user_id', NEW.to_user_id,
            'job_id', NEW.job_id,
            'message', NEW.message
        )::text);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new notifications
DROP TRIGGER IF EXISTS on_new_notification ON notifications;
CREATE TRIGGER on_new_notification
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_interest_request();

-- Create a view for easy notification querying
CREATE OR REPLACE VIEW pending_notifications_summary AS
SELECT 
    to_user_id,
    COUNT(*) as pending_count,
    COUNT(CASE WHEN type = 'interest_request' THEN 1 END) as interest_requests,
    COUNT(CASE WHEN type = 'offer_received' THEN 1 END) as offer_requests
FROM notifications
WHERE status = 'pending'
GROUP BY to_user_id; 