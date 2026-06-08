-- Per-user conversation archiving.
--
-- A conversation has two participants (client_id + provider_id). Archiving must be
-- one-sided: when the client archives a chat it disappears from *their* Messages list
-- but stays visible for the provider, and vice-versa. We model that with two boolean
-- flags, mirroring the existing client_unread_count / provider_unread_count pattern.
--
-- Additive + idempotent. Existing rows default to false (un-archived), so behaviour is
-- unchanged until a user explicitly archives a conversation. No trigger or RLS changes
-- are needed: the existing "Users can update conversations they are part of" UPDATE
-- policy already authorises a participant to flip their own archive flag.

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS client_archived boolean NOT NULL DEFAULT false;

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS provider_archived boolean NOT NULL DEFAULT false;
