-- Step 1: Create notifications table
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type text NOT NULL,
  job_id uuid NOT NULL,
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  message text NULL,
  offer_data jsonb NULL,
  actioned_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT notifications_pkey PRIMARY KEY (id)
);

-- Step 2: Add foreign key constraints
ALTER TABLE public.notifications 
ADD CONSTRAINT notifications_job_id_fkey 
FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;

ALTER TABLE public.notifications 
ADD CONSTRAINT notifications_from_user_id_fkey 
FOREIGN KEY (from_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.notifications 
ADD CONSTRAINT notifications_to_user_id_fkey 
FOREIGN KEY (to_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 3: Add check constraints
ALTER TABLE public.notifications 
ADD CONSTRAINT notifications_status_check 
CHECK (status IN ('pending', 'accepted', 'rejected'));

-- Step 4: Create indexes
CREATE INDEX idx_notifications_to_user_id ON public.notifications(to_user_id);
CREATE INDEX idx_notifications_job_id ON public.notifications(job_id);
CREATE INDEX idx_notifications_status ON public.notifications(status);
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at);

-- Step 5: Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Step 6: Create RLS policies
CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = to_user_id);

CREATE POLICY "Users can create notifications" ON public.notifications
  FOR INSERT WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = to_user_id); 