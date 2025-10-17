-- Create storage bucket for chat images
INSERT INTO storage.buckets (id, name, public) VALUES ('chat-images', 'chat-images', true);

-- Create storage policies for chat images
CREATE POLICY "Chat images are publicly accessible" 
ON storage.objects 
FOR SELECT 
USING (bucket_id = 'chat-images');

CREATE POLICY "Users can upload chat images" 
ON storage.objects 
FOR INSERT 
WITH CHECK (bucket_id = 'chat-images' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can update their own chat images" 
ON storage.objects 
FOR UPDATE 
USING (bucket_id = 'chat-images' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can delete their own chat images" 
ON storage.objects 
FOR DELETE 
USING (bucket_id = 'chat-images' AND auth.uid() IS NOT NULL);

-- Add new message types and negotiation data
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS negotiation_data JSONB,
ADD COLUMN IF NOT EXISTS original_proposal_id UUID REFERENCES public.proposals(id) ON DELETE SET NULL;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_messages_negotiation ON public.messages(original_proposal_id) WHERE original_proposal_id IS NOT NULL;