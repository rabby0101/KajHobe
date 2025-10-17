-- Create storage bucket for chat attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-attachments', 'chat-attachments', true);

-- Create policy to allow authenticated users to upload files
CREATE POLICY "Allow authenticated users to upload chat attachments" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'chat-attachments' 
    AND auth.role() = 'authenticated'
);

-- Create policy to allow public access to view files
CREATE POLICY "Allow public access to chat attachments" ON storage.objects
FOR SELECT USING (bucket_id = 'chat-attachments');

-- Create policy to allow users to delete their own uploads
CREATE POLICY "Allow users to delete their own chat attachments" ON storage.objects
FOR DELETE USING (
    bucket_id = 'chat-attachments' 
    AND auth.uid()::text = (storage.foldername(name))[1]
); 