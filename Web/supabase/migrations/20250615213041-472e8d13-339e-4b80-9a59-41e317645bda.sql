
-- Make proposal_id nullable in deals table to support chat-based deals
ALTER TABLE public.deals 
ALTER COLUMN proposal_id DROP NOT NULL;
