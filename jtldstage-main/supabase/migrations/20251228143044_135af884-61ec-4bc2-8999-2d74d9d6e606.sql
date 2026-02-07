-- Create lightweight RPC function for session list (no heavy JSONB fields)
CREATE OR REPLACE FUNCTION public.get_audit_sessions_list_with_token(
  p_project_id uuid,
  p_token uuid
)
RETURNS TABLE (
  id uuid,
  name text,
  status text,
  created_at timestamptz,
  current_iteration integer,
  max_iterations integer,
  phase text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Validate access
  PERFORM public.require_role(p_project_id, p_token, 'viewer');
  
  RETURN QUERY 
  SELECT 
    s.id,
    s.name,
    s.status,
    s.created_at,
    s.current_iteration,
    s.max_iterations,
    s.phase
  FROM public.audit_sessions s
  WHERE s.project_id = p_project_id
  ORDER BY s.created_at DESC;
END;
$function$;