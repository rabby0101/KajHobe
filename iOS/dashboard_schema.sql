-- Database Schema for Job Completion & Dashboard System

-- 1. Add completion tracking columns to deals table
ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS client_completion_requested boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS provider_completion_requested boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS client_completion_requested_at timestamp with time zone NULL,
ADD COLUMN IF NOT EXISTS provider_completion_requested_at timestamp with time zone NULL,
ADD COLUMN IF NOT EXISTS completion_status text DEFAULT 'in_progress' CHECK (completion_status IN ('in_progress', 'pending_approval', 'completed', 'disputed'));

-- 2. Create completion_requests table for tracking completion requests
CREATE TABLE IF NOT EXISTS public.completion_requests (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    deal_id uuid NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
    requester_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    requester_type text NOT NULL CHECK (requester_type IN ('client', 'provider')),
    request_message text NULL,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    responded_by uuid NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
    responded_at timestamp with time zone NULL,
    response_message text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_completion_requests_deal_id ON public.completion_requests(deal_id);
CREATE INDEX IF NOT EXISTS idx_completion_requests_requester_id ON public.completion_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_completion_requests_status ON public.completion_requests(status);
CREATE INDEX IF NOT EXISTS idx_deals_completion_status ON public.deals(completion_status);

-- 4. Enable RLS on completion_requests table
ALTER TABLE public.completion_requests ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies for completion_requests
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

-- 6. Create function to update deal completion status
CREATE OR REPLACE FUNCTION update_deal_completion_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the deal completion status based on completion requests
    IF NEW.status = 'approved' THEN
        UPDATE public.deals 
        SET completion_status = 'completed',
            status = 'completed',
            completed_at = NOW()
        WHERE id = NEW.deal_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger for auto-updating deal status
DROP TRIGGER IF EXISTS trigger_update_deal_completion ON public.completion_requests;
CREATE TRIGGER trigger_update_deal_completion
    AFTER UPDATE ON public.completion_requests
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION update_deal_completion_status();

-- 8. Create function to get user dashboard data
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
        CASE 
            WHEN p.is_service_provider = true THEN 'provider'
            ELSE 'client'
        END as user_type,
        
        -- Active deals count
        (SELECT COUNT(*) FROM public.deals 
         WHERE (client_id = user_id OR provider_id = user_id) 
         AND completion_status = 'in_progress')::bigint as active_deals_count,
        
        -- Completed deals count
        (SELECT COUNT(*) FROM public.deals 
         WHERE (client_id = user_id OR provider_id = user_id) 
         AND completion_status = 'completed')::bigint as completed_deals_count,
        
        -- Pending completion requests
        (SELECT COUNT(*) FROM public.completion_requests cr
         JOIN public.deals d ON cr.deal_id = d.id
         WHERE cr.status = 'pending' 
         AND ((d.client_id = user_id AND cr.requester_type = 'provider') 
              OR (d.provider_id = user_id AND cr.requester_type = 'client')))::bigint as pending_completion_requests,
        
        -- Total earnings (for providers)
        COALESCE((SELECT SUM(agreed_amount) FROM public.deals 
                  WHERE provider_id = user_id AND completion_status = 'completed'), 0) as total_earnings,
        
        -- Total spent (for clients)
        COALESCE((SELECT SUM(agreed_amount) FROM public.deals 
                  WHERE client_id = user_id AND completion_status = 'completed'), 0) as total_spent,
        
        -- Average rating
        COALESCE(p.average_rating, 0) as average_rating,
        
        -- Recent deals (last 5)
        (SELECT json_agg(
            json_build_object(
                'id', d.id,
                'job_title', j.title,
                'agreed_amount', d.agreed_amount,
                'completion_status', d.completion_status,
                'created_at', d.created_at,
                'other_party_name', 
                CASE 
                    WHEN d.client_id = user_id THEN cp.full_name
                    ELSE pp.full_name
                END
            )
        )
        FROM public.deals d
        JOIN public.jobs j ON d.job_id = j.id
        LEFT JOIN public.profiles cp ON d.client_id = cp.id
        LEFT JOIN public.profiles pp ON d.provider_id = pp.id
        WHERE d.client_id = user_id OR d.provider_id = user_id
        ORDER BY d.created_at DESC
        LIMIT 5) as recent_deals
        
    FROM public.profiles p
    WHERE p.id = user_id;
END;
$$ LANGUAGE plpgsql;

-- 9. Update notifications table to support completion request notifications
ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS completion_request_id uuid NULL REFERENCES public.completion_requests(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_completion_request_id ON public.notifications(completion_request_id);

-- 10. Force schema cache reload
SELECT pg_notify('pgrst', 'reload schema');

-- 11. Verify the changes
SELECT 
    'Schema update completed!' as message,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'completion_requests') as completion_requests_columns,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'deals' AND column_name LIKE '%completion%') as deals_completion_columns;