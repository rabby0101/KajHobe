-- Add missing tables for Swift app compatibility

-- Create conversations table
CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id bigint NOT NULL,
  client_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'active'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT conversations_pkey PRIMARY KEY (id),
  CONSTRAINT conversations_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs (id) ON DELETE CASCADE,
  CONSTRAINT conversations_client_id_fkey FOREIGN KEY (client_id) REFERENCES profiles (id) ON DELETE CASCADE,
  CONSTRAINT conversations_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES profiles (id) ON DELETE CASCADE
);

-- Create index for conversations
CREATE INDEX IF NOT EXISTS idx_conversations_job_id ON public.conversations USING btree (job_id);
CREATE INDEX IF NOT EXISTS idx_conversations_client_id ON public.conversations USING btree (client_id);
CREATE INDEX IF NOT EXISTS idx_conversations_provider_id ON public.conversations USING btree (provider_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON public.conversations USING btree (updated_at DESC);

-- Create messages table (alias for chat_messages for compatibility)
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  message_type text NOT NULL DEFAULT 'text'::text,
  attachment_url text NULL,
  read_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE,
  CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES profiles (id) ON DELETE CASCADE
);

-- Create index for messages
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages USING btree (conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages USING btree (sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages USING btree (created_at ASC);

-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'info'::text,
  read boolean NOT NULL DEFAULT false,
  related_job_id bigint NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles (id) ON DELETE CASCADE,
  CONSTRAINT notifications_related_job_id_fkey FOREIGN KEY (related_job_id) REFERENCES jobs (id) ON DELETE CASCADE
);

-- Create index for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications USING btree (read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications USING btree (created_at DESC);

-- Create jobs table if it doesn't exist (referenced by conversations)
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
  CONSTRAINT jobs_pkey PRIMARY KEY (id),
  CONSTRAINT jobs_client_id_fkey FOREIGN KEY (client_id) REFERENCES profiles (id) ON DELETE CASCADE
);

-- Create index for jobs
CREATE INDEX IF NOT EXISTS idx_jobs_client_id ON public.jobs USING btree (client_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON public.jobs USING btree (status);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON public.jobs USING btree (created_at DESC);

-- Add RLS policies for conversations
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view conversations they are part of" ON public.conversations
  FOR SELECT USING (
    auth.uid() = client_id OR auth.uid() = provider_id
  );

CREATE POLICY "Users can insert conversations" ON public.conversations
  FOR INSERT WITH CHECK (
    auth.uid() = client_id OR auth.uid() = provider_id
  );

CREATE POLICY "Users can update conversations they are part of" ON public.conversations
  FOR UPDATE USING (
    auth.uid() = client_id OR auth.uid() = provider_id
  );

-- Add RLS policies for messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages in conversations they are part of" ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.client_id = auth.uid() OR conversations.provider_id = auth.uid())
    )
  );

CREATE POLICY "Users can insert messages in conversations they are part of" ON public.messages
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.client_id = auth.uid() OR conversations.provider_id = auth.uid())
    )
  );

-- Add RLS policies for notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own notifications" ON public.notifications
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- Add RLS policies for jobs
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view jobs" ON public.jobs
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own jobs" ON public.jobs
  FOR INSERT WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can update their own jobs" ON public.jobs
  FOR UPDATE USING (auth.uid() = client_id); 