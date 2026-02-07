-- Update merge_collaboration_to_artifact_with_token to optionally keep session active
CREATE OR REPLACE FUNCTION public.merge_collaboration_to_artifact_with_token(
  p_collaboration_id uuid,
  p_token uuid,
  p_close_session boolean DEFAULT false
)
RETURNS artifact_collaborations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_project_id uuid;
  v_artifact_id uuid;
  v_current_content text;
  result public.artifact_collaborations;
BEGIN
  -- Get project_id and artifact_id from collaboration
  SELECT project_id, artifact_id, current_content 
  INTO v_project_id, v_artifact_id, v_current_content
  FROM public.artifact_collaborations
  WHERE id = p_collaboration_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Collaboration not found';
  END IF;
  
  -- Validate access - require editor role
  PERFORM public.require_role(v_project_id, p_token, 'editor');
  
  -- Update the source artifact with current collaboration content
  UPDATE public.artifacts
  SET content = v_current_content, updated_at = now()
  WHERE id = v_artifact_id;
  
  -- Only update collaboration status if p_close_session is true
  IF p_close_session THEN
    UPDATE public.artifact_collaborations
    SET status = 'merged', merged_to_artifact = true, merged_at = now(), updated_at = now()
    WHERE id = p_collaboration_id
    RETURNING * INTO result;
  ELSE
    -- Just update the merged_at timestamp but keep status as 'active'
    UPDATE public.artifact_collaborations
    SET merged_to_artifact = true, merged_at = now(), updated_at = now()
    WHERE id = p_collaboration_id
    RETURNING * INTO result;
  END IF;
  
  RETURN result;
END;
$function$;