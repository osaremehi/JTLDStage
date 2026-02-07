-- Drop and recreate get_agent_operations_with_token to fix parameter signature
DROP FUNCTION IF EXISTS public.get_agent_operations_with_token(uuid, uuid);

CREATE OR REPLACE FUNCTION public.get_agent_operations_with_token(
  p_session_id uuid,
  p_token uuid
)
RETURNS SETOF agent_file_operations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
BEGIN
  -- Get project_id from session
  SELECT project_id INTO v_project_id
  FROM agent_sessions
  WHERE id = p_session_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  
  -- Validate project access
  PERFORM public.validate_project_access(v_project_id, p_token);
  
  RETURN QUERY
  SELECT *
  FROM public.agent_file_operations
  WHERE session_id = p_session_id
  ORDER BY created_at ASC;
END;
$function$;