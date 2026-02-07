-- Drop the duplicate agent_search_files_with_token function with old parameter order
-- This function has a parameter signature conflict with the new version that includes staging overlay
-- The old version: (p_project_id uuid, p_keyword text, p_token uuid)
-- The new version: (p_project_id uuid, p_token uuid, p_keyword text)
-- Keeping only the new version which properly searches both repo_files and repo_staging

DROP FUNCTION IF EXISTS public.agent_search_files_with_token(uuid, text, uuid);