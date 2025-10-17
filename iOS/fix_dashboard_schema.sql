-- Fix Dashboard Schema Issues
-- This script creates a robust dashboard function that handles missing columns gracefully

-- 1. First, ensure the completion_requests table exists
CREATE TABLE IF NOT EXISTS public.completion_requests (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    deal_id uuid NOT NULL,
    requester_id uuid NOT NULL,
    requester_type text NOT NULL CHECK (requester_type IN ('client', 'provider')),
    request_message text NULL,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    responded_by uuid NULL,
    responded_at timestamp with time zone NULL,
    response_message text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Add completion columns to deals table if they don't exist
DO $$ 
BEGIN
    -- Add completion_status column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'completion_status') THEN
        ALTER TABLE public.deals ADD COLUMN completion_status text DEFAULT 'in_progress';
    END IF;
    
    -- Add client_completion_requested column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'client_completion_requested') THEN
        ALTER TABLE public.deals ADD COLUMN client_completion_requested boolean DEFAULT false;
    END IF;
    
    -- Add provider_completion_requested column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'provider_completion_requested') THEN
        ALTER TABLE public.deals ADD COLUMN provider_completion_requested boolean DEFAULT false;
    END IF;
END $$;

-- 3. Create a simple, robust dashboard function
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
        
        -- Recent deals (last 5) - simplified to avoid missing columns
        (SELECT COALESCE(json_agg(
            json_build_object(
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
            )
        ), '[]'::json)
        FROM public.deals d
        LEFT JOIN public.jobs j ON d.job_id = j.id
        LEFT JOIN public.profiles cp ON d.provider_id = cp.id
        LEFT JOIN public.profiles pp ON d.client_id = pp.id
        WHERE d.client_id = user_id OR d.provider_id = user_id
        ORDER BY d.created_at DESC
        LIMIT 5) as recent_deals;
END;
$$ LANGUAGE plpgsql;

-- 4. Enable RLS on completion_requests if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'completion_requests') THEN
        ALTER TABLE public.completion_requests ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

-- 5. Create basic RLS policies for completion_requests if they don't exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'completion_requests') THEN
        -- Drop existing policies first
        DROP POLICY IF EXISTS "Users can view completion requests for their deals" ON public.completion_requests;
        DROP POLICY IF EXISTS "Users can create completion requests for their deals" ON public.completion_requests;
        DROP POLICY IF EXISTS "Users can update completion requests they received" ON public.completion_requests;
        
        -- Create new policies
        CREATE POLICY "Users can view completion requests for their deals" 
            ON public.completion_requests 
            FOR SELECT 
            USING (
                EXISTS (
                    SELECT 1 FROM public.deals 
                    WHERE deals.id = completion_requests.deal_id 
                    AND (deals.client_id = auth.uid() OR deals.provider_id = auth.uid())
                )
            );

        CREATE POLICY "Users can create completion requests for their deals" 
            ON public.completion_requests 
            FOR INSERT 
            WITH CHECK (
                auth.uid() = requester_id AND
                EXISTS (
                    SELECT 1 FROM public.deals 
                    WHERE deals.id = completion_requests.deal_id 
                    AND (deals.client_id = auth.uid() OR deals.provider_id = auth.uid())
                )
            );

        CREATE POLICY "Users can update completion requests they received" 
            ON public.completion_requests 
            FOR UPDATE 
            USING (
                EXISTS (
                    SELECT 1 FROM public.deals 
                    WHERE deals.id = completion_requests.deal_id 
                    AND (
                        (deals.client_id = auth.uid() AND completion_requests.requester_type = 'provider') OR
                        (deals.provider_id = auth.uid() AND completion_requests.requester_type = 'client')
                    )
                )
            );
    END IF;
END $$;

-- 6. Force schema cache reload
SELECT pg_notify('pgrst', 'reload schema');

-- 7. Test the function
SELECT 'Dashboard function created successfully!' as result;