-- Fix RLS issue for show interest functionality
-- This function bypasses RLS for notification creation during show interest workflow

CREATE OR REPLACE FUNCTION public.show_interest_in_job(
  p_job_id uuid,
  p_message text DEFAULT 'I''m interested in this job!'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_client_id uuid;
  v_job_title text;
  v_notification_id uuid;
  v_interest_id uuid;
  result json;
BEGIN
  -- Get the current authenticated user
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;
  
  -- Check if job exists and get client_id and title
  SELECT client_id, title INTO v_client_id, v_job_title
  FROM public.jobs
  WHERE id = p_job_id;
  
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Job not found';
  END IF;
  
  -- Check if user already showed interest
  IF EXISTS (
    SELECT 1 FROM public.job_interests 
    WHERE job_id = p_job_id AND provider_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'You have already shown interest in this job';
  END IF;
  
  -- Insert into job_interests table
  INSERT INTO public.job_interests (job_id, provider_id, status, message)
  VALUES (p_job_id, v_user_id, 'pending', p_message)
  RETURNING id INTO v_interest_id;
  
  -- Create notification (bypassing RLS with SECURITY DEFINER)
  INSERT INTO public.notifications (
    type,
    job_id,
    from_user_id,
    to_user_id,
    status,
    message
  )
  VALUES (
    'show_interest',
    p_job_id,
    v_user_id,
    v_client_id,
    'pending',
    'Someone showed interest in your job: ' || v_job_title
  )
  RETURNING id INTO v_notification_id;
  
  -- Return success result
  result := json_build_object(
    'success', true,
    'interest_id', v_interest_id,
    'notification_id', v_notification_id,
    'message', 'Interest shown successfully'
  );
  
  RETURN result;
  
EXCEPTION WHEN others THEN
  -- Return error result
  result := json_build_object(
    'success', false,
    'error', SQLERRM
  );
  RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.show_interest_in_job(uuid, text) TO authenticated;

-- Create a simpler version without optional message parameter
CREATE OR REPLACE FUNCTION public.show_interest_in_job(p_job_id uuid)
RETURNS json
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT public.show_interest_in_job(p_job_id, 'I''m interested in this job!');
$$;

GRANT EXECUTE ON FUNCTION public.show_interest_in_job(uuid) TO authenticated;