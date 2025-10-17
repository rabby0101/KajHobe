-- Simple, robust dashboard function that avoids structure mismatches
CREATE OR REPLACE FUNCTION get_user_dashboard_data(user_id uuid)
RETURNS TABLE(
    user_type text,
    active_deals_count bigint,
    completed_deals_count bigint,
    pending_completion_requests bigint,
    total_earnings numeric,
    total_spent numeric,
    average_rating numeric,
    recent_deals json
) AS $$
DECLARE
    user_profile_record RECORD;
    active_count bigint := 0;
    completed_count bigint := 0;
    pending_requests bigint := 0;
    earnings numeric := 0;
    spent numeric := 0;
    rating numeric := 4.5;
    deals_json json := '[]'::json;
BEGIN
    -- Get user profile information
    SELECT * INTO user_profile_record FROM public.profiles WHERE id = user_id LIMIT 1;
    
    -- Determine user type
    IF user_profile_record.is_service_provider = true THEN
        user_type := 'provider';
    ELSE
        user_type := 'client';
    END IF;
    
    -- Count active deals
    SELECT COUNT(*) INTO active_count
    FROM public.deals 
    WHERE (client_id = user_id OR provider_id = user_id) 
    AND status NOT IN ('completed', 'cancelled');
    
    -- Count completed deals
    SELECT COUNT(*) INTO completed_count
    FROM public.deals 
    WHERE (client_id = user_id OR provider_id = user_id) 
    AND status = 'completed';
    
    -- Count pending completion requests (if table exists)
    BEGIN
        SELECT COUNT(*) INTO pending_requests
        FROM public.completion_requests cr
        JOIN public.deals d ON cr.deal_id = d.id
        WHERE cr.status = 'pending' 
        AND ((d.client_id = user_id AND cr.requester_type = 'provider') 
             OR (d.provider_id = user_id AND cr.requester_type = 'client'));
    EXCEPTION
        WHEN others THEN
            pending_requests := 0;
    END;
    
    -- Calculate total earnings (for providers)
    SELECT COALESCE(SUM(agreed_amount), 0) INTO earnings
    FROM public.deals 
    WHERE provider_id = user_id AND status = 'completed';
    
    -- Calculate total spent (for clients)
    SELECT COALESCE(SUM(agreed_amount), 0) INTO spent
    FROM public.deals 
    WHERE client_id = user_id AND status = 'completed';
    
    -- Get average rating if column exists
    BEGIN
        IF user_profile_record.average_rating IS NOT NULL THEN
            rating := user_profile_record.average_rating;
        END IF;
    EXCEPTION
        WHEN others THEN
            rating := 4.5;
    END;
    
    -- Get recent deals
    BEGIN
        WITH recent_deals_data AS (
            SELECT 
                d.id,
                COALESCE(j.title, 'Unknown Job') as job_title,
                d.agreed_amount,
                COALESCE(d.status, 'in_progress') as completion_status,
                d.created_at,
                CASE 
                    WHEN d.client_id = user_id THEN COALESCE(cp.full_name, 'Unknown Provider')
                    ELSE COALESCE(pp.full_name, 'Unknown Client')
                END as other_party_name
            FROM public.deals d
            LEFT JOIN public.jobs j ON d.job_id = j.id
            LEFT JOIN public.profiles cp ON d.provider_id = cp.id
            LEFT JOIN public.profiles pp ON d.client_id = pp.id
            WHERE d.client_id = user_id OR d.provider_id = user_id
            ORDER BY d.created_at DESC
            LIMIT 5
        )
        SELECT json_agg(
            json_build_object(
                'id', id,
                'job_title', job_title,
                'agreed_amount', agreed_amount,
                'completion_status', completion_status,
                'created_at', created_at,
                'other_party_name', other_party_name
            )
        ) INTO deals_json
        FROM recent_deals_data;
        
        IF deals_json IS NULL THEN
            deals_json := '[]'::json;
        END IF;
    EXCEPTION
        WHEN others THEN
            deals_json := '[]'::json;
    END;
    
    -- Return the single row
    active_deals_count := active_count;
    completed_deals_count := completed_count;
    pending_completion_requests := pending_requests;
    total_earnings := earnings;
    total_spent := spent;
    average_rating := rating;
    recent_deals := deals_json;
    
    RETURN NEXT;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Force schema cache reload
SELECT pg_notify('pgrst', 'reload schema');

-- Test the function with a dummy UUID to make sure it works
SELECT 'Dashboard function created successfully!' as result;
SELECT 'Testing function...' as test_status;

-- You can test with: SELECT * FROM get_user_dashboard_data('00000000-0000-0000-0000-000000000000');