-- Create job_interests table
CREATE TABLE public.job_interests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT job_interests_pkey PRIMARY KEY (id),
  CONSTRAINT job_interests_unique UNIQUE (job_id, provider_id)
);

-- Add foreign key constraints
ALTER TABLE public.job_interests 
ADD CONSTRAINT job_interests_job_id_fkey 
FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;

ALTER TABLE public.job_interests 
ADD CONSTRAINT job_interests_provider_id_fkey 
FOREIGN KEY (provider_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Create indexes
CREATE INDEX idx_job_interests_job_id ON public.job_interests(job_id);
CREATE INDEX idx_job_interests_provider_id ON public.job_interests(provider_id);

-- Enable RLS
ALTER TABLE public.job_interests ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view all interests" ON public.job_interests
  FOR SELECT USING (true);

CREATE POLICY "Users can create their own interests" ON public.job_interests
  FOR INSERT WITH CHECK (auth.uid() = provider_id); 