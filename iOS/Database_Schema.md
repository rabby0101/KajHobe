create table public.bids (
  id uuid not null default gen_random_uuid (),
  job_id uuid not null,
  provider_id uuid not null,
  amount integer not null,
  message text null,
  status text null default 'pending'::text,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint bids_pkey primary key (id),
  constraint bids_job_id_provider_id_key unique (job_id, provider_id),
  constraint bids_job_id_fkey foreign KEY (job_id) references jobs (id) on delete CASCADE,
  constraint bids_provider_id_fkey foreign KEY (provider_id) references auth.users (id) on delete CASCADE,
  constraint bids_status_check check (
    (
      status = any (
        array[
          'pending'::text,
          'accepted'::text,
          'rejected'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;
---
create table public.conversations (
  id uuid not null default gen_random_uuid (),
  job_id uuid not null,
  client_id uuid not null,
  provider_id uuid not null,
  proposal_id uuid null,
  deal_id uuid null,
  status text not null default 'active'::text,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint conversations_pkey primary key (id),
  constraint conversations_client_id_fkey foreign KEY (client_id) references profiles (id) on delete CASCADE,
  constraint conversations_deal_id_fkey foreign KEY (deal_id) references deals (id) on delete set null,
  constraint conversations_job_id_fkey foreign KEY (job_id) references jobs (id) on delete CASCADE,
  constraint conversations_proposal_id_fkey foreign KEY (proposal_id) references proposals (id) on delete set null,
  constraint conversations_provider_id_fkey foreign KEY (provider_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_conversations_job_id on public.conversations using btree (job_id) TABLESPACE pg_default;

create index IF not exists idx_conversations_client_id on public.conversations using btree (client_id) TABLESPACE pg_default;

create index IF not exists idx_conversations_provider_id on public.conversations using btree (provider_id) TABLESPACE pg_default;
---
create table public.deals (
  id uuid not null default gen_random_uuid (),
  job_id uuid not null,
  client_id uuid not null,
  provider_id uuid not null,
  proposal_id uuid null,
  agreed_amount integer not null,
  status text not null default 'active'::text,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  completed_at timestamp with time zone null,
  constraint deals_pkey primary key (id),
  constraint deals_client_id_fkey foreign KEY (client_id) references profiles (id) on delete CASCADE,
  constraint deals_job_id_fkey foreign KEY (job_id) references jobs (id) on delete CASCADE,
  constraint deals_proposal_id_fkey foreign KEY (proposal_id) references proposals (id) on delete CASCADE,
  constraint deals_provider_id_fkey foreign KEY (provider_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;

create trigger on_deal_created
after INSERT on deals for EACH row
execute FUNCTION create_deal_notifications ();

create trigger on_deal_updated
after
update on deals for EACH row
execute FUNCTION update_deal_notifications ();
---
create table public.jobs (
  id uuid not null default gen_random_uuid (),
  title text not null,
  description text not null,
  category text not null,
  location text not null,
  status text null default 'open'::text,
  urgent boolean null default false,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  client_id uuid not null,
  budget integer not null,
  constraint jobs_pkey primary key (id),
  constraint jobs_client_id_fkey foreign KEY (client_id) references auth.users (id) on delete CASCADE,
  constraint jobs_status_check check (
    (
      status = any (
        array[
          'open'::text,
          'in_progress'::text,
          'completed'::text,
          'cancelled'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;
create table public.messages (
  id uuid not null default gen_random_uuid (),
  conversation_id uuid not null,
  sender_id uuid not null,
  content text not null,
  message_type text not null default 'text'::text,
  attachment_url text null,
  read_at timestamp with time zone null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  negotiation_data jsonb null,
  original_proposal_id uuid null,
  constraint messages_pkey primary key (id),
  constraint messages_conversation_id_fkey foreign KEY (conversation_id) references conversations (id) on delete CASCADE,
  constraint messages_original_proposal_id_fkey foreign KEY (original_proposal_id) references proposals (id) on delete set null,
  constraint messages_sender_id_fkey foreign KEY (sender_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_messages_conversation_id on public.messages using btree (conversation_id) TABLESPACE pg_default;

create index IF not exists idx_messages_sender_id on public.messages using btree (sender_id) TABLESPACE pg_default;

create index IF not exists idx_messages_created_at on public.messages using btree (created_at) TABLESPACE pg_default;

create index IF not exists idx_messages_negotiation on public.messages using btree (original_proposal_id) TABLESPACE pg_default
where
  (original_proposal_id is not null);

create trigger on_message_received
after INSERT on messages for EACH row
execute FUNCTION handle_new_message ();

create trigger on_message_sent
after INSERT on messages for EACH row
execute FUNCTION update_conversation_timestamp ();

create trigger trigger_handle_negotiation_message
after INSERT on messages for EACH row
execute FUNCTION handle_negotiation_message ();
---
create table public.messages (
  id uuid not null default gen_random_uuid (),
  conversation_id uuid not null,
  sender_id uuid not null,
  content text not null,
  message_type text not null default 'text'::text,
  attachment_url text null,
  read_at timestamp with time zone null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  negotiation_data jsonb null,
  original_proposal_id uuid null,
  constraint messages_pkey primary key (id),
  constraint messages_conversation_id_fkey foreign KEY (conversation_id) references conversations (id) on delete CASCADE,
  constraint messages_original_proposal_id_fkey foreign KEY (original_proposal_id) references proposals (id) on delete set null,
  constraint messages_sender_id_fkey foreign KEY (sender_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_messages_conversation_id on public.messages using btree (conversation_id) TABLESPACE pg_default;

create index IF not exists idx_messages_sender_id on public.messages using btree (sender_id) TABLESPACE pg_default;

create index IF not exists idx_messages_created_at on public.messages using btree (created_at) TABLESPACE pg_default;

create index IF not exists idx_messages_negotiation on public.messages using btree (original_proposal_id) TABLESPACE pg_default
where
  (original_proposal_id is not null);

create trigger on_message_received
after INSERT on messages for EACH row
execute FUNCTION handle_new_message ();

create trigger on_message_sent
after INSERT on messages for EACH row
execute FUNCTION update_conversation_timestamp ();

create trigger trigger_handle_negotiation_message
after INSERT on messages for EACH row
execute FUNCTION handle_negotiation_message ();
---
create table public.profiles (
  id uuid not null,
  email text null,
  full_name text null,
  phone text null,
  avatar_url text null,
  user_type text null default 'seeker'::text,
  location text null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  bio text null,
  website text null,
  is_service_provider boolean null default false,
  constraint profiles_pkey primary key (id),
  constraint profiles_id_fkey foreign KEY (id) references auth.users (id) on delete CASCADE,
  constraint valid_user_type check (
    (
      user_type = any (
        array['seeker'::text, 'provider'::text, 'both'::text]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_profiles_is_service_provider on public.profiles using btree (is_service_provider) TABLESPACE pg_default;
---
create table public.proposals (
  id uuid not null default gen_random_uuid (),
  job_id uuid not null,
  provider_id uuid not null,
  amount integer not null,
  message text null,
  status text not null default 'pending'::text,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint proposals_pkey primary key (id),
  constraint proposals_job_id_provider_id_key unique (job_id, provider_id),
  constraint proposals_job_id_fkey foreign KEY (job_id) references jobs (id) on delete CASCADE,
  constraint proposals_provider_id_fkey foreign KEY (provider_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;

create trigger on_proposal_created
after INSERT on proposals for EACH row
execute FUNCTION handle_new_proposal ();

create trigger on_proposal_status_changed
after
update on proposals for EACH row
execute FUNCTION handle_proposal_status_change ();
---
create table public.reviews (
  id uuid not null default gen_random_uuid (),
  job_id uuid not null,
  reviewer_id uuid not null,
  reviewed_id uuid not null,
  rating integer not null,
  comment text null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint reviews_pkey primary key (id),
  constraint reviews_job_id_reviewer_id_reviewed_id_key unique (job_id, reviewer_id, reviewed_id),
  constraint reviews_job_id_fkey foreign KEY (job_id) references jobs (id) on delete CASCADE,
  constraint reviews_reviewed_id_fkey foreign KEY (reviewed_id) references auth.users (id) on delete CASCADE,
  constraint reviews_reviewer_id_fkey foreign KEY (reviewer_id) references auth.users (id) on delete CASCADE,
  constraint reviews_rating_check check (
    (
      (rating >= 1)
      and (rating <= 5)
    )
  )
) TABLESPACE pg_default;
---
create table public.service_categories (
  id uuid not null default gen_random_uuid (),
  name text not null,
  description text null,
  icon text null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint service_categories_pkey primary key (id),
  constraint service_categories_name_key unique (name)
) TABLESPACE pg_default;