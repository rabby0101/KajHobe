-- Database trigger to automatically create notifications when completion requests are created
-- This ensures notifications are always sent when someone requests task completion

-- Function to create notification when completion request is created
CREATE OR REPLACE FUNCTION create_completion_request_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_recipient_id uuid;
    v_sender_name text;
    v_job_title text;
    v_notification_message text;
BEGIN
    -- Get the recipient ID (the other party in the deal)
    SELECT 
        CASE 
            WHEN NEW.requester_type = 'client' THEN d.provider_id
            ELSE d.client_id
        END,
        j.title
    INTO v_recipient_id, v_job_title
    FROM deals d
    JOIN jobs j ON d.job_id = j.id
    WHERE d.id = NEW.deal_id;
    
    -- Get the sender's name
    SELECT full_name INTO v_sender_name
    FROM profiles 
    WHERE id = NEW.requester_id;
    
    -- Create the notification message
    v_notification_message := COALESCE(v_sender_name, 'Someone') || ' has requested to mark "' || COALESCE(v_job_title, 'the task') || '" as completed';
    
    -- Create the notification
    INSERT INTO notifications (
        type,
        job_id,
        from_user_id,
        to_user_id,
        message,
        completion_request_id,
        status,
        created_at
    )
    VALUES (
        'completion_request',
        (SELECT job_id FROM deals WHERE id = NEW.deal_id),
        NEW.requester_id,
        v_recipient_id,
        v_notification_message,
        NEW.id,
        'pending',
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create notification when completion request is responded to
CREATE OR REPLACE FUNCTION create_completion_response_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_recipient_id uuid;
    v_responder_name text;
    v_job_title text;
    v_notification_message text;
BEGIN
    -- Only create notification when status changes from pending to approved/rejected
    IF OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected') THEN
        -- Get the recipient ID (the original requester)
        v_recipient_id := NEW.requester_id;
        
        -- Get the responder's name
        SELECT full_name INTO v_responder_name
        FROM profiles 
        WHERE id = NEW.responded_by;
        
        -- Get job title
        SELECT j.title INTO v_job_title
        FROM deals d
        JOIN jobs j ON d.job_id = j.id
        WHERE d.id = NEW.deal_id;
        
        -- Create the notification message
        IF NEW.status = 'approved' THEN
            v_notification_message := COALESCE(v_responder_name, 'Someone') || ' has approved the completion of "' || COALESCE(v_job_title, 'the task') || '"';
        ELSE
            v_notification_message := COALESCE(v_responder_name, 'Someone') || ' has rejected the completion request for "' || COALESCE(v_job_title, 'the task') || '"';
        END IF;
        
        -- Create the notification
        INSERT INTO notifications (
            type,
            job_id,
            from_user_id,
            to_user_id,
            message,
            completion_request_id,
            status,
            created_at
        )
        VALUES (
            CASE WHEN NEW.status = 'approved' THEN 'completion_approved' ELSE 'completion_rejected' END,
            (SELECT job_id FROM deals WHERE id = NEW.deal_id),
            NEW.responded_by,
            v_recipient_id,
            v_notification_message,
            NEW.id,
            'pending',
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_completion_request_notification ON completion_requests;
DROP TRIGGER IF EXISTS trigger_completion_response_notification ON completion_requests;

-- Create trigger for completion request creation
CREATE TRIGGER trigger_completion_request_notification
    AFTER INSERT ON completion_requests
    FOR EACH ROW
    EXECUTE FUNCTION create_completion_request_notification();

-- Create trigger for completion request response
CREATE TRIGGER trigger_completion_response_notification
    AFTER UPDATE ON completion_requests
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION create_completion_response_notification();

-- Update notifications table to support new notification types
-- Add new types to the existing enum constraint if it exists
DO $$
BEGIN
    -- Check if the constraint exists and update it
    IF EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name LIKE '%notification%type%' 
        AND table_name = 'notifications'
    ) THEN
        -- Drop the old constraint
        ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
    END IF;
    
    -- Add new constraint with all notification types
    ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
    CHECK (type IN (
        'interest_request', 
        'offer_received', 
        'deal_rejected', 
        'completion_request', 
        'completion_approved', 
        'completion_rejected',
        'message_received'
    ));
END $$;

-- Force schema reload
SELECT pg_notify('pgrst', 'reload schema');

-- Verify the changes
SELECT 
    'Completion request notification triggers created successfully!' as message,
    COUNT(*) as trigger_count
FROM information_schema.triggers 
WHERE trigger_name LIKE '%completion%notification%';