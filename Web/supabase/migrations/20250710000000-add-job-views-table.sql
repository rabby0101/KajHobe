-- Create job_views table to track when users view specific jobs
CREATE TABLE IF NOT EXISTS public.job_views (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  user_id uuid NOT NULL,
  viewed_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT job_views_pkey PRIMARY KEY (id),
  CONSTRAINT job_views_unique UNIQUE (job_id, user_id),
  CONSTRAINT job_views_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  CONSTRAINT job_views_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create indexes for job_views
CREATE INDEX IF NOT EXISTS idx_job_views_job_id ON public.job_views(job_id);
CREATE INDEX IF NOT EXISTS idx_job_views_user_id ON public.job_views(user_id);
CREATE INDEX IF NOT EXISTS idx_job_views_viewed_at ON public.job_views(viewed_at);

-- Enable RLS
ALTER TABLE public.job_views ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for job_views
CREATE POLICY "Users can view their own job views" ON public.job_views
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own job views" ON public.job_views
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own job views" ON public.job_views
  FOR UPDATE USING (auth.uid() = user_id);

-- Create function to track job views (upsert to handle multiple views)
CREATE OR REPLACE FUNCTION public.track_job_view(
  p_job_id uuid,
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.job_views (job_id, user_id, viewed_at)
  VALUES (p_job_id, p_user_id, timezone('utc'::text, now()))
  ON CONFLICT (job_id, user_id) 
  DO UPDATE SET viewed_at = timezone('utc'::text, now());
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.track_job_view(uuid, uuid) TO authenticated;
