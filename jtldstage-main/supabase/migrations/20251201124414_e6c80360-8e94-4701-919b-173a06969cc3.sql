-- Create RPC function for agent file search
CREATE OR REPLACE FUNCTION public.agent_search_files_with_token(
  p_project_id uuid,
  p_keyword text,
  p_token uuid
)
RETURNS TABLE(
  id uuid,
  path text,
  content text,
  match_type text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Validate project access
  PERFORM public.validate_project_access(p_project_id, p_token);
  
  -- Search in file paths and content
  RETURN QUERY
  SELECT 
    rf.id,
    rf.path,
    rf.content,
    CASE 
      WHEN rf.path ILIKE '%' || p_keyword || '%' THEN 'path'
      WHEN rf.content ILIKE '%' || p_keyword || '%' THEN 'content'
      ELSE 'unknown'
    END as match_type
  FROM public.repo_files rf
  WHERE rf.project_id = p_project_id
    AND (
      rf.path ILIKE '%' || p_keyword || '%' 
      OR rf.content ILIKE '%' || p_keyword || '%'
    )
  ORDER BY 
    CASE WHEN rf.path ILIKE '%' || p_keyword || '%' THEN 1 ELSE 2 END,
    rf.path;
END;
$function$;

-- Create RPC function for agent to read a single file
CREATE OR REPLACE FUNCTION public.agent_read_file_with_token(
  p_file_id uuid,
  p_token uuid
)
RETURNS TABLE(
  id uuid,
  path text,
  content text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Validate access via repo
  IF NOT EXISTS (
    SELECT 1 FROM repo_files rf
    WHERE rf.id = p_file_id
    AND validate_repo_access(rf.repo_id, p_token)
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;
  
  RETURN QUERY
  SELECT rf.id, rf.path, rf.content
  FROM repo_files rf
  WHERE rf.id = p_file_id;
END;
$function$;

-- Create RPC function for agent to read multiple files at once
CREATE OR REPLACE FUNCTION public.agent_read_multiple_files_with_token(
  p_file_ids uuid[],
  p_token uuid
)
RETURNS TABLE(
  id uuid,
  path text,
  content text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT rf.id, rf.path, rf.content
  FROM repo_files rf
  WHERE rf.id = ANY(p_file_ids)
    AND validate_repo_access(rf.repo_id, p_token);
END;
$function$;