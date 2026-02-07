-- Make standard-attachments bucket public so files can be viewed
UPDATE storage.buckets 
SET public = true 
WHERE name = 'standard-attachments';