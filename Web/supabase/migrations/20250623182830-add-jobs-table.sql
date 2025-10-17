-- Create jobs table (referenced by bids and chat_messages)
CREATE TABLE IF NOT EXISTS public.jobs (
  id bigserial NOT NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  title text NOT NULL,
  description text NOT NULL,
  category text NOT NULL,
  budget numeric NOT NULL,
  location text NOT NULL,
  urgent boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'open'::text,
  client_id uuid NOT NULL,
  CONSTRAINT jobs_pkey PRIMARY KEY (id)
);

-- Create index for jobs
CREATE INDEX IF NOT EXISTS idx_jobs_client_id ON public.jobs USING btree (client_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON public.jobs USING btree (status);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON public.jobs USING btree (created_at DESC);

-- Add RLS policies for jobs
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view jobs" ON public.jobs
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own jobs" ON public.jobs
  FOR INSERT WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can update their own jobs" ON public.jobs
  FOR UPDATE USING (auth.uid() = client_id); 