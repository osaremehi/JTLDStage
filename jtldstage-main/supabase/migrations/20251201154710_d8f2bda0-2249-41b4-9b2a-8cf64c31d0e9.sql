-- Add unique constraint to prevent duplicate staged changes for the same file
ALTER TABLE public.repo_staging 
DROP CONSTRAINT IF EXISTS repo_staging_unique_file;

ALTER TABLE public.repo_staging 
ADD CONSTRAINT repo_staging_unique_file UNIQUE (repo_id, file_path);