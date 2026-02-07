-- Fix update_agent_operation_status_with_token: Remove broken duplicate, update original with RBAC fix only

-- Step 1: Drop the broken new version (wrong status check 'error' vs 'failed', wrong param order)
DROP FUNCTION IF EXISTS public.update_agent_operation_status_with_token(uuid, uuid, text, text);

-- Step 2: Update the original version with ONLY the RBAC fix
CREATE OR REPLACE FUNCTION public.update_agent_operation_status_with_token(
  p_operation_id uuid,
  p_status text,
  p_error_message text DEFAULT NULL,
  p_token uuid DEFAULT NULL
)
RETURNS agent_file_operations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_session_id uuid;
  result public.agent_file_operations;
BEGIN
  -- Get session_id from operation
  SELECT session_id INTO v_session_id 
  FROM public.agent_file_operations 
  WHERE id = p_operation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Operation not found';
  END IF;
  
  -- FIXED: Use require_role instead of set_share_token
  v_project_id := public.get_project_id_from_session(v_session_id);
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  PERFORM public.require_role(v_project_id, p_token, 'editor');

  -- Original logic preserved (note: 'failed' not 'error')
  UPDATE public.agent_file_operations
  SET 
    status = p_status,
    error_message = p_error_message,
    completed_at = CASE WHEN p_status IN ('completed', 'failed') THEN now() ELSE completed_at END
  WHERE id = p_operation_id
  RETURNING * INTO result;

  RETURN result;
END;
$function$;