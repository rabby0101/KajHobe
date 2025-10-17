-- Fix GROUP BY issue in dashboard function
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
BEGIN
    RETURN QUERY
    SELECT 
        -- User type - default to 'client' if is_service_provider column doesn't exist
        CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'is_service_provider')
            AND (SELECT is_service_provider FROM public.profiles WHERE id = user_id) = true 
            THEN 'provider'
            ELSE 'client'
        END as user_type,
        
        -- Active deals count - use status if completion_status doesn't exist
        (SELECT COUNT(*) FROM public.deals 
         WHERE (client_id = user_id OR provider_id = user_id) 
         AND (
             CASE 
                 WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'completion_status')
                 THEN completion_status = 'in_progress'
                 ELSE status NOT IN ('completed', 'cancelled')
             END
         ))::bigint as active_deals_count,
        
        -- Completed deals count
        (SELECT COUNT(*) FROM public.deals 
         WHERE (client_id = user_id OR provider_id = user_id) 
         AND (
             CASE 
                 WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'completion_status')
                 THEN completion_status = 'completed'
                 ELSE status = 'completed'
             END
         ))::bigint as completed_deals_count,
        
        -- Pending completion requests - default to 0 if table doesn't exist
        CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'completion_requests')
            THEN (SELECT COUNT(*) FROM public.completion_requests cr
                  JOIN public.deals d ON cr.deal_id = d.id
                  WHERE cr.status = 'pending' 
                  AND ((d.client_id = user_id AND cr.requester_type = 'provider') 
                       OR (d.provider_id = user_id AND cr.requester_type = 'client')))::bigint
            ELSE 0::bigint
        END as pending_completion_requests,
        
        -- Total earnings (for providers) - only count completed deals
        COALESCE((SELECT SUM(agreed_amount) FROM public.deals 
                  WHERE provider_id = user_id 
                  AND (
                      CASE 
                          WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'completion_status')
                          THEN completion_status = 'completed'
                          ELSE status = 'completed'
                      END
                  )), 0) as total_earnings,
        
        -- Total spent (for clients) - only count completed deals
        COALESCE((SELECT SUM(agreed_amount) FROM public.deals 
                  WHERE client_id = user_id 
                  AND (
                      CASE 
                          WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'completion_status')
                          THEN completion_status = 'completed'
                          ELSE status = 'completed'
                      END
                  )), 0) as total_spent,
        
        -- Average rating - default to 4.5 if column doesn't exist
        CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'average_rating')
            THEN COALESCE((SELECT average_rating FROM public.profiles WHERE id = user_id), 4.5)
            ELSE 4.5
        END as average_rating,
        
        -- Recent deals (last 5) - fixed GROUP BY issue
        (SELECT COALESCE(
            (SELECT json_agg(deal_json)
             FROM (
                SELECT json_build_object(
                    'id', d.id,
                    'job_title', COALESCE(j.title, 'Unknown Job'),
                    'agreed_amount', d.agreed_amount,
                    'completion_status', COALESCE(
                        CASE 
                            WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'completion_status')
                            THEN d.completion_status
                            ELSE d.status
                        END, 'in_progress'
                    ),
                    'created_at', d.created_at,
                    'other_party_name', 
                    CASE 
                        WHEN d.client_id = user_id THEN COALESCE(cp.full_name, 'Unknown Provider')
                        ELSE COALESCE(pp.full_name, 'Unknown Client')
                    END
                ) as deal_json
                FROM public.deals d
                LEFT JOIN public.jobs j ON d.job_id = j.id
                LEFT JOIN public.profiles cp ON d.provider_id = cp.id
                LEFT JOIN public.profiles pp ON d.client_id = pp.id
                WHERE d.client_id = user_id OR d.provider_id = user_id
                ORDER BY d.created_at DESC
                LIMIT 5
             ) subquery
            ), 
            '[]'::json
        )) as recent_deals;
END;
$$ LANGUAGE plpgsql;

-- Force schema cache reload
SELECT pg_notify('pgrst', 'reload schema');

-- Test the function
SELECT 'Dashboard function updated successfully!' as result;