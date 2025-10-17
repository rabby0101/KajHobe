# Storage Policies for job-media Bucket

The `job-media` bucket has been created successfully. To complete the setup, add these RLS policies through the Supabase Dashboard:

## Access the Storage Policies

1. Go to: https://supabase.com/dashboard/project/xatlqnbrvgukuqewsxux/storage/policies
2. Select the `job-media` bucket
3. Add the following policies:

## Policy 1: Public Read Access
**Name:** Public read access for job media
**Operation:** SELECT
**Policy Definition:**
```sql
bucket_id = 'job-media'
```

## Policy 2: Authenticated Upload Access
**Name:** Authenticated users can upload job media
**Operation:** INSERT
**Policy Definition:**
```sql
bucket_id = 'job-media' AND auth.role() = 'authenticated'
```

## Policy 3: Users Can Update Their Own Media
**Name:** Users can update their own job media
**Operation:** UPDATE
**USING Expression:**
```sql
bucket_id = 'job-media' AND auth.uid()::text = (storage.foldername(name))[1]
```
**WITH CHECK Expression:**
```sql
bucket_id = 'job-media' AND auth.uid()::text = (storage.foldername(name))[1]
```

## Policy 4: Users Can Delete Their Own Media
**Name:** Users can delete their own job media
**Operation:** DELETE
**Policy Definition:**
```sql
bucket_id = 'job-media' AND auth.uid()::text = (storage.foldername(name))[1]
```

## Alternative: Simplified Public Bucket Setup

If you want simpler public access (recommended for MVP):

1. **Public Read:** Already enabled (bucket is public)
2. **Authenticated Upload:** Add this policy:
   ```sql
   bucket_id = 'job-media' AND auth.role() = 'authenticated'
   ```
3. **Anyone Can Upload (Less Secure):** If testing, you can allow anonymous uploads:
   ```sql
   bucket_id = 'job-media'
   ```

## Bucket Configuration

The bucket is already configured with:
- **Public Access:** Yes (anyone can read)
- **File Size Limit:** 50MB
- **Allowed MIME Types:**
  - Images: jpeg, png, jpg, webp, gif
  - Videos: mp4, quicktime, x-msvideo

## Testing

After setting up policies, test with:
```bash
# Test upload (requires authentication)
curl -X POST \
  'https://xatlqnbrvgukuqewsxux.supabase.co/storage/v1/object/job-media/test.jpg' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: image/jpeg' \
  --data-binary '@test.jpg'

# Test public read
curl 'https://xatlqnbrvgukuqewsxux.supabase.co/storage/v1/object/public/job-media/test.jpg'
```
