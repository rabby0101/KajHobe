-- Enable Row Level Security on proposals table (if not already enabled)
ALTER TABLE public.proposals ENABLE ROW LEVEL SECURITY;

-- Allow providers to create proposals for jobs
CREATE POLICY "Providers can create proposals" 
ON public.proposals 
FOR INSERT 
WITH CHECK (auth.uid() = provider_id);

-- Allow users to view proposals they created or proposals for their jobs
CREATE POLICY "Users can view relevant proposals" 
ON public.proposals 
FOR SELECT 
USING (
  auth.uid() = provider_id OR 
  auth.uid() IN (
    SELECT client_id FROM public.jobs WHERE id = job_id
  )
);

-- Allow providers to update their own proposals (for counter offers)
CREATE POLICY "Providers can update their proposals" 
ON public.proposals 
FOR UPDATE 
USING (auth.uid() = provider_id);

-- Allow job owners to update proposal status (accept/reject)
CREATE POLICY "Job owners can update proposal status" 
ON public.proposals 
FOR UPDATE 
USING (
  auth.uid() IN (
    SELECT client_id FROM public.jobs WHERE id = job_id
  )
);