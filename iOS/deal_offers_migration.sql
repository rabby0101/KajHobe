-- Fix data type mismatches between jobs, proposals, and deals tables
-- The root issue is that jobs.id is bigint but proposals.job_id should also be bigint

-- First, ensure profiles table exists with all required columns
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email text,
  full_name text,
  phone text,
  avatar_url text,
  user_type text CHECK (user_type IN ('seeker', 'provider', 'both')) DEFAULT 'seeker',
  location text,
  bio text,
  website text,
  is_service_provider boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add missing columns to profiles table if they don't exist
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS user_type text DEFAULT 'seeker',
ADD COLUMN IF NOT EXISTS bio text,
ADD COLUMN IF NOT EXISTS website text,
ADD COLUMN IF NOT EXISTS is_service_provider boolean DEFAULT false;

-- Add or update the check constraint for user_type
DO $$
BEGIN
    -- Drop existing constraint if it exists
    ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS valid_user_type;
    ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
    
    -- Add the correct constraint
    ALTER TABLE public.profiles 
    ADD CONSTRAINT valid_user_type 
    CHECK (user_type IN ('seeker', 'provider', 'both'));
    
    -- Ensure existing records have valid user_type
    UPDATE public.profiles 
    SET user_type = 'seeker' 
    WHERE user_type IS NULL OR user_type NOT IN ('seeker', 'provider', 'both');
END $$;

-- Enable RLS for profiles table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create or replace RLS policies for profiles table
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;

CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Create indexes for profiles table
CREATE INDEX IF NOT EXISTS idx_profiles_user_type ON public.profiles(user_type);
CREATE INDEX IF NOT EXISTS idx_profiles_is_service_provider ON public.profiles(is_service_provider);

-- Create notifications table with comprehensive schema to support all notification types
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  -- Old schema columns (for backward compatibility)
  user_id uuid NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NULL,
  message text NULL,
  read boolean DEFAULT false,
  related_job_id bigint NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  related_proposal_id uuid NULL,
  -- New schema columns (for show interest and deal offers)
  type text NULL,
  job_id bigint NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  from_user_id uuid NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  to_user_id uuid NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text DEFAULT 'pending',
  offer_data jsonb NULL,
  actioned_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Add check constraint for status (flexible to allow NULL for old schema)
ALTER TABLE public.notifications 
ADD CONSTRAINT notifications_status_check 
CHECK (status IN ('pending', 'accepted', 'rejected') OR status IS NULL);

-- Create indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_to_user_id ON public.notifications(to_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_from_user_id ON public.notifications(from_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_job_id ON public.notifications(job_id);
CREATE INDEX IF NOT EXISTS idx_notifications_related_job_id ON public.notifications(related_job_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at);

-- Enable RLS for notifications table
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Create comprehensive RLS policies that work with both old and new schema
CREATE POLICY "Users can view their own notifications" 
  ON public.notifications 
  FOR SELECT 
  USING (
    auth.uid() = user_id OR  -- Old schema
    auth.uid() = to_user_id  -- New schema
  );

CREATE POLICY "Users can create notifications" 
  ON public.notifications 
  FOR INSERT 
  WITH CHECK (
    auth.uid() = user_id OR  -- Old schema
    auth.uid() = from_user_id  -- New schema
  );

CREATE POLICY "Users can update their own notifications" 
  ON public.notifications 
  FOR UPDATE 
  USING (
    auth.uid() = user_id OR  -- Old schema
    auth.uid() = to_user_id  -- New schema
  );

-- Create proposals table if it doesn't exist (with correct data types)
CREATE TABLE IF NOT EXISTS public.proposals (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id bigint NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  provider_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount integer NOT NULL,
  message text NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(job_id, provider_id)
);

-- Enable RLS for proposals table
ALTER TABLE public.proposals ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for proposals table
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

CREATE POLICY "Providers can view their own proposals" 
  ON public.proposals 
  FOR SELECT 
  USING (provider_id = auth.uid());

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

CREATE POLICY "Providers can update their own proposals" 
  ON public.proposals 
  FOR UPDATE 
  USING (provider_id = auth.uid());

CREATE POLICY "Job owners can update proposal status" 
  ON public.proposals 
  FOR UPDATE 
  USING (
    auth.uid() IN (
      SELECT client_id FROM public.jobs WHERE id = job_id
    )
  );

-- Now check and fix the proposals table if it already existed with wrong data type
DO $$
DECLARE 
    proposals_job_id_type text;
BEGIN
    -- Check current data type of proposals.job_id
    SELECT data_type INTO proposals_job_id_type
    FROM information_schema.columns 
    WHERE table_name = 'proposals' 
    AND table_schema = 'public' 
    AND column_name = 'job_id';
    
    -- If proposals.job_id is uuid but jobs.id is bigint, we need to fix it
    IF proposals_job_id_type = 'uuid' THEN
        RAISE NOTICE 'Fixing existing proposals.job_id data type from UUID to bigint';
        
        -- Drop foreign key constraint temporarily
        ALTER TABLE public.proposals DROP CONSTRAINT IF EXISTS proposals_job_id_fkey;
        
        -- Change job_id column type (this will fail if there are UUIDs in the data)
        -- For a clean migration, you might need to truncate proposals table first
        -- TRUNCATE TABLE public.proposals; -- Uncomment if needed
        
        ALTER TABLE public.proposals ALTER COLUMN job_id TYPE bigint USING job_id::text::bigint;
        
        -- Recreate foreign key constraint
        ALTER TABLE public.proposals 
        ADD CONSTRAINT proposals_job_id_fkey 
        FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Fixed proposals.job_id data type successfully';
    END IF;
END $$;

-- Create deal_offers table
CREATE TABLE IF NOT EXISTS public.deal_offers (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  provider_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  job_id bigint NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  amount integer NOT NULL,
  terms text NULL,
  timeline text NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  responded_at timestamp with time zone NULL
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_deal_offers_conversation_id ON public.deal_offers(conversation_id);
CREATE INDEX IF NOT EXISTS idx_deal_offers_job_id ON public.deal_offers(job_id);
CREATE INDEX IF NOT EXISTS idx_deal_offers_provider_id ON public.deal_offers(provider_id);
CREATE INDEX IF NOT EXISTS idx_deal_offers_client_id ON public.deal_offers(client_id);
CREATE INDEX IF NOT EXISTS idx_deal_offers_status ON public.deal_offers(status);
CREATE INDEX IF NOT EXISTS idx_deal_offers_created_at ON public.deal_offers(created_at);

-- Enable RLS
ALTER TABLE public.deal_offers ENABLE ROW LEVEL SECURITY;

-- RLS policies for deal_offers
CREATE POLICY "Users can view deal offers they are part of" 
  ON public.deal_offers 
  FOR SELECT 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

CREATE POLICY "Providers can create deal offers" 
  ON public.deal_offers 
  FOR INSERT 
  WITH CHECK (auth.uid() = provider_id);

CREATE POLICY "Clients can update deal offers" 
  ON public.deal_offers 
  FOR UPDATE 
  USING (auth.uid() = client_id);

-- Now add deal_offer_id column to notifications table (after deal_offers table exists)
ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS deal_offer_id uuid NULL REFERENCES public.deal_offers(id) ON DELETE SET NULL;

-- Create index for the new column
CREATE INDEX IF NOT EXISTS idx_notifications_deal_offer_id ON public.notifications(deal_offer_id);

-- Create deals table if it doesn't exist (with correct data types)
CREATE TABLE IF NOT EXISTS public.deals (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id bigint NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  proposal_id uuid NULL REFERENCES public.proposals(id) ON DELETE CASCADE,
  agreed_amount integer NOT NULL,
  status text NOT NULL DEFAULT 'active',
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  completed_at timestamp with time zone NULL
);

-- Enable RLS for deals table
ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for deals table
CREATE POLICY "Users can view deals they are part of" 
  ON public.deals 
  FOR SELECT 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

CREATE POLICY "Clients can create deals" 
  ON public.deals 
  FOR INSERT 
  WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can update deals they are part of" 
  ON public.deals 
  FOR UPDATE 
  USING (auth.uid() = client_id OR auth.uid() = provider_id);

-- Fix notifications table schema to ensure compatibility with deal offers
-- Check if notifications table has the new schema (with to_user_id, from_user_id)
DO $$
BEGIN
    -- If the new notification schema exists but job_id is uuid, we need to change it to bigint
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'to_user_id'
        AND table_schema = 'public'
    ) THEN
        -- Check if job_id exists and is uuid type
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'notifications' 
            AND column_name = 'job_id'
            AND data_type = 'uuid'
            AND table_schema = 'public'
        ) THEN
            -- Drop the foreign key constraint if it exists
            IF EXISTS (
                SELECT 1 FROM information_schema.table_constraints 
                WHERE constraint_name = 'notifications_job_id_fkey'
                AND table_name = 'notifications'
            ) THEN
                ALTER TABLE public.notifications DROP CONSTRAINT notifications_job_id_fkey;
            END IF;
            
            -- Change job_id from uuid to bigint
            ALTER TABLE public.notifications ALTER COLUMN job_id TYPE bigint USING job_id::text::bigint;
            
            -- Re-add the foreign key constraint
            ALTER TABLE public.notifications 
            ADD CONSTRAINT notifications_job_id_fkey 
            FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

-- Add required columns to existing tables

-- Add deal_offer_id column to messages table for tracking
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS deal_offer_id uuid NULL REFERENCES public.deal_offers(id) ON DELETE SET NULL;

-- Add deal_offer_id and conversation_id columns to deals table (needed by Swift code)
ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS deal_offer_id uuid NULL REFERENCES public.deal_offers(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS conversation_id uuid NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS agreed_terms text NULL,
ADD COLUMN IF NOT EXISTS timeline text NULL;

-- Create indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_messages_deal_offer_id ON public.messages(deal_offer_id);
CREATE INDEX IF NOT EXISTS idx_deals_deal_offer_id ON public.deals(deal_offer_id);
CREATE INDEX IF NOT EXISTS idx_deals_conversation_id ON public.deals(conversation_id);

-- Function to handle deal offer creation
CREATE OR REPLACE FUNCTION handle_deal_offer_created()
RETURNS TRIGGER AS $$
BEGIN
  -- Send notification to client about new deal offer
  INSERT INTO public.notifications (
    type, 
    job_id, 
    from_user_id, 
    to_user_id, 
    status, 
    message,
    deal_offer_id
  )
  VALUES (
    'deal_offer_received',
    NEW.job_id,
    NEW.provider_id,
    NEW.client_id,
    'pending',
    'You have received a new deal offer for $' || NEW.amount,
    NEW.id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle deal offer response
CREATE OR REPLACE FUNCTION handle_deal_offer_responded()
RETURNS TRIGGER AS $$
BEGIN
  -- If deal was accepted, create the actual deal
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    INSERT INTO public.deals (
      job_id,
      client_id,
      provider_id,
      conversation_id,
      deal_offer_id,
      agreed_amount,
      agreed_terms,
      timeline,
      status
    )
    VALUES (
      NEW.job_id,
      NEW.client_id,
      NEW.provider_id,
      NEW.conversation_id,
      NEW.id,
      NEW.amount,
      NEW.terms,
      NEW.timeline,
      'active'
    );
  END IF;
  
  -- Send notification to provider about response
  INSERT INTO public.notifications (
    type,
    job_id,
    from_user_id,
    to_user_id,
    status,
    message,
    deal_offer_id
  )
  VALUES (
    'deal_offer_responded',
    NEW.job_id,
    NEW.client_id,
    NEW.provider_id,
    'pending',
    'Your deal offer was ' || NEW.status,
    NEW.id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER on_deal_offer_created
  AFTER INSERT ON public.deal_offers
  FOR EACH ROW EXECUTE FUNCTION handle_deal_offer_created();

CREATE TRIGGER on_deal_offer_responded
  AFTER UPDATE ON public.deal_offers
  FOR EACH ROW EXECUTE FUNCTION handle_deal_offer_responded();

-- Function to get deal count for a provider on a specific job
CREATE OR REPLACE FUNCTION get_deal_count(job_uuid bigint, provider_uuid uuid)
RETURNS integer AS $$
DECLARE
  deal_count integer;
BEGIN
  SELECT COUNT(*) INTO deal_count
  FROM public.deal_offers
  WHERE job_id = job_uuid AND provider_id = provider_uuid;
  
  RETURN deal_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.deal_offers TO authenticated;
GRANT ALL ON public.deals TO authenticated;
GRANT EXECUTE ON FUNCTION get_deal_count(bigint, uuid) TO authenticated; 