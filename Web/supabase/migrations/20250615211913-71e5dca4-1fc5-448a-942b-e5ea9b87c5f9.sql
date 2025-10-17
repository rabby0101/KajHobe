
-- Drop existing policies if they exist and recreate them with correct permissions
DROP POLICY IF EXISTS "Users can view relevant proposals" ON public.proposals;
DROP POLICY IF EXISTS "Providers can create proposals" ON public.proposals;
DROP POLICY IF EXISTS "Clients can update proposals for their jobs" ON public.proposals;
DROP POLICY IF EXISTS "Providers can update their own proposals" ON public.proposals;

-- Recreate policies with proper permissions
CREATE POLICY "Users can view relevant proposals" 
  ON public.proposals 
  FOR SELECT 
  USING (
    auth.uid() = provider_id OR 
    auth.uid() IN (
      SELECT client_id FROM public.jobs WHERE id = job_id
    )
  );

CREATE POLICY "Providers can create proposals" 
  ON public.proposals 
  FOR INSERT 
  WITH CHECK (auth.uid() = provider_id);

CREATE POLICY "Clients can update proposals for their jobs" 
  ON public.proposals 
  FOR UPDATE 
  USING (
    auth.uid() IN (
      SELECT client_id FROM public.jobs WHERE id = job_id
    )
  );

CREATE POLICY "Providers can update their own proposals" 
  ON public.proposals 
  FOR UPDATE 
  USING (auth.uid() = provider_id);
