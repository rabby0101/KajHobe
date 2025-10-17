-- Prevent users from showing interest in their own jobs
-- This adds database-level constraints to ensure job creators cannot show interest in their own jobs

-- Create a function to check if the provider is not the job owner
CREATE OR REPLACE FUNCTION check_not_own_job()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the provider_id is the same as the job's client_id
    IF EXISTS (
        SELECT 1 FROM jobs 
        WHERE id = NEW.job_id::uuid 
        AND client_id = NEW.provider_id::uuid
    ) THEN
        RAISE EXCEPTION 'You cannot show interest in your own job posting';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add the trigger to job_interests table
DROP TRIGGER IF EXISTS prevent_self_interest ON job_interests;
CREATE TRIGGER prevent_self_interest
    BEFORE INSERT ON job_interests
    FOR EACH ROW
    EXECUTE FUNCTION check_not_own_job();

-- Also create a similar check for notifications to prevent self-notifications
CREATE OR REPLACE FUNCTION check_not_self_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Prevent users from creating interest notifications for their own jobs
    IF NEW.type = 'interest_request' AND EXISTS (
        SELECT 1 FROM jobs 
        WHERE id = NEW.job_id::uuid 
        AND client_id = NEW.from_user_id::uuid
    ) THEN
        RAISE EXCEPTION 'You cannot create interest notifications for your own job posting';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add the trigger to notifications table
DROP TRIGGER IF EXISTS prevent_self_notification ON notifications;
CREATE TRIGGER prevent_self_notification
    BEFORE INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION check_not_self_notification();

-- Test the constraints (optional - you can run these to verify they work)
/*
-- This should work (different users)
INSERT INTO job_interests (job_id, provider_id) 
VALUES ('some-job-uuid', 'different-user-uuid');

-- This should fail (same user as job owner)
INSERT INTO job_interests (job_id, provider_id) 
VALUES ('some-job-uuid', 'job-owner-uuid');
*/ 