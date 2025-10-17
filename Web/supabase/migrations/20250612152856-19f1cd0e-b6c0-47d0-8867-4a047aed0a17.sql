
-- Drop the check constraint that might be preventing the alter
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;

-- Create proposals table to store job proposals
CREATE TABLE public.proposals (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE NOT NULL,
  provider_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  amount INTEGER NOT NULL,
  message TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(job_id, provider_id)
);

-- Add Row Level Security (RLS) to proposals table
ALTER TABLE public.proposals ENABLE ROW LEVEL SECURITY;

-- Create policy that allows job owners to view proposals for their jobs
CREATE POLICY "Job owners can view proposals for their jobs" 
  ON public.proposals 
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM public.jobs 
      WHERE jobs.id = proposals.job_id 
      AND jobs.client_id = auth.uid()
    )
  );

-- Create policy that allows providers to view their own proposals
CREATE POLICY "Providers can view their own proposals" 
  ON public.proposals 
  FOR SELECT 
  USING (provider_id = auth.uid());

-- Create policy that allows service providers to create proposals
CREATE POLICY "Service providers can create proposals" 
  ON public.proposals 
  FOR INSERT 
  WITH CHECK (
    provider_id = auth.uid() 
    AND EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.user_type IN ('provider', 'both')
    )
  );

-- Create policy that allows providers to update their own proposals
CREATE POLICY "Providers can update their own proposals" 
  ON public.proposals 
  FOR UPDATE 
  USING (provider_id = auth.uid());

-- Update the user_type column to support new values
UPDATE public.profiles 
SET user_type = 'seeker' 
WHERE user_type IS NULL OR user_type NOT IN ('seeker', 'provider', 'both');

-- Add check constraint for valid user types
ALTER TABLE public.profiles 
ADD CONSTRAINT valid_user_type 
CHECK (user_type IN ('seeker', 'provider', 'both'));
