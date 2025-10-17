-- Add offer_data column to messages table
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS offer_data jsonb NULL;

-- Update deals table to support the new workflow
ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS conversation_id uuid NULL;

ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS agreed_terms text NULL;

ALTER TABLE public.deals 
ADD COLUMN IF NOT EXISTS timeline text NULL;

-- Add foreign key constraint for conversation_id (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'deals_conversation_id_fkey'
    ) THEN
        ALTER TABLE public.deals 
        ADD CONSTRAINT deals_conversation_id_fkey 
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;
    END IF;
END $$; 